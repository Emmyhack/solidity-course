// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title UniswapV2Clone
 * @dev A production-ready implementation of Uniswap V2 AMM
 * @notice This contract implements the constant product formula (x * y = k)
 * Features:
 * - Liquidity provision and removal
 * - Token swapping with dynamic fees
 * - Price impact calculations
 * - MEV protection mechanisms
 * - Emergency controls
 */
contract UniswapV2Clone is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ============ CONSTANTS ============

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant MAX_FEE = 1000; // 10% max fee
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 private constant PRECISION = 1e18;

    // ============ STATE VARIABLES ============

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public totalSupply;
    uint256 public swapFee = 30; // 0.3% default fee

    bool public paused = false;
    uint256 public maxSlippage = 500; // 5% max slippage

    // LP token tracking
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // Price tracking for TWAP
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint32 public blockTimestampLast;

    // MEV protection
    mapping(address => uint256) public lastTxBlock;
    uint256 public minBlockDelay = 1; // Minimum blocks between transactions

    // ============ EVENTS ============

    event Mint(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Burn(
        address indexed sender,
        uint256 amount0,
        uint256 amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint256 reserve0, uint256 reserve1);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event EmergencyPause(bool paused);

    // ============ ERRORS ============

    error InsufficientLiquidity();
    error InsufficientAmount();
    error InsufficientBalance();
    error InvalidToken();
    error ExcessiveSlippage();
    error ContractPaused();
    error MEVProtection();
    error InvalidFee();
    error ZeroAddress();
    error IdenticalAddresses();
    error TransferFailed();

    // ============ MODIFIERS ============

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier mevProtection() {
        if (block.number <= lastTxBlock[msg.sender] + minBlockDelay) {
            revert MEVProtection();
        }
        lastTxBlock[msg.sender] = block.number;
        _;
    }

    modifier validAddress(address addr) {
        if (addr == address(0)) revert ZeroAddress();
        _;
    }

    // ============ CONSTRUCTOR ============

    constructor(
        address _token0,
        address _token1
    ) validAddress(_token0) validAddress(_token1) {
        if (_token0 == _token1) revert IdenticalAddresses();

        // Ensure token0 < token1 for consistent ordering
        if (_token0 > _token1) {
            (_token0, _token1) = (_token1, _token0);
        }

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
    }

    // ============ LIQUIDITY FUNCTIONS ============

    /**
     * @dev Add liquidity to the pool
     * @param amount0Desired Desired amount of token0
     * @param amount1Desired Desired amount of token1
     * @param amount0Min Minimum amount of token0
     * @param amount1Min Minimum amount of token1
     * @param to Address to receive LP tokens
     * @param deadline Transaction deadline
     * @return amount0 Actual amount of token0 added
     * @return amount1 Actual amount of token1 added
     * @return liquidity LP tokens minted
     */
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        validAddress(to)
        returns (uint256 amount0, uint256 amount1, uint256 liquidity)
    {
        if (block.timestamp > deadline) revert("EXPIRED");

        (amount0, amount1) = _addLiquidity(
            amount0Desired,
            amount1Desired,
            amount0Min,
            amount1Min
        );

        // Transfer tokens to contract
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        liquidity = _mint(to);
    }

    /**
     * @dev Remove liquidity from the pool
     * @param liquidity Amount of LP tokens to burn
     * @param amount0Min Minimum amount of token0 to receive
     * @param amount1Min Minimum amount of token1 to receive
     * @param to Address to receive tokens
     * @param deadline Transaction deadline
     * @return amount0 Amount of token0 received
     * @return amount1 Amount of token1 received
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        validAddress(to)
        returns (uint256 amount0, uint256 amount1)
    {
        if (block.timestamp > deadline) revert("EXPIRED");

        // Transfer LP tokens to contract
        _transfer(msg.sender, address(this), liquidity);

        (amount0, amount1) = _burn(to);

        if (amount0 < amount0Min) revert InsufficientAmount();
        if (amount1 < amount1Min) revert InsufficientAmount();
    }

    // ============ SWAP FUNCTIONS ============

    /**
     * @dev Swap exact amount of input token for output token
     * @param amountIn Exact amount of input token
     * @param amountOutMin Minimum amount of output token
     * @param path Array of token addresses [input, output]
     * @param to Address to receive output tokens
     * @param deadline Transaction deadline
     * @return amountOut Actual amount of output tokens received
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        mevProtection
        validAddress(to)
        returns (uint256 amountOut)
    {
        if (block.timestamp > deadline) revert("EXPIRED");
        if (path.length != 2) revert("INVALID_PATH");
        if (path[0] != address(token0) && path[0] != address(token1))
            revert InvalidToken();
        if (path[1] != address(token0) && path[1] != address(token1))
            revert InvalidToken();

        amountOut = getAmountOut(amountIn, path[0], path[1]);
        if (amountOut < amountOutMin) revert ExcessiveSlippage();

        // Check slippage protection
        uint256 maxSlippageAmount = (amountIn *
            (FEE_DENOMINATOR - maxSlippage)) / FEE_DENOMINATOR;
        if (amountOut < maxSlippageAmount) revert ExcessiveSlippage();

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(
            amountIn,
            0,
            path[0] == address(token0) ? 0 : amountOut,
            path[0] == address(token0) ? amountOut : 0,
            to
        );
    }

    /**
     * @dev Swap tokens for exact amount of output token
     * @param amountOut Exact amount of output token desired
     * @param amountInMax Maximum amount of input token
     * @param path Array of token addresses [input, output]
     * @param to Address to receive output tokens
     * @param deadline Transaction deadline
     * @return amountIn Actual amount of input tokens used
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        nonReentrant
        whenNotPaused
        mevProtection
        validAddress(to)
        returns (uint256 amountIn)
    {
        if (block.timestamp > deadline) revert("EXPIRED");
        if (path.length != 2) revert("INVALID_PATH");

        amountIn = getAmountIn(amountOut, path[0], path[1]);
        if (amountIn > amountInMax) revert ExcessiveSlippage();

        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), amountIn);
        _swap(
            amountIn,
            0,
            path[0] == address(token0) ? 0 : amountOut,
            path[0] == address(token0) ? amountOut : 0,
            to
        );
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get amount of output tokens for given input
     * @param amountIn Amount of input tokens
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @return amountOut Amount of output tokens
     */
    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (tokenIn != address(token0) && tokenIn != address(token1))
            revert InvalidToken();
        if (tokenOut != address(token0) && tokenOut != address(token1))
            revert InvalidToken();
        if (tokenIn == tokenOut) revert IdenticalAddresses();

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == address(token0)
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        return _getAmountOut(amountIn, reserveIn, reserveOut);
    }

    /**
     * @dev Get amount of input tokens needed for given output
     * @param amountOut Amount of output tokens desired
     * @param tokenIn Input token address
     * @param tokenOut Output token address
     * @return amountIn Amount of input tokens needed
     */
    function getAmountIn(
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountIn) {
        if (amountOut == 0) revert InsufficientAmount();
        if (tokenIn != address(token0) && tokenIn != address(token1))
            revert InvalidToken();
        if (tokenOut != address(token0) && tokenOut != address(token1))
            revert InvalidToken();
        if (tokenIn == tokenOut) revert IdenticalAddresses();

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == address(token0)
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        return _getAmountIn(amountOut, reserveIn, reserveOut);
    }

    /**
     * @dev Get current price of token0 in terms of token1
     * @return price Price with 18 decimal precision
     */
    function getPrice0() public view returns (uint256 price) {
        if (reserve1 == 0) return 0;
        return (reserve0 * PRECISION) / reserve1;
    }

    /**
     * @dev Get current price of token1 in terms of token0
     * @return price Price with 18 decimal precision
     */
    function getPrice1() public view returns (uint256 price) {
        if (reserve0 == 0) return 0;
        return (reserve1 * PRECISION) / reserve0;
    }

    /**
     * @dev Calculate price impact for a given trade
     * @param amountIn Amount of input tokens
     * @param tokenIn Input token address
     * @return priceImpact Price impact in basis points (100 = 1%)
     */
    function getPriceImpact(
        uint256 amountIn,
        address tokenIn
    ) public view returns (uint256 priceImpact) {
        if (amountIn == 0) return 0;

        (uint256 reserveIn, uint256 reserveOut) = tokenIn == address(token0)
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        if (reserveIn == 0 || reserveOut == 0) return 0;

        uint256 priceBefore = (reserveOut * PRECISION) / reserveIn;
        uint256 amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        uint256 priceAfter = ((reserveOut - amountOut) * PRECISION) /
            (reserveIn + amountIn);

        if (priceBefore == 0) return 0;
        priceImpact = ((priceBefore - priceAfter) * 10000) / priceBefore;
    }

    // ============ INTERNAL FUNCTIONS ============

    function _addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min) revert InsufficientAmount();
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                if (
                    amount0Optimal > amount0Desired ||
                    amount0Optimal < amount0Min
                ) {
                    revert InsufficientAmount();
                }
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
    }

    function _mint(address to) internal returns (uint256 liquidity) {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - reserve0;
        uint256 amount1 = balance1 - reserve1;

        if (totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // Permanently lock first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(
                (amount0 * totalSupply) / reserve0,
                (amount1 * totalSupply) / reserve1
            );
        }

        if (liquidity == 0) revert InsufficientLiquidity();
        _mint(to, liquidity);

        _update(balance0, balance1);
        emit Mint(msg.sender, amount0, amount1, to);
    }

    function _burn(
        address to
    ) internal returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 liquidity = balanceOf[address(this)];

        amount0 = (liquidity * balance0) / totalSupply;
        amount1 = (liquidity * balance1) / totalSupply;

        if (amount0 == 0 || amount1 == 0) revert InsufficientLiquidity();

        _burn(address(this), liquidity);
        token0.safeTransfer(to, amount0);
        token1.safeTransfer(to, amount1);

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1);
        emit Burn(msg.sender, amount0, amount1, to);
    }

    function _swap(
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address to
    ) internal {
        if (amount0Out == 0 && amount1Out == 0) revert InsufficientAmount();
        if (amount0Out >= reserve0 || amount1Out >= reserve1)
            revert InsufficientLiquidity();

        uint256 balance0;
        uint256 balance1;

        {
            if (to == address(token0) || to == address(token1))
                revert InvalidToken();
            if (amount0Out > 0) token0.safeTransfer(to, amount0Out);
            if (amount1Out > 0) token1.safeTransfer(to, amount1Out);

            balance0 = token0.balanceOf(address(this));
            balance1 = token1.balanceOf(address(this));
        }

        if (balance0 * balance1 < reserve0 * reserve1) revert("K");

        uint256 amount0InWithFee = amount0In * (FEE_DENOMINATOR - swapFee);
        uint256 amount1InWithFee = amount1In * (FEE_DENOMINATOR - swapFee);

        if (
            balance0 * FEE_DENOMINATOR - amount0InWithFee <
            (reserve0 - amount0Out) * FEE_DENOMINATOR ||
            balance1 * FEE_DENOMINATOR - amount1InWithFee <
            (reserve1 - amount1Out) * FEE_DENOMINATOR
        ) {
            revert("K");
        }

        _update(balance0, balance1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function _update(uint256 balance0, uint256 balance1) internal {
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && reserve0 != 0 && reserve1 != 0) {
            price0CumulativeLast +=
                uint256((reserve1 * PRECISION) / reserve0) *
                timeElapsed;
            price1CumulativeLast +=
                uint256((reserve0 * PRECISION) / reserve1) *
                timeElapsed;
        }

        reserve0 = balance0;
        reserve1 = balance1;
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    function _getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 amountOut) {
        if (amountIn == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function _getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal view returns (uint256 amountIn) {
        if (amountOut == 0) revert InsufficientAmount();
        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();
        if (amountOut >= reserveOut) revert InsufficientLiquidity();

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) *
            (FEE_DENOMINATOR - swapFee);
        amountIn = (numerator / denominator) + 1;
    }

    // ============ ERC20 FUNCTIONALITY ============

    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }

    function _burn(address from, uint256 value) internal {
        balanceOf[from] -= value;
        totalSupply -= value;
        emit Transfer(from, address(0), value);
    }

    function _transfer(address from, address to, uint256 value) internal {
        if (balanceOf[from] < value) revert InsufficientBalance();
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool) {
        if (allowance[from][msg.sender] < value) revert InsufficientBalance();
        allowance[from][msg.sender] -= value;
        _transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // ============ ADMIN FUNCTIONS ============

    /**
     * @dev Update swap fee (only owner)
     * @param newFee New fee in basis points (max 10%)
     */
    function setSwapFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE) revert InvalidFee();
        uint256 oldFee = swapFee;
        swapFee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    /**
     * @dev Emergency pause/unpause (only owner)
     * @param _paused New pause state
     */
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        emit EmergencyPause(_paused);
    }

    /**
     * @dev Update MEV protection settings (only owner)
     * @param newDelay New minimum block delay
     */
    function setMEVProtection(uint256 newDelay) external onlyOwner {
        minBlockDelay = newDelay;
    }

    /**
     * @dev Update maximum slippage (only owner)
     * @param newMaxSlippage New maximum slippage in basis points
     */
    function setMaxSlippage(uint256 newMaxSlippage) external onlyOwner {
        if (newMaxSlippage > 5000) revert("EXCESSIVE_SLIPPAGE"); // Max 50%
        maxSlippage = newMaxSlippage;
    }
}

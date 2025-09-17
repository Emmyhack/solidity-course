// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title AMM (Automated Market Maker) DEX
 * @dev A comprehensive AMM implementation demonstrating Foundry development practices
 * @notice This contract implements a constant product formula (x * y = k) AMM
 *
 * FEATURES:
 * - Liquidity provision and removal
 * - Token swapping with slippage protection
 * - Fee collection and distribution
 * - Price oracle functionality
 * - Flashloan capabilities
 * - Emergency controls
 * - Comprehensive events for analytics
 */
contract AMMDEX is ERC20, ReentrancyGuard, Ownable {
    using Math for uint256;

    // ======================
    // CONSTANTS & IMMUTABLES
    // ======================

    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 public constant FEE_DENOMINATOR = 10000;
    uint256 public constant MAX_FEE = 1000; // 10%

    // ======================
    // STATE VARIABLES
    // ======================

    IERC20 public immutable token0;
    IERC20 public immutable token1;

    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint256 public swapFee = 30; // 0.3% in basis points
    uint256 public protocolFee = 5; // 5/6 to LPs, 1/6 to protocol

    bool public flashloanEnabled = true;
    uint256 public flashloanFee = 9; // 0.09%

    address public feeRecipient;

    // ======================
    // EVENTS
    // ======================

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
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
    event Sync(uint112 reserve0, uint112 reserve1);
    event FlashLoan(
        address indexed borrower,
        address indexed token,
        uint256 amount,
        uint256 fee
    );
    event SwapFeeUpdated(uint256 oldFee, uint256 newFee);
    event ProtocolFeeUpdated(uint256 oldFee, uint256 newFee);
    event FlashLoanToggled(bool enabled);

    // ======================
    // ERRORS
    // ======================

    error InsufficientLiquidityMinted();
    error InsufficientLiquidityBurned();
    error InsufficientOutputAmount();
    error InsufficientInputAmount();
    error InsufficientLiquidity();
    error InvalidTo();
    error InvalidK();
    error InvalidFee();
    error TransferFailed();
    error FlashLoanNotEnabled();
    error FlashLoanNotRepaid();
    error IdenticalAddresses();
    error ZeroAddress();

    // ======================
    // MODIFIERS
    // ======================

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, "EXPIRED");
        _;
    }

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(
        address _token0,
        address _token1,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        if (_token0 == _token1) revert IdenticalAddresses();
        if (_token0 == address(0) || _token1 == address(0))
            revert ZeroAddress();

        token0 = IERC20(_token0);
        token1 = IERC20(_token1);
        feeRecipient = msg.sender;
    }

    // ======================
    // CORE FUNCTIONS
    // ======================

    /**
     * @dev Add liquidity to the pool
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
        ensure(deadline)
        nonReentrant
        returns (uint256 amountA, uint256 amountB, uint256 liquidity)
    {
        (amountA, amountB) = _addLiquidity(
            amount0Desired,
            amount1Desired,
            amount0Min,
            amount1Min
        );

        // Transfer tokens to this contract
        _safeTransferFrom(token0, msg.sender, address(this), amountA);
        _safeTransferFrom(token1, msg.sender, address(this), amountB);

        liquidity = mint(to);
    }

    /**
     * @dev Remove liquidity from the pool
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        // Transfer LP tokens to this contract
        _transfer(msg.sender, address(this), liquidity);

        (amount0, amount1) = burn(to);

        if (amount0 < amount0Min) revert InsufficientOutputAmount();
        if (amount1 < amount1Min) revert InsufficientOutputAmount();
    }

    /**
     * @dev Swap exact tokens for tokens
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        require(path.length == 2, "Invalid path");
        require(
            path[0] == address(token0) || path[0] == address(token1),
            "Invalid input token"
        );
        require(
            path[1] == address(token0) || path[1] == address(token1),
            "Invalid output token"
        );
        require(path[0] != path[1], "Identical tokens");

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = getAmountOut(amountIn, path[0], path[1]);

        if (amounts[1] < amountOutMin) revert InsufficientOutputAmount();

        _safeTransferFrom(
            IERC20(path[0]),
            msg.sender,
            address(this),
            amounts[0]
        );
        _swap(amounts[0], amounts[1], path[0], path[1], to);
    }

    /**
     * @dev Swap tokens for exact tokens
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    )
        external
        ensure(deadline)
        nonReentrant
        returns (uint256[] memory amounts)
    {
        require(path.length == 2, "Invalid path");
        require(
            path[0] == address(token0) || path[0] == address(token1),
            "Invalid input token"
        );
        require(
            path[1] == address(token0) || path[1] == address(token1),
            "Invalid output token"
        );
        require(path[0] != path[1], "Identical tokens");

        amounts = new uint256[](2);
        amounts[1] = amountOut;
        amounts[0] = getAmountIn(amountOut, path[0], path[1]);

        if (amounts[0] > amountInMax) revert InsufficientInputAmount();

        _safeTransferFrom(
            IERC20(path[0]),
            msg.sender,
            address(this),
            amounts[0]
        );
        _swap(amounts[0], amounts[1], path[0], path[1], to);
    }

    /**
     * @dev Flash loan function
     */
    function flashLoan(
        address token,
        uint256 amount,
        bytes calldata data
    ) external nonReentrant {
        if (!flashloanEnabled) revert FlashLoanNotEnabled();

        IERC20 borrowToken = IERC20(token);
        require(
            token == address(token0) || token == address(token1),
            "Invalid token"
        );

        uint256 balanceBefore = borrowToken.balanceOf(address(this));
        if (balanceBefore < amount) revert InsufficientLiquidity();

        uint256 fee = (amount * flashloanFee) / FEE_DENOMINATOR;

        // Transfer tokens to borrower
        _safeTransfer(borrowToken, msg.sender, amount);

        // Call borrower's callback
        IFlashLoanReceiver(msg.sender).executeOperation(
            token,
            amount,
            fee,
            data
        );

        // Check repayment
        uint256 balanceAfter = borrowToken.balanceOf(address(this));
        if (balanceAfter < balanceBefore + fee) revert FlashLoanNotRepaid();

        emit FlashLoan(msg.sender, token, amount, fee);
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    /**
     * @dev Internal function to add liquidity
     */
    function _addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();

        if (_reserve0 == 0 && _reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = quote(
                amount0Desired,
                _reserve0,
                _reserve1
            );
            if (amount1Optimal <= amount1Desired) {
                if (amount1Optimal < amount1Min)
                    revert InsufficientInputAmount();
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = quote(
                    amount1Desired,
                    _reserve1,
                    _reserve0
                );
                assert(amount0Optimal <= amount0Desired);
                if (amount0Optimal < amount0Min)
                    revert InsufficientInputAmount();
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
    }

    /**
     * @dev Internal swap function
     */
    function _swap(
        uint256 amountIn,
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        address to
    ) internal {
        if (to == address(token0) || to == address(token1)) revert InvalidTo();

        (uint256 amount0Out, uint256 amount1Out) = tokenIn == address(token0)
            ? (uint256(0), amountOut)
            : (amountOut, uint256(0));

        _safeTransfer(IERC20(tokenOut), to, amountOut);

        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            reserve0,
            reserve1
        );

        emit Swap(
            msg.sender,
            tokenIn == address(token0) ? amountIn : 0,
            tokenIn == address(token1) ? amountIn : 0,
            amount0Out,
            amount1Out,
            to
        );
    }

    /**
     * @dev Mint LP tokens
     */
    function mint(address to) internal returns (uint256 liquidity) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply();

        if (_totalSupply == 0) {
            liquidity = Math.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = Math.min(
                (amount0 * _totalSupply) / _reserve0,
                (amount1 * _totalSupply) / _reserve1
            );
        }

        if (liquidity <= 0) revert InsufficientLiquidityMinted();
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;

        emit Mint(msg.sender, amount0, amount1);
    }

    /**
     * @dev Burn LP tokens
     */
    function burn(
        address to
    ) internal returns (uint256 amount0, uint256 amount1) {
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply();

        amount0 = (liquidity * balance0) / _totalSupply;
        amount1 = (liquidity * balance1) / _totalSupply;

        if (amount0 <= 0 || amount1 <= 0) revert InsufficientLiquidityBurned();

        _burn(address(this), liquidity);
        _safeTransfer(token0, to, amount0);
        _safeTransfer(token1, to, amount1);

        balance0 = token0.balanceOf(address(this));
        balance1 = token1.balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint256(reserve0) * reserve1;

        emit Burn(msg.sender, amount0, amount1, to);
    }

    /**
     * @dev Update reserves and cumulative prices
     */
    function _update(
        uint256 balance0,
        uint256 balance1,
        uint112 _reserve0,
        uint112 _reserve1
    ) private {
        require(
            balance0 <= type(uint112).max && balance1 <= type(uint112).max,
            "OVERFLOW"
        );
        uint32 blockTimestamp = uint32(block.timestamp % 2 ** 32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast;

        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast +=
                uint256(_uqdiv(UQ112x112.encode(_reserve1), _reserve0)) *
                timeElapsed;
            price1CumulativeLast +=
                uint256(_uqdiv(UQ112x112.encode(_reserve0), _reserve1)) *
                timeElapsed;
        }

        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    /**
     * @dev Mint protocol fee
     */
    function _mintFee(
        uint112 _reserve0,
        uint112 _reserve1
    ) private returns (bool feeOn) {
        address feeTo = feeRecipient;
        feeOn = feeTo != address(0);
        uint256 _kLast = kLast;

        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = Math.sqrt(uint256(_reserve0) * _reserve1);
                uint256 rootKLast = Math.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = rootK * protocolFee + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Get current reserves
     */
    function getReserves()
        public
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        )
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    /**
     * @dev Get amount out for exact input
     */
    function getAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountOut) {
        require(amountIn > 0, "INSUFFICIENT_INPUT_AMOUNT");
        require(tokenIn != tokenOut, "IDENTICAL_ADDRESSES");
        require(
            tokenIn == address(token0) || tokenIn == address(token1),
            "INVALID_TOKEN"
        );
        require(
            tokenOut == address(token0) || tokenOut == address(token1),
            "INVALID_TOKEN"
        );

        (uint112 reserveIn, uint112 reserveOut) = tokenIn == address(token0)
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");

        uint256 amountInWithFee = amountIn * (FEE_DENOMINATOR - swapFee);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * FEE_DENOMINATOR + amountInWithFee;
        amountOut = numerator / denominator;
    }

    /**
     * @dev Get amount in for exact output
     */
    function getAmountIn(
        uint256 amountOut,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256 amountIn) {
        require(amountOut > 0, "INSUFFICIENT_OUTPUT_AMOUNT");
        require(tokenIn != tokenOut, "IDENTICAL_ADDRESSES");
        require(
            tokenIn == address(token0) || tokenIn == address(token1),
            "INVALID_TOKEN"
        );
        require(
            tokenOut == address(token0) || tokenOut == address(token1),
            "INVALID_TOKEN"
        );

        (uint112 reserveIn, uint112 reserveOut) = tokenIn == address(token0)
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        require(reserveIn > 0 && reserveOut > 0, "INSUFFICIENT_LIQUIDITY");

        uint256 numerator = reserveIn * amountOut * FEE_DENOMINATOR;
        uint256 denominator = (reserveOut - amountOut) *
            (FEE_DENOMINATOR - swapFee);
        amountIn = (numerator / denominator) + 1;
    }

    /**
     * @dev Quote function for liquidity calculations
     */
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) public pure returns (uint256 amountB) {
        require(amountA > 0, "INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "INSUFFICIENT_LIQUIDITY");
        amountB = (amountA * reserveB) / reserveA;
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    /**
     * @dev Set swap fee (only owner)
     */
    function setSwapFee(uint256 _swapFee) external onlyOwner {
        if (_swapFee > MAX_FEE) revert InvalidFee();
        uint256 oldFee = swapFee;
        swapFee = _swapFee;
        emit SwapFeeUpdated(oldFee, _swapFee);
    }

    /**
     * @dev Set protocol fee (only owner)
     */
    function setProtocolFee(uint256 _protocolFee) external onlyOwner {
        if (_protocolFee > 10) revert InvalidFee(); // Max 10 (1/6 to protocol)
        uint256 oldFee = protocolFee;
        protocolFee = _protocolFee;
        emit ProtocolFeeUpdated(oldFee, _protocolFee);
    }

    /**
     * @dev Set fee recipient (only owner)
     */
    function setFeeRecipient(address _feeRecipient) external onlyOwner {
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev Toggle flashloan functionality (only owner)
     */
    function toggleFlashLoan() external onlyOwner {
        flashloanEnabled = !flashloanEnabled;
        emit FlashLoanToggled(flashloanEnabled);
    }

    /**
     * @dev Emergency function to sync reserves (only owner)
     */
    function sync() external onlyOwner {
        _update(
            token0.balanceOf(address(this)),
            token1.balanceOf(address(this)),
            reserve0,
            reserve1
        );
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    function _safeTransfer(IERC20 token, address to, uint256 value) private {
        bool success = token.transfer(to, value);
        if (!success) revert TransferFailed();
    }

    function _safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) private {
        bool success = token.transferFrom(from, to, value);
        if (!success) revert TransferFailed();
    }
}

// ======================
// HELPER LIBRARIES
// ======================

library UQ112x112 {
    uint224 constant Q112 = 2 ** 112;

    function encode(uint112 y) internal pure returns (uint224 z) {
        z = uint224(y) * Q112;
    }

    function uqdiv(uint224 x, uint112 y) internal pure returns (uint224 z) {
        z = x / uint224(y);
    }
}

function _uqdiv(uint224 x, uint112 y) pure returns (uint224 z) {
    return UQ112x112.uqdiv(x, y);
}

/**
 * @title Flash Loan Receiver Interface
 * @dev Interface for contracts that want to receive flash loans
 */
interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

/**
 * 🏦 AMM DEX FEATURES:
 *
 * 1. CORE FUNCTIONALITY:
 *    - Liquidity provision and removal
 *    - Token swapping with automated pricing
 *    - Fee collection and distribution
 *    - Price oracle with TWAP capabilities
 *
 * 2. ADVANCED FEATURES:
 *    - Flash loans with configurable fees
 *    - Protocol fee mechanism
 *    - Emergency controls and admin functions
 *    - Comprehensive event emission
 *
 * 3. SECURITY FEATURES:
 *    - Reentrancy protection
 *    - Slippage protection
 *    - Overflow protection
 *    - Safe transfer functions
 *
 * 4. FOUNDRY INTEGRATION:
 *    - Optimized for property-based testing
 *    - Comprehensive invariant testing
 *    - Gas optimization ready
 *    - Extensive fuzzing capabilities
 *
 * 🚀 EDUCATIONAL VALUE:
 * - Real-world AMM implementation
 * - Professional Foundry development practices
 * - Advanced testing strategies
 * - Gas optimization techniques
 * - DeFi protocol design patterns
 */

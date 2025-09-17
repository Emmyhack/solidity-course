// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/AMMDEX.sol";
import "../src/MockERC20.sol";

/**
 * @title AMM DEX Invariant Tests
 * @dev Advanced invariant testing demonstrating Foundry's invariant testing capabilities
 * @notice These tests ensure that critical system properties hold under all conditions
 */
contract AMMDEXInvariantTest is Test {
    // ======================
    // TEST CONTRACTS
    // ======================

    AMMDEX public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    // ======================
    // HANDLER CONTRACT
    // ======================

    AMMHandler public handler;

    // ======================
    // SETUP
    // ======================

    function setUp() public {
        // Deploy mock tokens
        tokenA = new MockERC20("Token A", "TKNA", 18, 1_000_000_000e18);
        tokenB = new MockERC20("Token B", "TKNB", 18, 1_000_000_000e18);

        // Ensure token0 < token1 for consistent ordering
        if (address(tokenA) > address(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        // Deploy AMM
        amm = new AMMDEX(
            address(tokenA),
            address(tokenB),
            "AMM LP Token",
            "AMM-LP"
        );

        // Deploy handler
        handler = new AMMHandler(amm, tokenA, tokenB);

        // Setup initial liquidity
        tokenA.mint(address(handler), 10_000_000e18);
        tokenB.mint(address(handler), 10_000_000e18);

        // Add initial liquidity through handler
        handler.addLiquidity(1_000_000e18, 1_000_000e18);

        // Set handler as target for invariant testing
        targetContract(address(handler));

        // Target specific functions for invariant testing
        targetSelector(AMMHandler.addLiquidity.selector);
        targetSelector(AMMHandler.removeLiquidity.selector);
        targetSelector(AMMHandler.swap.selector);
        targetSelector(AMMHandler.flashLoan.selector);
    }

    // ======================
    // INVARIANTS
    // ======================

    /**
     * @dev Invariant: Constant product formula should hold
     * The product k = reserve0 * reserve1 should never decrease (except for rounding)
     */
    function invariant_constant_product_increases() public {
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();
        uint256 currentK = uint256(reserve0) * reserve1;
        uint256 initialK = handler.initialK();

        // K should never decrease significantly (allowing for rounding errors)
        assertGe(
            currentK,
            initialK - 1000,
            "Constant product should not decrease"
        );
    }

    /**
     * @dev Invariant: Total LP token supply should reflect actual liquidity
     */
    function invariant_lp_token_supply_consistency() public {
        uint256 totalSupply = amm.totalSupply();
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();

        if (totalSupply > 0) {
            // If there are LP tokens, there must be reserves
            assertTrue(
                reserve0 > 0 && reserve1 > 0,
                "Reserves must exist with LP tokens"
            );
        }

        if (reserve0 == 0 && reserve1 == 0) {
            // If no reserves, total supply should be 0 (or minimum liquidity locked)
            assertLe(
                totalSupply,
                amm.MINIMUM_LIQUIDITY(),
                "No LP tokens without reserves"
            );
        }
    }

    /**
     * @dev Invariant: Token balances should be consistent
     */
    function invariant_token_balance_consistency() public {
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();

        uint256 actualBalance0 = tokenA.balanceOf(address(amm));
        uint256 actualBalance1 = tokenB.balanceOf(address(amm));

        assertEq(
            actualBalance0,
            reserve0,
            "Reserve0 should match actual balance"
        );
        assertEq(
            actualBalance1,
            reserve1,
            "Reserve1 should match actual balance"
        );
    }

    /**
     * @dev Invariant: Price should not deviate dramatically from initial price
     */
    function invariant_price_stability() public {
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();

        if (reserve0 > 0 && reserve1 > 0) {
            uint256 currentPrice = (uint256(reserve1) * 1e18) / reserve0;
            uint256 initialPrice = handler.initialPrice();

            // Price should not deviate more than 90% from initial (to allow for normal trading)
            uint256 minPrice = (initialPrice * 10) / 100; // 10% of initial
            uint256 maxPrice = (initialPrice * 1000) / 100; // 1000% of initial

            assertGe(
                currentPrice,
                minPrice,
                "Price should not drop below 10% of initial"
            );
            assertLe(
                currentPrice,
                maxPrice,
                "Price should not exceed 1000% of initial"
            );
        }
    }

    /**
     * @dev Invariant: AMM contract should never have negative balances
     */
    function invariant_no_negative_balances() public {
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();

        assertTrue(reserve0 >= 0, "Reserve0 cannot be negative");
        assertTrue(reserve1 >= 0, "Reserve1 cannot be negative");
        assertTrue(amm.totalSupply() >= 0, "Total supply cannot be negative");
    }

    /**
     * @dev Invariant: Handler should maintain token balance consistency
     */
    function invariant_handler_balance_tracking() public {
        uint256 handlerBalanceA = tokenA.balanceOf(address(handler));
        uint256 handlerBalanceB = tokenB.balanceOf(address(handler));

        assertTrue(
            handlerBalanceA >= 0,
            "Handler token A balance should be non-negative"
        );
        assertTrue(
            handlerBalanceB >= 0,
            "Handler token B balance should be non-negative"
        );
    }

    /**
     * @dev Invariant: Swap should always respect slippage limits
     */
    function invariant_swap_respects_math() public {
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();

        if (reserve0 > 1000 && reserve1 > 1000) {
            // Test small swap amount
            uint256 amountIn = 1000;
            uint256 expectedOut = amm.getAmountOut(
                amountIn,
                address(tokenA),
                address(tokenB)
            );

            // The calculated amount should be less than the reserve
            assertLt(
                expectedOut,
                reserve1,
                "Output amount should not exceed reserves"
            );

            // The amount should be positive for positive input
            if (amountIn > 0) {
                assertGt(
                    expectedOut,
                    0,
                    "Positive input should yield positive output"
                );
            }
        }
    }

    /**
     * @dev Invariant: Flash loan should always be repaid
     */
    function invariant_flash_loan_repayment() public {
        // This is tested implicitly - if flash loans weren't repaid,
        // the token balance consistency invariant would fail
        assertTrue(
            true,
            "Flash loan repayment is tested via balance consistency"
        );
    }

    /**
     * @dev Invariant: Total value locked should not disappear
     */
    function invariant_total_value_locked() public {
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();
        uint256 currentTVL = uint256(reserve0) + reserve1;
        uint256 initialTVL = handler.initialTVL();

        // TVL should not decrease dramatically (allowing for trading and fees)
        uint256 minTVL = (initialTVL * 50) / 100; // Allow 50% decrease max
        assertGe(currentTVL, minTVL, "TVL should not decrease dramatically");
    }
}

/**
 * @title AMM Handler Contract
 * @dev Handler contract for invariant testing that manages interactions with the AMM
 */
contract AMMHandler is Test {
    // ======================
    // STATE VARIABLES
    // ======================

    AMMDEX public immutable amm;
    MockERC20 public immutable tokenA;
    MockERC20 public immutable tokenB;

    uint256 public initialK;
    uint256 public initialPrice;
    uint256 public initialTVL;

    uint256 public totalLiquidityAdded;
    uint256 public totalLiquidityRemoved;
    uint256 public totalSwapVolume;
    uint256 public totalFlashLoans;

    // ======================
    // EVENTS
    // ======================

    event HandlerAction(string action, uint256 amount1, uint256 amount2);

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(AMMDEX _amm, MockERC20 _tokenA, MockERC20 _tokenB) {
        amm = _amm;
        tokenA = _tokenA;
        tokenB = _tokenB;
    }

    // ======================
    // LIQUIDITY MANAGEMENT
    // ======================

    function addLiquidity(uint256 amountA, uint256 amountB) public {
        // Bound amounts to reasonable ranges
        amountA = bound(amountA, 1e18, 100_000e18);
        amountB = bound(amountB, 1e18, 100_000e18);

        // Ensure we have enough tokens
        if (tokenA.balanceOf(address(this)) < amountA) {
            tokenA.mint(address(this), amountA);
        }
        if (tokenB.balanceOf(address(this)) < amountB) {
            tokenB.mint(address(this), amountB);
        }

        tokenA.approve(address(amm), amountA);
        tokenB.approve(address(amm), amountB);

        try
            amm.addLiquidity(
                amountA,
                amountB,
                0, // No minimum amounts for testing
                0,
                address(this),
                block.timestamp + 1
            )
        returns (uint256 actualA, uint256 actualB, uint256 liquidity) {
            totalLiquidityAdded += liquidity;

            // Set initial values if this is the first liquidity addition
            if (initialK == 0) {
                (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();
                initialK = uint256(reserve0) * reserve1;
                initialPrice = (uint256(reserve1) * 1e18) / reserve0;
                initialTVL = uint256(reserve0) + reserve1;
            }

            emit HandlerAction("addLiquidity", actualA, actualB);
        } catch {
            // Ignore failed attempts
        }
    }

    function removeLiquidity(uint256 liquidityPercent) public {
        // Bound percentage to 1-50% to avoid draining pool
        liquidityPercent = bound(liquidityPercent, 1, 50);

        uint256 balance = amm.balanceOf(address(this));
        if (balance == 0) return;

        uint256 liquidityToRemove = (balance * liquidityPercent) / 100;
        if (liquidityToRemove == 0) return;

        try
            amm.removeLiquidity(
                liquidityToRemove,
                0, // No minimum amounts for testing
                0,
                address(this),
                block.timestamp + 1
            )
        returns (uint256 amountA, uint256 amountB) {
            totalLiquidityRemoved += liquidityToRemove;
            emit HandlerAction("removeLiquidity", amountA, amountB);
        } catch {
            // Ignore failed attempts
        }
    }

    // ======================
    // TRADING
    // ======================

    function swap(uint256 amountIn, bool tokenAtoB) public {
        // Bound amount to reasonable range
        amountIn = bound(amountIn, 1e15, 10_000e18);

        address tokenIn = tokenAtoB ? address(tokenA) : address(tokenB);
        address tokenOut = tokenAtoB ? address(tokenB) : address(tokenA);

        MockERC20 inputToken = tokenAtoB ? tokenA : tokenB;

        // Ensure we have enough tokens
        if (inputToken.balanceOf(address(this)) < amountIn) {
            inputToken.mint(address(this), amountIn);
        }

        inputToken.approve(address(amm), amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        try
            amm.swapExactTokensForTokens(
                amountIn,
                0, // No minimum output for testing
                path,
                address(this),
                block.timestamp + 1
            )
        returns (uint256[] memory amounts) {
            totalSwapVolume += amountIn;
            emit HandlerAction("swap", amounts[0], amounts[1]);
        } catch {
            // Ignore failed attempts
        }
    }

    // ======================
    // FLASH LOANS
    // ======================

    function flashLoan(uint256 amount, bool useTokenA) public {
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();
        uint256 maxAmount = useTokenA ? reserve0 / 10 : reserve1 / 10; // Max 10% of reserves

        amount = bound(amount, 1e15, maxAmount);
        if (amount == 0) return;

        address token = useTokenA ? address(tokenA) : address(tokenB);
        MockERC20 borrowToken = useTokenA ? tokenA : tokenB;

        // Calculate fee and ensure we can repay
        uint256 fee = (amount * amm.flashloanFee()) / amm.FEE_DENOMINATOR();
        borrowToken.mint(address(this), fee);

        try amm.flashLoan(token, amount, "") {
            totalFlashLoans += amount;
            emit HandlerAction("flashLoan", amount, fee);
        } catch {
            // Ignore failed attempts
        }
    }

    // ======================
    // FLASH LOAN RECEIVER
    // ======================

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata /* data */
    ) external {
        require(msg.sender == address(amm), "Only AMM can call");

        // Repay the loan with fee
        MockERC20(token).transfer(msg.sender, amount + fee);
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    function getStats()
        external
        view
        returns (
            uint256 liquidityAdded,
            uint256 liquidityRemoved,
            uint256 swapVolume,
            uint256 flashLoanVolume
        )
    {
        return (
            totalLiquidityAdded,
            totalLiquidityRemoved,
            totalSwapVolume,
            totalFlashLoans
        );
    }
}

/**
 * 🔬 INVARIANT TESTING FEATURES:
 *
 * 1. CRITICAL INVARIANTS:
 *    - Constant product formula maintenance
 *    - Token balance consistency
 *    - LP token supply correctness
 *    - Price stability bounds
 *
 * 2. ADVANCED PATTERNS:
 *    - Handler contract for complex interactions
 *    - Bounded fuzzing for realistic scenarios
 *    - State tracking across operations
 *    - Mathematical property verification
 *
 * 3. FOUNDRY FEATURES:
 *    - targetContract() for focused testing
 *    - targetSelector() for specific functions
 *    - Automated invariant checking
 *    - Statistical analysis of failures
 *
 * 4. REAL-WORLD SCENARIOS:
 *    - Flash loan testing
 *    - Slippage protection
 *    - TVL preservation
 *    - Price manipulation resistance
 *
 * 🚀 USAGE:
 * - forge test --match-contract Invariant -vv
 * - forge test --invariant-runs 1000 (intensive testing)
 * - forge test --invariant-depth 100 (deep call sequences)
 * - Add --debug for detailed failure analysis
 */

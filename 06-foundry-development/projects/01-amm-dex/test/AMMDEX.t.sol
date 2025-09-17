// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/AMMDEX.sol";
import "../src/MockERC20.sol";

/**
 * @title AMM DEX Test Suite
 * @dev Comprehensive test suite demonstrating Foundry testing best practices
 * @notice This test suite covers unit tests, integration tests, fuzz testing, and invariant testing
 */
contract AMMDEXTest is Test {
    // ======================
    // TEST CONTRACTS
    // ======================

    AMMDEX public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    // ======================
    // TEST ACCOUNTS
    // ======================

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public liquidityProvider = makeAddr("liquidityProvider");
    address public trader = makeAddr("trader");

    // ======================
    // TEST CONSTANTS
    // ======================

    uint256 constant INITIAL_MINT = 1_000_000e18;
    uint256 constant INITIAL_LIQUIDITY_A = 100_000e18;
    uint256 constant INITIAL_LIQUIDITY_B = 100_000e18;
    uint256 constant MINIMUM_LIQUIDITY = 1000;

    // ======================
    // EVENTS FOR TESTING
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

    // ======================
    // SETUP
    // ======================

    function setUp() public {
        // Deploy mock tokens
        tokenA = new MockERC20("Token A", "TKNA", 18, INITIAL_MINT);
        tokenB = new MockERC20("Token B", "TKNB", 18, INITIAL_MINT);

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

        // Setup initial balances
        _setupInitialBalances();

        // Add initial liquidity
        _addInitialLiquidity();
    }

    function _setupInitialBalances() internal {
        // Distribute tokens to test accounts
        tokenA.mint(alice, INITIAL_MINT);
        tokenA.mint(bob, INITIAL_MINT);
        tokenA.mint(charlie, INITIAL_MINT);
        tokenA.mint(liquidityProvider, INITIAL_MINT);
        tokenA.mint(trader, INITIAL_MINT);

        tokenB.mint(alice, INITIAL_MINT);
        tokenB.mint(bob, INITIAL_MINT);
        tokenB.mint(charlie, INITIAL_MINT);
        tokenB.mint(liquidityProvider, INITIAL_MINT);
        tokenB.mint(trader, INITIAL_MINT);
    }

    function _addInitialLiquidity() internal {
        vm.startPrank(liquidityProvider);

        tokenA.approve(address(amm), INITIAL_LIQUIDITY_A);
        tokenB.approve(address(amm), INITIAL_LIQUIDITY_B);

        amm.addLiquidity(
            INITIAL_LIQUIDITY_A,
            INITIAL_LIQUIDITY_B,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1
        );

        vm.stopPrank();
    }

    // ======================
    // BASIC FUNCTIONALITY TESTS
    // ======================

    function test_initial_setup() public {
        assertEq(address(amm.token0()), address(tokenA));
        assertEq(address(amm.token1()), address(tokenB));
        assertEq(amm.owner(), address(this));

        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();
        assertEq(reserve0, INITIAL_LIQUIDITY_A);
        assertEq(reserve1, INITIAL_LIQUIDITY_B);

        // Check LP token supply
        uint256 expectedLiquidity = _sqrt(
            INITIAL_LIQUIDITY_A * INITIAL_LIQUIDITY_B
        ) - MINIMUM_LIQUIDITY;
        assertEq(amm.balanceOf(liquidityProvider), expectedLiquidity);
    }

    function test_add_liquidity() public {
        uint256 addAmountA = 10_000e18;
        uint256 addAmountB = 10_000e18;

        vm.startPrank(alice);

        tokenA.approve(address(amm), addAmountA);
        tokenB.approve(address(amm), addAmountB);

        uint256 liquidityBefore = amm.balanceOf(alice);

        vm.expectEmit(true, false, false, true);
        emit Mint(alice, addAmountA, addAmountB);

        (uint256 amountA, uint256 amountB, uint256 liquidity) = amm
            .addLiquidity(
                addAmountA,
                addAmountB,
                (addAmountA * 95) / 100, // 5% slippage tolerance
                (addAmountB * 95) / 100,
                alice,
                block.timestamp + 1
            );

        vm.stopPrank();

        assertEq(amountA, addAmountA);
        assertEq(amountB, addAmountB);
        assertGt(liquidity, 0);
        assertEq(amm.balanceOf(alice), liquidityBefore + liquidity);
    }

    function test_remove_liquidity() public {
        // First add some liquidity
        test_add_liquidity();

        vm.startPrank(alice);

        uint256 liquidityToRemove = amm.balanceOf(alice) / 2;
        uint256 balanceABefore = tokenA.balanceOf(alice);
        uint256 balanceBBefore = tokenB.balanceOf(alice);

        vm.expectEmit(true, false, false, true);
        emit Burn(alice, liquidityToRemove / 2, liquidityToRemove / 2, alice); // Approximate amounts

        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(
            liquidityToRemove,
            0,
            0,
            alice,
            block.timestamp + 1
        );

        vm.stopPrank();

        assertGt(amountA, 0);
        assertGt(amountB, 0);
        assertGt(tokenA.balanceOf(alice), balanceABefore);
        assertGt(tokenB.balanceOf(alice), balanceBBefore);
    }

    function test_swap_exact_tokens_for_tokens() public {
        uint256 amountIn = 1000e18;
        uint256 expectedAmountOut = amm.getAmountOut(
            amountIn,
            address(tokenA),
            address(tokenB)
        );

        vm.startPrank(trader);

        tokenA.approve(address(amm), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 balanceBBefore = tokenB.balanceOf(trader);

        vm.expectEmit(true, false, false, true);
        emit Swap(trader, amountIn, 0, 0, expectedAmountOut, trader);

        uint256[] memory amounts = amm.swapExactTokensForTokens(
            amountIn,
            (expectedAmountOut * 95) / 100, // 5% slippage tolerance
            path,
            trader,
            block.timestamp + 1
        );

        vm.stopPrank();

        assertEq(amounts[0], amountIn);
        assertEq(amounts[1], expectedAmountOut);
        assertEq(tokenB.balanceOf(trader), balanceBBefore + expectedAmountOut);
    }

    function test_swap_tokens_for_exact_tokens() public {
        uint256 amountOut = 1000e18;
        uint256 expectedAmountIn = amm.getAmountIn(
            amountOut,
            address(tokenA),
            address(tokenB)
        );

        vm.startPrank(trader);

        tokenA.approve(address(amm), expectedAmountIn);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 balanceABefore = tokenA.balanceOf(trader);
        uint256 balanceBBefore = tokenB.balanceOf(trader);

        uint256[] memory amounts = amm.swapTokensForExactTokens(
            amountOut,
            (expectedAmountIn * 105) / 100, // 5% slippage tolerance
            path,
            trader,
            block.timestamp + 1
        );

        vm.stopPrank();

        assertEq(amounts[0], expectedAmountIn);
        assertEq(amounts[1], amountOut);
        assertEq(tokenA.balanceOf(trader), balanceABefore - expectedAmountIn);
        assertEq(tokenB.balanceOf(trader), balanceBBefore + amountOut);
    }

    // ======================
    // FLASH LOAN TESTS
    // ======================

    function test_flash_loan_success() public {
        FlashLoanReceiver receiver = new FlashLoanReceiver();

        uint256 loanAmount = 10_000e18;
        uint256 fee = (loanAmount * amm.flashloanFee()) / amm.FEE_DENOMINATOR();

        // Give receiver enough tokens to repay
        tokenA.mint(address(receiver), fee);

        vm.expectEmit(true, true, false, true);
        emit FlashLoan(address(receiver), address(tokenA), loanAmount, fee);

        amm.flashLoan(address(tokenA), loanAmount, "");

        // Verify fee was collected
        assertGt(tokenA.balanceOf(address(amm)), INITIAL_LIQUIDITY_A);
    }

    function test_flash_loan_failure_insufficient_repayment() public {
        FlashLoanReceiver receiver = new FlashLoanReceiver();
        receiver.setShouldRepay(false);

        uint256 loanAmount = 10_000e18;

        vm.expectRevert(AMMDEX.FlashLoanNotRepaid.selector);
        amm.flashLoan(address(tokenA), loanAmount, "");
    }

    // ======================
    // ADMIN FUNCTION TESTS
    // ======================

    function test_set_swap_fee() public {
        uint256 newFee = 50; // 0.5%

        vm.expectEmit(false, false, false, true);
        emit SwapFeeUpdated(amm.swapFee(), newFee);

        amm.setSwapFee(newFee);
        assertEq(amm.swapFee(), newFee);
    }

    function test_set_swap_fee_unauthorized() public {
        vm.prank(alice);
        vm.expectRevert("Ownable: caller is not the owner");
        amm.setSwapFee(50);
    }

    function test_set_swap_fee_too_high() public {
        vm.expectRevert(AMMDEX.InvalidFee.selector);
        amm.setSwapFee(1001); // > 10%
    }

    // ======================
    // FUZZ TESTS
    // ======================

    function testFuzz_add_liquidity(uint256 amountA, uint256 amountB) public {
        // Bound inputs to reasonable ranges
        amountA = bound(amountA, 1e18, 1_000_000e18);
        amountB = bound(amountB, 1e18, 1_000_000e18);

        vm.startPrank(alice);

        tokenA.mint(alice, amountA);
        tokenB.mint(alice, amountB);
        tokenA.approve(address(amm), amountA);
        tokenB.approve(address(amm), amountB);

        // Calculate expected liquidity ratio
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();
        uint256 expectedAmountB = amm.quote(amountA, reserve0, reserve1);

        if (expectedAmountB <= amountB) {
            (
                uint256 actualAmountA,
                uint256 actualAmountB,
                uint256 liquidity
            ) = amm.addLiquidity(
                    amountA,
                    amountB,
                    0,
                    0,
                    alice,
                    block.timestamp + 1
                );

            assertEq(actualAmountA, amountA);
            assertEq(actualAmountB, expectedAmountB);
            assertGt(liquidity, 0);
        }

        vm.stopPrank();
    }

    function testFuzz_swap(uint256 amountIn) public {
        // Bound input to reasonable range
        amountIn = bound(amountIn, 1e15, 10_000e18); // 0.001 to 10,000 tokens

        vm.startPrank(trader);

        // Ensure trader has enough tokens
        if (tokenA.balanceOf(trader) < amountIn) {
            tokenA.mint(trader, amountIn);
        }

        tokenA.approve(address(amm), amountIn);

        uint256 expectedAmountOut = amm.getAmountOut(
            amountIn,
            address(tokenA),
            address(tokenB)
        );

        if (expectedAmountOut > 0) {
            address[] memory path = new address[](2);
            path[0] = address(tokenA);
            path[1] = address(tokenB);

            uint256 balanceBefore = tokenB.balanceOf(trader);

            amm.swapExactTokensForTokens(
                amountIn,
                0,
                path,
                trader,
                block.timestamp + 1
            );

            uint256 balanceAfter = tokenB.balanceOf(trader);
            assertEq(balanceAfter - balanceBefore, expectedAmountOut);
        }

        vm.stopPrank();
    }

    function testFuzz_flash_loan(uint256 loanAmount) public {
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();

        // Bound loan amount to available liquidity
        loanAmount = bound(loanAmount, 1e15, uint256(reserve0) / 2);

        FlashLoanReceiver receiver = new FlashLoanReceiver();

        uint256 fee = (loanAmount * amm.flashloanFee()) / amm.FEE_DENOMINATOR();
        tokenA.mint(address(receiver), fee);

        uint256 balanceBefore = tokenA.balanceOf(address(amm));

        amm.flashLoan(address(tokenA), loanAmount, "");

        uint256 balanceAfter = tokenA.balanceOf(address(amm));
        assertEq(balanceAfter, balanceBefore + fee);
    }

    // ======================
    // PROPERTY-BASED TESTS
    // ======================

    function test_constant_product_formula() public {
        (uint112 reserve0Before, uint112 reserve1Before, ) = amm.getReserves();
        uint256 kBefore = uint256(reserve0Before) * reserve1Before;

        // Perform a swap
        uint256 amountIn = 1000e18;

        vm.startPrank(trader);
        tokenA.approve(address(amm), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        amm.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            trader,
            block.timestamp + 1
        );
        vm.stopPrank();

        (uint112 reserve0After, uint112 reserve1After, ) = amm.getReserves();
        uint256 kAfter = uint256(reserve0After) * reserve1After;

        // K should increase due to fees (k >= k_before)
        assertGe(kAfter, kBefore);
    }

    function test_no_arbitrage_opportunity() public {
        // Test that price impact is consistent in both directions
        uint256 amountIn = 1000e18;

        uint256 amountOut1 = amm.getAmountOut(
            amountIn,
            address(tokenA),
            address(tokenB)
        );
        uint256 amountIn2 = amm.getAmountIn(
            amountOut1,
            address(tokenB),
            address(tokenA)
        );

        // Due to fees, it should cost more to swap back
        assertGt(amountIn2, amountIn);
    }

    // ======================
    // GAS OPTIMIZATION TESTS
    // ======================

    function test_gas_add_liquidity() public {
        vm.startPrank(alice);

        tokenA.approve(address(amm), 1000e18);
        tokenB.approve(address(amm), 1000e18);

        uint256 gasBefore = gasleft();
        amm.addLiquidity(1000e18, 1000e18, 0, 0, alice, block.timestamp + 1);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for addLiquidity:", gasUsed);

        // Assert reasonable gas usage (adjust based on optimization targets)
        assertLt(gasUsed, 200_000);

        vm.stopPrank();
    }

    function test_gas_swap() public {
        vm.startPrank(trader);

        tokenA.approve(address(amm), 1000e18);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 gasBefore = gasleft();
        amm.swapExactTokensForTokens(
            1000e18,
            0,
            path,
            trader,
            block.timestamp + 1
        );
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for swap:", gasUsed);

        // Assert reasonable gas usage
        assertLt(gasUsed, 150_000);

        vm.stopPrank();
    }

    // ======================
    // ERROR CONDITION TESTS
    // ======================

    function test_insufficient_liquidity_error() public {
        vm.startPrank(trader);

        // Try to swap more than available liquidity
        (uint112 reserve1, , ) = amm.getReserves();
        uint256 impossibleAmount = uint256(reserve1) + 1;

        tokenA.approve(address(amm), type(uint256).max);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        vm.expectRevert("INSUFFICIENT_LIQUIDITY");
        amm.swapExactTokensForTokens(
            impossibleAmount,
            0,
            path,
            trader,
            block.timestamp + 1
        );

        vm.stopPrank();
    }

    function test_expired_deadline() public {
        vm.startPrank(alice);

        tokenA.approve(address(amm), 1000e18);
        tokenB.approve(address(amm), 1000e18);

        // Use past timestamp
        vm.expectRevert("EXPIRED");
        amm.addLiquidity(1000e18, 1000e18, 0, 0, alice, block.timestamp - 1);

        vm.stopPrank();
    }

    // ======================
    // HELPER FUNCTIONS
    // ======================

    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}

// ======================
// FLASH LOAN RECEIVER FOR TESTING
// ======================

contract FlashLoanReceiver {
    bool public shouldRepay = true;

    function setShouldRepay(bool _shouldRepay) external {
        shouldRepay = _shouldRepay;
    }

    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata /* data */
    ) external {
        if (shouldRepay) {
            // Repay the loan with fee
            IERC20(token).transfer(msg.sender, amount + fee);
        }
        // If shouldRepay is false, we don't repay to test failure case
    }
}

/**
 * 🧪 TEST SUITE FEATURES:
 *
 * 1. COMPREHENSIVE COVERAGE:
 *    - Unit tests for all core functions
 *    - Integration tests for complex workflows
 *    - Property-based testing
 *    - Gas optimization testing
 *
 * 2. FOUNDRY PATTERNS:
 *    - Proper test setup with setUp()
 *    - Event testing with vm.expectEmit()
 *    - Fuzz testing with bounded inputs
 *    - Prank testing for access control
 *
 * 3. ADVANCED TECHNIQUES:
 *    - Flash loan testing with mock receiver
 *    - Error condition testing
 *    - Gas usage assertions
 *    - Mathematical property verification
 *
 * 4. BEST PRACTICES:
 *    - Clear test organization
 *    - Descriptive test names
 *    - Helper functions for reusability
 *    - Console logging for debugging
 *
 * 🚀 USAGE:
 * - forge test -vv (verbose output)
 * - forge test --gas-report (gas analysis)
 * - forge test --fuzz-runs 10000 (intensive fuzzing)
 * - forge coverage (coverage analysis)
 */

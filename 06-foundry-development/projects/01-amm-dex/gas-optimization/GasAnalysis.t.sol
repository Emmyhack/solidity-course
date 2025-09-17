// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/AMMDEX.sol";
import "../src/MockERC20.sol";

/**
 * @title Gas Optimization Analysis
 * @dev Comprehensive gas analysis and optimization testing for AMM DEX
 * @notice This contract provides detailed gas usage analysis for all AMM operations
 */
contract GasOptimizationTest is Test {
    // ======================
    // TEST CONTRACTS
    // ======================

    AMMDEX public amm;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    // ======================
    // TEST ACCOUNTS
    // ======================

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public liquidityProvider = makeAddr("liquidityProvider");

    // ======================
    // GAS TRACKING
    // ======================

    struct GasReport {
        uint256 addLiquidity;
        uint256 removeLiquidity;
        uint256 swapExactTokensForTokens;
        uint256 swapTokensForExactTokens;
        uint256 flashLoan;
        uint256 skim;
        uint256 sync;
    }

    GasReport public gasUsage;

    // ======================
    // SETUP
    // ======================

    function setUp() public {
        // Deploy contracts
        tokenA = new MockERC20("Token A", "TKNA", 18, 10_000_000e18);
        tokenB = new MockERC20("Token B", "TKNB", 18, 10_000_000e18);

        // Ensure proper ordering
        if (address(tokenA) > address(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        amm = new AMMDEX(address(tokenA), address(tokenB), "AMM LP", "AMM-LP");

        // Setup balances
        _setupBalances();

        // Add initial liquidity
        _addInitialLiquidity();
    }

    function _setupBalances() internal {
        tokenA.mint(user1, 1_000_000e18);
        tokenA.mint(user2, 1_000_000e18);
        tokenA.mint(liquidityProvider, 1_000_000e18);

        tokenB.mint(user1, 1_000_000e18);
        tokenB.mint(user2, 1_000_000e18);
        tokenB.mint(liquidityProvider, 1_000_000e18);
    }

    function _addInitialLiquidity() internal {
        vm.startPrank(liquidityProvider);

        tokenA.approve(address(amm), 100_000e18);
        tokenB.approve(address(amm), 100_000e18);

        amm.addLiquidity(
            100_000e18,
            100_000e18,
            0,
            0,
            liquidityProvider,
            block.timestamp + 1
        );

        vm.stopPrank();
    }

    // ======================
    // GAS OPTIMIZATION TESTS
    // ======================

    function test_gas_addLiquidity_first_time() public {
        // Reset AMM for first-time test
        AMMDEX newAmm = new AMMDEX(
            address(tokenA),
            address(tokenB),
            "New AMM LP",
            "NEW-LP"
        );

        vm.startPrank(user1);

        tokenA.approve(address(newAmm), 50_000e18);
        tokenB.approve(address(newAmm), 50_000e18);

        uint256 gasBefore = gasleft();
        newAmm.addLiquidity(
            50_000e18,
            50_000e18,
            0,
            0,
            user1,
            block.timestamp + 1
        );
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console.log("Gas used for first addLiquidity:", gasUsed);
        gasUsage.addLiquidity = gasUsed;

        // First liquidity addition is more expensive due to MINIMUM_LIQUIDITY burn
        assertLt(
            gasUsed,
            250_000,
            "First addLiquidity should be under 250k gas"
        );
    }

    function test_gas_addLiquidity_subsequent() public {
        vm.startPrank(user1);

        tokenA.approve(address(amm), 10_000e18);
        tokenB.approve(address(amm), 10_000e18);

        uint256 gasBefore = gasleft();
        amm.addLiquidity(
            10_000e18,
            10_000e18,
            0,
            0,
            user1,
            block.timestamp + 1
        );
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console.log("Gas used for subsequent addLiquidity:", gasUsed);

        // Subsequent additions should be cheaper
        assertLt(
            gasUsed,
            200_000,
            "Subsequent addLiquidity should be under 200k gas"
        );
    }

    function test_gas_removeLiquidity() public {
        // First add liquidity as user1
        test_gas_addLiquidity_subsequent();

        vm.startPrank(user1);

        uint256 liquidity = amm.balanceOf(user1);
        uint256 liquidityToRemove = liquidity / 2;

        uint256 gasBefore = gasleft();
        amm.removeLiquidity(
            liquidityToRemove,
            0,
            0,
            user1,
            block.timestamp + 1
        );
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console.log("Gas used for removeLiquidity:", gasUsed);
        gasUsage.removeLiquidity = gasUsed;

        assertLt(gasUsed, 150_000, "RemoveLiquidity should be under 150k gas");
    }

    function test_gas_swap_exact_tokens_for_tokens() public {
        vm.startPrank(user1);

        uint256 amountIn = 1000e18;
        tokenA.approve(address(amm), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 gasBefore = gasleft();
        amm.swapExactTokensForTokens(
            amountIn,
            0,
            path,
            user1,
            block.timestamp + 1
        );
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console.log("Gas used for swapExactTokensForTokens:", gasUsed);
        gasUsage.swapExactTokensForTokens = gasUsed;

        assertLt(
            gasUsed,
            120_000,
            "SwapExactTokensForTokens should be under 120k gas"
        );
    }

    function test_gas_swap_tokens_for_exact_tokens() public {
        vm.startPrank(user1);

        uint256 amountOut = 1000e18;
        uint256 maxAmountIn = amm.getAmountIn(
            amountOut,
            address(tokenA),
            address(tokenB)
        );
        tokenA.approve(address(amm), maxAmountIn);

        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 gasBefore = gasleft();
        amm.swapTokensForExactTokens(
            amountOut,
            maxAmountIn,
            path,
            user1,
            block.timestamp + 1
        );
        uint256 gasUsed = gasBefore - gasleft();

        vm.stopPrank();

        console.log("Gas used for swapTokensForExactTokens:", gasUsed);
        gasUsage.swapTokensForExactTokens = gasUsed;

        assertLt(
            gasUsed,
            120_000,
            "SwapTokensForExactTokens should be under 120k gas"
        );
    }

    function test_gas_flash_loan() public {
        FlashLoanTester tester = new FlashLoanTester();

        uint256 loanAmount = 10_000e18;
        uint256 fee = (loanAmount * amm.flashloanFee()) / amm.FEE_DENOMINATOR();

        // Give tester tokens to pay fee
        tokenA.mint(address(tester), fee);

        uint256 gasBefore = gasleft();
        amm.flashLoan(address(tokenA), loanAmount, "");
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for flashLoan:", gasUsed);
        gasUsage.flashLoan = gasUsed;

        assertLt(gasUsed, 100_000, "FlashLoan should be under 100k gas");
    }

    function test_gas_skim() public {
        // Manually send extra tokens to create imbalance
        tokenA.mint(address(amm), 1000e18);

        uint256 gasBefore = gasleft();
        amm.skim(user1);
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for skim:", gasUsed);
        gasUsage.skim = gasUsed;

        assertLt(gasUsed, 50_000, "Skim should be under 50k gas");
    }

    function test_gas_sync() public {
        // Force balance mismatch for sync test
        tokenA.mint(address(amm), 1000e18);

        uint256 gasBefore = gasleft();
        amm.sync();
        uint256 gasUsed = gasBefore - gasleft();

        console.log("Gas used for sync:", gasUsed);
        gasUsage.sync = gasUsed;

        assertLt(gasUsed, 30_000, "Sync should be under 30k gas");
    }

    // ======================
    // BATCH OPERATION TESTS
    // ======================

    function test_gas_multiple_swaps() public {
        vm.startPrank(user1);

        uint256 totalGas = 0;
        uint256 iterations = 10;

        for (uint256 i = 0; i < iterations; i++) {
            uint256 amountIn = 100e18;
            tokenA.approve(address(amm), amountIn);

            address[] memory path = new address[](2);
            path[0] = address(tokenA);
            path[1] = address(tokenB);

            uint256 gasBefore = gasleft();
            amm.swapExactTokensForTokens(
                amountIn,
                0,
                path,
                user1,
                block.timestamp + 1
            );
            uint256 gasUsed = gasBefore - gasleft();

            totalGas += gasUsed;
        }

        vm.stopPrank();

        uint256 avgGas = totalGas / iterations;
        console.log("Average gas per swap over", iterations, "swaps:", avgGas);

        // Should maintain efficiency even with multiple swaps
        assertLt(avgGas, 150_000, "Average swap gas should remain efficient");
    }

    function test_gas_liquidity_operations_cycle() public {
        vm.startPrank(user2);

        // Approve large amounts once
        tokenA.approve(address(amm), 100_000e18);
        tokenB.approve(address(amm), 100_000e18);

        uint256 totalGas = 0;

        // Add liquidity
        uint256 gasBefore = gasleft();
        (, , uint256 liquidity) = amm.addLiquidity(
            10_000e18,
            10_000e18,
            0,
            0,
            user2,
            block.timestamp + 1
        );
        uint256 addGas = gasBefore - gasleft();
        totalGas += addGas;

        // Remove half liquidity
        gasBefore = gasleft();
        amm.removeLiquidity(liquidity / 2, 0, 0, user2, block.timestamp + 1);
        uint256 removeGas = gasBefore - gasleft();
        totalGas += removeGas;

        vm.stopPrank();

        console.log("Gas for add + remove liquidity cycle:", totalGas);
        console.log("  Add liquidity gas:", addGas);
        console.log("  Remove liquidity gas:", removeGas);

        assertLt(
            totalGas,
            300_000,
            "Full liquidity cycle should be under 300k gas"
        );
    }

    // ======================
    // GAS OPTIMIZATION COMPARISONS
    // ======================

    function test_gas_comparison_different_amounts() public {
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 100e18; // Small
        amounts[1] = 1_000e18; // Medium
        amounts[2] = 10_000e18; // Large
        amounts[3] = 50_000e18; // Very large

        vm.startPrank(user1);

        for (uint256 i = 0; i < amounts.length; i++) {
            tokenA.approve(address(amm), amounts[i]);

            address[] memory path = new address[](2);
            path[0] = address(tokenA);
            path[1] = address(tokenB);

            uint256 gasBefore = gasleft();
            amm.swapExactTokensForTokens(
                amounts[i],
                0,
                path,
                user1,
                block.timestamp + 1
            );
            uint256 gasUsed = gasBefore - gasleft();

            console.log("Gas for", amounts[i] / 1e18, "token swap:", gasUsed);

            // Gas should not scale significantly with amount
            assertLt(
                gasUsed,
                150_000,
                "Gas should not increase significantly with amount"
            );
        }

        vm.stopPrank();
    }

    function test_gas_impact_of_reserve_size() public {
        // Create AMMs with different reserve sizes
        AMMDEX smallAmm = _createAMMWithLiquidity(1_000e18, 1_000e18);
        AMMDEX mediumAmm = _createAMMWithLiquidity(100_000e18, 100_000e18);
        AMMDEX largeAmm = _createAMMWithLiquidity(1_000_000e18, 1_000_000e18);

        AMMDEX[] memory amms = new AMMDEX[](3);
        amms[0] = smallAmm;
        amms[1] = mediumAmm;
        amms[2] = largeAmm;

        string[] memory sizes = new string[](3);
        sizes[0] = "Small";
        sizes[1] = "Medium";
        sizes[2] = "Large";

        vm.startPrank(user1);

        for (uint256 i = 0; i < amms.length; i++) {
            uint256 swapAmount = 1000e18;
            tokenA.approve(address(amms[i]), swapAmount);

            address[] memory path = new address[](2);
            path[0] = address(tokenA);
            path[1] = address(tokenB);

            uint256 gasBefore = gasleft();
            amms[i].swapExactTokensForTokens(
                swapAmount,
                0,
                path,
                user1,
                block.timestamp + 1
            );
            uint256 gasUsed = gasBefore - gasleft();

            console.log(sizes[i], "AMM swap gas:", gasUsed);
        }

        vm.stopPrank();
    }

    function _createAMMWithLiquidity(
        uint256 amountA,
        uint256 amountB
    ) internal returns (AMMDEX) {
        AMMDEX newAmm = new AMMDEX(
            address(tokenA),
            address(tokenB),
            "Test AMM LP",
            "TEST-LP"
        );

        tokenA.approve(address(newAmm), amountA);
        tokenB.approve(address(newAmm), amountB);

        newAmm.addLiquidity(
            amountA,
            amountB,
            0,
            0,
            address(this),
            block.timestamp + 1
        );

        return newAmm;
    }

    // ======================
    // GAS OPTIMIZATION REPORT
    // ======================

    function test_generate_gas_report() public {
        // Run all gas tests to populate gasUsage struct
        test_gas_addLiquidity_first_time();
        test_gas_removeLiquidity();
        test_gas_swap_exact_tokens_for_tokens();
        test_gas_swap_tokens_for_exact_tokens();
        test_gas_flash_loan();
        test_gas_skim();
        test_gas_sync();

        console.log("\n=== AMM DEX GAS OPTIMIZATION REPORT ===");
        console.log("Add Liquidity (first):", gasUsage.addLiquidity);
        console.log("Remove Liquidity:", gasUsage.removeLiquidity);
        console.log("Swap Exact Tokens:", gasUsage.swapExactTokensForTokens);
        console.log(
            "Swap For Exact Tokens:",
            gasUsage.swapTokensForExactTokens
        );
        console.log("Flash Loan:", gasUsage.flashLoan);
        console.log("Skim:", gasUsage.skim);
        console.log("Sync:", gasUsage.sync);
        console.log("=====================================\n");

        // Verify all operations are reasonably gas efficient
        assertTrue(gasUsage.addLiquidity > 0, "Add liquidity gas recorded");
        assertTrue(
            gasUsage.removeLiquidity > 0,
            "Remove liquidity gas recorded"
        );
        assertTrue(
            gasUsage.swapExactTokensForTokens > 0,
            "Swap exact tokens gas recorded"
        );
        assertTrue(gasUsage.flashLoan > 0, "Flash loan gas recorded");
    }
}

/**
 * @title Flash Loan Tester Contract
 * @dev Simple contract for testing flash loan gas usage
 */
contract FlashLoanTester {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata /* data */
    ) external {
        // Simple repayment
        IERC20(token).transfer(msg.sender, amount + fee);
    }
}

/**
 * ⛽ GAS OPTIMIZATION FEATURES:
 *
 * 1. COMPREHENSIVE ANALYSIS:
 *    - Individual operation gas costs
 *    - Batch operation efficiency
 *    - Impact of different parameters
 *    - Reserve size effect on gas usage
 *
 * 2. OPTIMIZATION INSIGHTS:
 *    - First vs subsequent liquidity additions
 *    - Gas scaling with transaction amounts
 *    - Efficiency of different swap types
 *    - Flash loan overhead analysis
 *
 * 3. BENCHMARKING:
 *    - Gas usage targets for each operation
 *    - Performance regression detection
 *    - Comparison across scenarios
 *    - Detailed reporting capabilities
 *
 * 4. REAL-WORLD SCENARIOS:
 *    - Multiple consecutive operations
 *    - Different AMM sizes and liquidity
 *    - Realistic transaction patterns
 *    - Edge case gas consumption
 *
 * 📊 USAGE:
 * - forge test --match-contract GasOptimization --gas-report
 * - Use detailed gas reporting for optimization
 * - Monitor gas costs across contract changes
 * - Identify optimization opportunities
 */

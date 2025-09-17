// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../examples/Counter.sol";

/**
 * @title CounterFuzzTest
 * @dev Advanced fuzzing examples for the Counter contract
 * @notice Demonstrates property-based testing and invariant testing
 */
contract CounterFuzzTest is Test {
    Counter public counter;

    // Test configuration
    uint256 public constant MAX_COUNT = type(uint256).max;
    uint256 public constant INITIAL_COUNT = 100;

    function setUp() public {
        counter = new Counter(INITIAL_COUNT);
    }

    // ============ BASIC FUZZ TESTS ============

    /**
     * @dev Fuzz test for increment by amount
     */
    function testFuzz_IncrementBy(uint256 amount) public {
        // Bound to prevent overflow
        uint256 currentCount = counter.count();
        amount = bound(amount, 0, MAX_COUNT - currentCount);

        uint256 expectedCount = currentCount + amount;
        counter.incrementBy(amount);

        assertEq(counter.count(), expectedCount);
    }

    /**
     * @dev Fuzz test for decrement by amount
     */
    function testFuzz_DecrementBy(uint256 amount) public {
        uint256 currentCount = counter.count();

        if (amount > currentCount) {
            // Should revert
            vm.expectRevert(Counter.CannotDecrementBelowZero.selector);
            counter.decrementBy(amount);
        } else {
            // Should succeed
            uint256 expectedCount = currentCount - amount;
            counter.decrementBy(amount);
            assertEq(counter.count(), expectedCount);
        }
    }

    /**
     * @dev Fuzz test for set count (owner only)
     */
    function testFuzz_SetCount(uint256 newCount) public {
        counter.setCount(newCount);
        assertEq(counter.count(), newCount);
    }

    /**
     * @dev Fuzz test ownership transfer
     */
    function testFuzz_OwnershipTransfer(address newOwner) public {
        // Assume non-zero address
        vm.assume(newOwner != address(0));

        counter.transferOwnership(newOwner);
        assertEq(counter.owner(), newOwner);
    }

    // ============ PROPERTY-BASED TESTS ============

    /**
     * @dev Property: Increment then decrement should return to original state
     */
    function testProperty_IncrementDecrementSymmetry(uint256 amount) public {
        // Bound amount to prevent overflow/underflow
        uint256 currentCount = counter.count();
        amount = bound(amount, 1, min(currentCount, MAX_COUNT - currentCount));

        uint256 originalCount = counter.count();

        // Increment then decrement
        counter.incrementBy(amount);
        counter.decrementBy(amount);

        // Should return to original state
        assertEq(counter.count(), originalCount);
    }

    /**
     * @dev Property: Multiple small increments equal one large increment
     */
    function testProperty_AdditivityOfIncrements(
        uint8 numIncrements,
        uint256 baseAmount
    ) public {
        vm.assume(numIncrements > 0 && numIncrements <= 10);

        // Bound to prevent overflow
        uint256 currentCount = counter.count();
        baseAmount = bound(
            baseAmount,
            1,
            (MAX_COUNT - currentCount) / numIncrements
        );

        uint256 originalCount = counter.count();
        uint256 totalIncrement = baseAmount * numIncrements;

        // Method 1: Multiple small increments
        Counter counter1 = new Counter(originalCount);
        for (uint256 i = 0; i < numIncrements; i++) {
            counter1.incrementBy(baseAmount);
        }

        // Method 2: One large increment
        Counter counter2 = new Counter(originalCount);
        counter2.incrementBy(totalIncrement);

        // Results should be equal
        assertEq(counter1.count(), counter2.count());
        assertEq(counter1.count(), originalCount + totalIncrement);
    }

    /**
     * @dev Property: Count should never exceed max value after operations
     */
    function testProperty_NoOverflow(uint256 amount1, uint256 amount2) public {
        // Test that our bounds prevent overflow
        uint256 currentCount = counter.count();
        amount1 = bound(amount1, 0, MAX_COUNT - currentCount);

        counter.incrementBy(amount1);
        uint256 newCount = counter.count();

        amount2 = bound(amount2, 0, MAX_COUNT - newCount);
        counter.incrementBy(amount2);

        // Should never overflow
        assertLe(counter.count(), MAX_COUNT);
        assertEq(counter.count(), currentCount + amount1 + amount2);
    }

    /**
     * @dev Property: Count should never underflow
     */
    function testProperty_NoUnderflow(
        uint256 increment,
        uint256 decrement
    ) public {
        uint256 currentCount = counter.count();
        increment = bound(increment, 0, MAX_COUNT - currentCount);

        counter.incrementBy(increment);
        uint256 newCount = counter.count();

        // Test decrement
        if (decrement > newCount) {
            vm.expectRevert(Counter.CannotDecrementBelowZero.selector);
            counter.decrementBy(decrement);
        } else {
            counter.decrementBy(decrement);
            assertGe(counter.count(), 0);
            assertEq(counter.count(), newCount - decrement);
        }
    }

    // ============ STATEFUL FUZZ TESTS ============

    /**
     * @dev Stateful fuzz test with random operations
     */
    function testFuzz_RandomOperations(
        uint256 seed,
        uint8 numOperations
    ) public {
        numOperations = uint8(bound(numOperations, 1, 20));

        uint256 rng = seed;

        for (uint256 i = 0; i < numOperations; i++) {
            uint256 operation = rng % 4; // 4 different operations
            rng = uint256(keccak256(abi.encode(rng)));

            uint256 amount = bound(rng % type(uint64).max, 1, 1000);
            rng = uint256(keccak256(abi.encode(rng)));

            if (operation == 0) {
                // Increment
                uint256 currentCount = counter.count();
                if (amount <= MAX_COUNT - currentCount) {
                    counter.incrementBy(amount);
                }
            } else if (operation == 1) {
                // Decrement
                uint256 currentCount = counter.count();
                if (amount <= currentCount) {
                    counter.decrementBy(amount);
                }
            } else if (operation == 2) {
                // Reset (as owner)
                counter.reset();
            } else {
                // Set count (as owner)
                uint256 newCount = bound(amount, 0, 1000000);
                counter.setCount(newCount);
            }

            // Invariant: count should always be valid
            assertGe(counter.count(), 0);
            assertLe(counter.count(), MAX_COUNT);
        }
    }

    // ============ COMPLEX SCENARIOS ============

    /**
     * @dev Fuzz test pause functionality
     */
    function testFuzz_PauseFunctionality(
        uint256 amount,
        bool shouldPause
    ) public {
        amount = bound(amount, 1, min(1000, counter.count()));

        if (shouldPause) {
            counter.togglePause();
            assertTrue(counter.paused());

            // All operations should revert when paused
            vm.expectRevert(Counter.ContractPaused.selector);
            counter.increment();

            vm.expectRevert(Counter.ContractPaused.selector);
            counter.decrement();

            vm.expectRevert(Counter.ContractPaused.selector);
            counter.incrementBy(amount);

            vm.expectRevert(Counter.ContractPaused.selector);
            counter.decrementBy(amount);
        } else {
            assertFalse(counter.paused());

            // Operations should work normally
            uint256 originalCount = counter.count();
            counter.incrementBy(amount);
            assertEq(counter.count(), originalCount + amount);
        }
    }

    /**
     * @dev Fuzz test with different users
     */
    function testFuzz_MultipleUsers(
        address user1,
        address user2,
        uint256 amount,
        bool transferOwnership
    ) public {
        // Assume valid users
        vm.assume(user1 != address(0));
        vm.assume(user2 != address(0));
        vm.assume(user1 != user2);
        amount = bound(amount, 1, 1000);

        uint256 originalCount = counter.count();

        if (transferOwnership) {
            // Transfer ownership to user1
            counter.transferOwnership(user1);
            assertEq(counter.owner(), user1);

            // user1 should be able to perform owner functions
            vm.prank(user1);
            counter.setCount(amount);
            assertEq(counter.count(), amount);

            // user2 should not be able to perform owner functions
            vm.expectRevert(Counter.OnlyOwner.selector);
            vm.prank(user2);
            counter.reset();
        } else {
            // Non-owners should not be able to perform owner functions
            vm.expectRevert(Counter.OnlyOwner.selector);
            vm.prank(user1);
            counter.setCount(amount);

            vm.expectRevert(Counter.OnlyOwner.selector);
            vm.prank(user2);
            counter.reset();
        }

        // All users should be able to perform non-owner functions
        vm.prank(user1);
        counter.increment();

        vm.prank(user2);
        counter.increment();

        if (!transferOwnership) {
            assertEq(counter.count(), originalCount + 2);
        }
    }

    // ============ EDGE CASE FUZZ TESTS ============

    /**
     * @dev Test edge cases with extreme values
     */
    function testFuzz_EdgeCases(bool useMaxValue, bool useMinValue) public {
        if (useMaxValue) {
            // Test with maximum possible count
            counter.setCount(MAX_COUNT);
            assertEq(counter.count(), MAX_COUNT);

            // Increment should revert (due to our bound in incrementBy)
            vm.expectRevert(); // Any revert is fine for extreme values
            counter.incrementBy(1);
        }

        if (useMinValue) {
            // Test with minimum count (0)
            counter.setCount(0);
            assertEq(counter.count(), 0);

            // Decrement should revert
            vm.expectRevert(Counter.CannotDecrementBelowZero.selector);
            counter.decrement();
        }
    }

    /**
     * @dev Test boundary conditions
     */
    function testFuzz_BoundaryConditions(
        uint256 currentCount,
        uint256 delta
    ) public {
        currentCount = bound(currentCount, 0, 1000000);
        delta = bound(delta, 1, 1000);

        counter.setCount(currentCount);

        // Test increment at boundary
        if (currentCount <= MAX_COUNT - delta) {
            counter.incrementBy(delta);
            assertEq(counter.count(), currentCount + delta);

            // Test decrement back
            counter.decrementBy(delta);
            assertEq(counter.count(), currentCount);
        }

        // Test decrement at boundary
        if (delta <= currentCount) {
            counter.decrementBy(delta);
            assertEq(counter.count(), currentCount - delta);

            // Test increment back
            counter.incrementBy(delta);
            assertEq(counter.count(), currentCount);
        }
    }

    // ============ HELPER FUNCTIONS ============

    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}

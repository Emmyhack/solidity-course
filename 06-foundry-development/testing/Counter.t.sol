// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../examples/Counter.sol";

/**
 * @title CounterTest
 * @dev Comprehensive test suite for Counter contract using Foundry
 * @notice Demonstrates various testing techniques including unit tests, fuzzing, and invariants
 */
contract CounterTest is Test {
    Counter public counter;

    // Test addresses
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // Events to test (must match contract events)
    event CountIncremented(
        uint256 indexed newCount,
        address indexed incrementer
    );
    event CountDecremented(
        uint256 indexed newCount,
        address indexed decrementer
    );
    event CountReset(address indexed resetter);
    event PauseToggled(bool indexed newPauseState, address indexed toggler);
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Setup function runs before each test
     */
    function setUp() public {
        // Deploy counter with initial count of 10
        counter = new Counter(10);
    }

    // ============ BASIC UNIT TESTS ============

    /**
     * @dev Test initial state
     */
    function test_InitialState() public {
        assertEq(counter.count(), 10);
        assertEq(counter.owner(), address(this));
        assertEq(counter.paused(), false);
    }

    /**
     * @dev Test basic increment functionality
     */
    function test_Increment() public {
        // Test increment
        counter.increment();
        assertEq(counter.count(), 11);

        // Test multiple increments
        counter.increment();
        counter.increment();
        assertEq(counter.count(), 13);
    }

    /**
     * @dev Test increment with event emission
     */
    function test_IncrementEmitsEvent() public {
        // Expect event emission
        vm.expectEmit(true, true, false, true);
        emit CountIncremented(11, address(this));

        counter.increment();
    }

    /**
     * @dev Test basic decrement functionality
     */
    function test_Decrement() public {
        // Test decrement
        counter.decrement();
        assertEq(counter.count(), 9);

        // Test multiple decrements
        counter.decrement();
        counter.decrement();
        assertEq(counter.count(), 7);
    }

    /**
     * @dev Test decrement with event emission
     */
    function test_DecrementEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit CountDecremented(9, address(this));

        counter.decrement();
    }

    /**
     * @dev Test increment by specific amount
     */
    function test_IncrementBy() public {
        counter.incrementBy(5);
        assertEq(counter.count(), 15);

        counter.incrementBy(100);
        assertEq(counter.count(), 115);
    }

    /**
     * @dev Test decrement by specific amount
     */
    function test_DecrementBy() public {
        counter.decrementBy(3);
        assertEq(counter.count(), 7);

        counter.decrementBy(7);
        assertEq(counter.count(), 0);
    }

    // ============ ERROR TESTING ============

    /**
     * @dev Test decrement below zero reverts
     */
    function test_RevertWhen_DecrementBelowZero() public {
        // Decrement to 0
        counter.decrementBy(10);
        assertEq(counter.count(), 0);

        // Expect revert on further decrement
        vm.expectRevert(Counter.CannotDecrementBelowZero.selector);
        counter.decrement();
    }

    /**
     * @dev Test decrement by amount larger than current count
     */
    function test_RevertWhen_DecrementByTooMuch() public {
        vm.expectRevert(Counter.CannotDecrementBelowZero.selector);
        counter.decrementBy(15); // Current count is 10
    }

    /**
     * @dev Test only owner functions revert for non-owners
     */
    function test_RevertWhen_NotOwner() public {
        vm.startPrank(alice);

        vm.expectRevert(Counter.OnlyOwner.selector);
        counter.reset();

        vm.expectRevert(Counter.OnlyOwner.selector);
        counter.setCount(100);

        vm.expectRevert(Counter.OnlyOwner.selector);
        counter.togglePause();

        vm.expectRevert(Counter.OnlyOwner.selector);
        counter.transferOwnership(bob);

        vm.stopPrank();
    }

    /**
     * @dev Test paused contract functionality
     */
    function test_RevertWhen_Paused() public {
        // Pause the contract
        counter.togglePause();
        assertTrue(counter.paused());

        // All user functions should revert
        vm.expectRevert(Counter.ContractPaused.selector);
        counter.increment();

        vm.expectRevert(Counter.ContractPaused.selector);
        counter.decrement();

        vm.expectRevert(Counter.ContractPaused.selector);
        counter.incrementBy(5);

        vm.expectRevert(Counter.ContractPaused.selector);
        counter.decrementBy(3);
    }

    // ============ OWNER FUNCTIONALITY TESTS ============

    /**
     * @dev Test reset functionality
     */
    function test_Reset() public {
        // Increment first
        counter.increment();
        assertEq(counter.count(), 11);

        // Reset
        vm.expectEmit(true, false, false, true);
        emit CountReset(address(this));

        counter.reset();
        assertEq(counter.count(), 0);
    }

    /**
     * @dev Test set count functionality
     */
    function test_SetCount() public {
        counter.setCount(999);
        assertEq(counter.count(), 999);

        counter.setCount(0);
        assertEq(counter.count(), 0);
    }

    /**
     * @dev Test pause toggle functionality
     */
    function test_TogglePause() public {
        assertFalse(counter.paused());

        // Pause
        vm.expectEmit(true, true, false, true);
        emit PauseToggled(true, address(this));
        counter.togglePause();
        assertTrue(counter.paused());

        // Unpause
        vm.expectEmit(true, true, false, true);
        emit PauseToggled(false, address(this));
        counter.togglePause();
        assertFalse(counter.paused());
    }

    /**
     * @dev Test ownership transfer
     */
    function test_TransferOwnership() public {
        assertEq(counter.owner(), address(this));

        // Transfer to alice
        vm.expectEmit(true, true, false, true);
        emit OwnershipTransferred(address(this), alice);
        counter.transferOwnership(alice);

        assertEq(counter.owner(), alice);
    }

    /**
     * @dev Test transfer ownership to zero address reverts
     */
    function test_RevertWhen_TransferToZeroAddress() public {
        vm.expectRevert(Counter.ZeroAddress.selector);
        counter.transferOwnership(address(0));
    }

    // ============ VIEW FUNCTION TESTS ============

    /**
     * @dev Test getInfo function
     */
    function test_GetInfo() public {
        (uint256 currentCount, address contractOwner, bool isPaused) = counter
            .getInfo();

        assertEq(currentCount, 10);
        assertEq(contractOwner, address(this));
        assertEq(isPaused, false);

        // Change state and test again
        counter.increment();
        counter.togglePause();
        counter.transferOwnership(alice);

        (currentCount, contractOwner, isPaused) = counter.getInfo();
        assertEq(currentCount, 11);
        assertEq(contractOwner, alice);
        assertEq(isPaused, true);
    }

    // ============ FUZZ TESTS ============

    /**
     * @dev Fuzz test increment by amount
     */
    function testFuzz_IncrementBy(uint256 amount) public {
        // Bound the amount to prevent overflow
        amount = bound(amount, 0, type(uint256).max - counter.count());

        uint256 initialCount = counter.count();
        counter.incrementBy(amount);

        assertEq(counter.count(), initialCount + amount);
    }

    /**
     * @dev Fuzz test decrement by amount
     */
    function testFuzz_DecrementBy(uint256 amount) public {
        uint256 initialCount = counter.count();

        if (amount > initialCount) {
            vm.expectRevert(Counter.CannotDecrementBelowZero.selector);
            counter.decrementBy(amount);
        } else {
            counter.decrementBy(amount);
            assertEq(counter.count(), initialCount - amount);
        }
    }

    /**
     * @dev Fuzz test set count
     */
    function testFuzz_SetCount(uint256 newCount) public {
        counter.setCount(newCount);
        assertEq(counter.count(), newCount);
    }

    /**
     * @dev Fuzz test ownership transfer
     */
    function testFuzz_TransferOwnership(address newOwner) public {
        // Skip zero address (we test this separately)
        vm.assume(newOwner != address(0));

        counter.transferOwnership(newOwner);
        assertEq(counter.owner(), newOwner);
    }

    // ============ STATEFUL FUZZ TESTS ============

    /**
     * @dev Invariant: Count should never overflow
     */
    function invariant_CountNeverOverflows() public {
        // This is more of a demonstration - Solidity 0.8+ prevents overflows by default
        assertTrue(counter.count() >= 0);
    }

    /**
     * @dev Invariant: Contract should have consistent state
     */
    function invariant_ConsistentState() public {
        (uint256 currentCount, address contractOwner, bool isPaused) = counter
            .getInfo();

        // Verify getInfo matches individual getters
        assertEq(currentCount, counter.count());
        assertEq(contractOwner, counter.owner());
        assertEq(isPaused, counter.paused());

        // Owner should never be zero address (unless intentionally set, which our contract prevents)
        assertTrue(contractOwner != address(0));
    }

    // ============ INTEGRATION TESTS ============

    /**
     * @dev Test complete workflow
     */
    function test_CompleteWorkflow() public {
        // Initial state
        assertEq(counter.count(), 10);
        assertEq(counter.owner(), address(this));
        assertFalse(counter.paused());

        // Increment operations
        counter.increment();
        counter.incrementBy(5);
        assertEq(counter.count(), 16);

        // Decrement operations
        counter.decrement();
        counter.decrementBy(3);
        assertEq(counter.count(), 12);

        // Owner operations
        counter.setCount(100);
        assertEq(counter.count(), 100);

        // Transfer ownership
        counter.transferOwnership(alice);
        assertEq(counter.owner(), alice);

        // New owner operations
        vm.startPrank(alice);
        counter.reset();
        assertEq(counter.count(), 0);

        counter.togglePause();
        assertTrue(counter.paused());
        vm.stopPrank();

        // Paused operations should fail
        vm.expectRevert(Counter.ContractPaused.selector);
        counter.increment();
    }

    // ============ GAS OPTIMIZATION TESTS ============

    /**
     * @dev Test gas consumption for increment
     */
    function test_GasUsage_Increment() public {
        uint256 gasBefore = gasleft();
        counter.increment();
        uint256 gasUsed = gasBefore - gasleft();

        // Assert reasonable gas usage (adjust based on actual measurements)
        assertLt(gasUsed, 50000); // Should be much less than 50k gas
    }

    /**
     * @dev Compare gas usage between increment and incrementBy(1)
     */
    function test_GasComparison_IncrementVsIncrementBy() public {
        Counter counter1 = new Counter(0);
        Counter counter2 = new Counter(0);

        uint256 gasBefore1 = gasleft();
        counter1.increment();
        uint256 gasUsed1 = gasBefore1 - gasleft();

        uint256 gasBefore2 = gasleft();
        counter2.incrementBy(1);
        uint256 gasUsed2 = gasBefore2 - gasleft();

        // incrementBy should use slightly more gas due to the parameter
        assertGe(gasUsed2, gasUsed1);

        // But difference should be minimal
        assertLt(gasUsed2 - gasUsed1, 1000);
    }

    // ============ HELPER FUNCTIONS ============

    /**
     * @dev Helper to setup counter in specific state
     */
    function _setupCounterState(
        uint256 _count,
        address _owner,
        bool _paused
    ) internal {
        if (_count != counter.count()) {
            counter.setCount(_count);
        }

        if (_owner != counter.owner()) {
            counter.transferOwnership(_owner);
        }

        if (_paused != counter.paused()) {
            if (_owner != address(this)) {
                vm.prank(_owner);
                counter.togglePause();
            } else {
                counter.togglePause();
            }
        }
    }
}

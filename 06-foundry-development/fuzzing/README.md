# Foundry Fuzzing & Property Testing Guide

Master the art of property-based testing and fuzzing with Foundry's advanced testing capabilities.

##  Table of Contents

1. [Introduction to Fuzzing](#introduction-to-fuzzing)
2. [Basic Fuzzing](#basic-fuzzing)
3. [Property-Based Testing](#property-based-testing)
4. [Invariant Testing](#invariant-testing)
5. [Advanced Fuzzing Techniques](#advanced-fuzzing-techniques)
6. [Fuzzing Configuration](#fuzzing-configuration)
7. [Common Patterns](#common-patterns)
8. [Best Practices](#best-practices)

##  Introduction to Fuzzing

### What is Fuzzing?

Fuzzing is a testing technique that automatically generates random inputs to test your contracts. Instead of writing specific test cases, you define properties that should always hold true, and the fuzzer tries to find inputs that break these properties.

### Why Fuzz Test Smart Contracts?

- **Discover Edge Cases**: Find unexpected inputs that break your contract
- **Property Verification**: Ensure mathematical properties always hold
- **Comprehensive Coverage**: Test millions of input combinations automatically
- **Security Auditing**: Identify potential vulnerabilities
- **Regression Testing**: Catch bugs introduced by changes

### Types of Fuzzing in Foundry

```solidity
// 1. Stateless Fuzzing - Each test runs independently
function testFuzz_Transfer(uint256 amount) public { }

// 2. Stateful Fuzzing - Tests build on each other's state
function invariant_TotalSupplyConstant() public { }

// 3. Property-Based Testing - Test mathematical properties
function testProperty_Commutative(uint256 a, uint256 b) public { }
```

##  Basic Fuzzing

### Your First Fuzz Test

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

contract BasicFuzzTest is Test {

    function testFuzz_Addition(uint256 a, uint256 b) public {
        // Foundry will automatically generate random values for a and b
        vm.assume(a <= type(uint256).max - b); // Prevent overflow

        uint256 result = a + b;

        // Properties that should always hold
        assertGe(result, a); // Result should be >= a
        assertGe(result, b); // Result should be >= b
    }

    function testFuzz_StringLength(string memory input) public {
        bytes memory inputBytes = bytes(input);

        // Property: string length should equal bytes length
        assertEq(inputBytes.length, bytes(input).length);

        // Property: empty string should have zero length
        if (inputBytes.length == 0) {
            assertEq(keccak256(inputBytes), keccak256(""));
        }
    }
}
```

### Input Constraints with vm.assume()

```solidity
function testFuzz_WithConstraints(uint256 amount, address user) public {
    // Constrain inputs to valid ranges
    vm.assume(amount > 0);
    vm.assume(amount <= 1000000e18);
    vm.assume(user != address(0));
    vm.assume(user != address(this));

    // Your test logic here
    token.mint(user, amount);
    assertEq(token.balanceOf(user), amount);
}
```

### Input Bounding with bound()

```solidity
function testFuzz_WithBounding(uint256 amount, address user) public {
    // Bound inputs to specific ranges
    amount = bound(amount, 1, 1000000e18);
    user = address(uint160(bound(uint160(user), 1, type(uint160).max)));

    // Your test logic here
    token.mint(user, amount);
    assertEq(token.balanceOf(user), amount);
}
```

##  Property-Based Testing

### Mathematical Properties

```solidity
contract MathPropertiesTest is Test {

    // Commutative property: a + b = b + a
    function testProperty_AdditionCommutative(uint256 a, uint256 b) public {
        vm.assume(a <= type(uint256).max - b);
        assertEq(a + b, b + a);
    }

    // Associative property: (a + b) + c = a + (b + c)
    function testProperty_AdditionAssociative(uint256 a, uint256 b, uint256 c) public {
        vm.assume(a <= type(uint256).max - b);
        vm.assume(b <= type(uint256).max - c);
        vm.assume(a + b <= type(uint256).max - c);

        assertEq((a + b) + c, a + (b + c));
    }

    // Identity property: a + 0 = a
    function testProperty_AdditionIdentity(uint256 a) public {
        assertEq(a + 0, a);
    }

    // Inverse property for subtraction: a - b + b = a
    function testProperty_SubtractionInverse(uint256 a, uint256 b) public {
        vm.assume(a >= b);
        assertEq(a - b + b, a);
    }
}
```

### Token Contract Properties

```solidity
contract TokenPropertiesTest is Test {
    ERC20 public token;

    function setUp() public {
        token = new ERC20("Test", "TEST");
    }

    // Conservation property: transfers don't change total supply
    function testProperty_TransferConservesTotalSupply(
        address from,
        address to,
        uint256 amount
    ) public {
        vm.assume(from != to);
        vm.assume(from != address(0) && to != address(0));

        // Setup: give 'from' enough tokens
        deal(address(token), from, amount);

        uint256 totalSupplyBefore = token.totalSupply();

        vm.prank(from);
        token.transfer(to, amount);

        uint256 totalSupplyAfter = token.totalSupply();
        assertEq(totalSupplyBefore, totalSupplyAfter);
    }

    // Symmetry property: approve + transferFrom = direct transfer
    function testProperty_ApprovalTransferSymmetry(
        address owner,
        address spender,
        address recipient,
        uint256 amount
    ) public {
        vm.assume(owner != spender && owner != recipient && spender != recipient);
        vm.assume(owner != address(0) && spender != address(0) && recipient != address(0));

        // Setup two identical scenarios
        deal(address(token), owner, amount * 2);

        uint256 balanceBefore = token.balanceOf(recipient);

        // Method 1: Direct transfer
        vm.prank(owner);
        token.transfer(recipient, amount);
        uint256 balanceAfterDirect = token.balanceOf(recipient);

        // Method 2: Approve + transferFrom
        vm.prank(owner);
        token.approve(spender, amount);

        vm.prank(spender);
        token.transferFrom(owner, recipient, amount);
        uint256 balanceAfterApproval = token.balanceOf(recipient);

        // Both methods should result in same balance
        assertEq(balanceAfterDirect - balanceBefore, balanceAfterApproval - balanceAfterDirect);
    }

    // Monotonicity property: balance changes are monotonic
    function testProperty_BalanceMonotonicity(
        address user,
        uint256 mintAmount,
        uint256 burnAmount
    ) public {
        vm.assume(user != address(0));
        mintAmount = bound(mintAmount, 1, 1000000e18);
        burnAmount = bound(burnAmount, 0, mintAmount);

        uint256 initialBalance = token.balanceOf(user);

        // Mint should increase balance
        deal(address(token), user, initialBalance + mintAmount);
        uint256 balanceAfterMint = token.balanceOf(user);
        assertGt(balanceAfterMint, initialBalance);

        // Burn should decrease balance
        vm.prank(user);
        token.transfer(address(0xdead), burnAmount);
        uint256 balanceAfterBurn = token.balanceOf(user);
        assertLt(balanceAfterBurn, balanceAfterMint);
    }
}
```

##  Invariant Testing

### Setting Up Invariant Tests

```solidity
// Handler contract for invariant testing
contract TokenHandler {
    ERC20 public token;
    address[] public actors;
    mapping(address => bool) public isActor;

    uint256 public ghost_mintSum;
    uint256 public ghost_burnSum;

    modifier useActor(uint256 actorIndexSeed) {
        address actor = actors[bound(actorIndexSeed, 0, actors.length - 1)];
        vm.startPrank(actor);
        _;
        vm.stopPrank();
    }

    constructor(ERC20 _token) {
        token = _token;
    }

    function mint(uint256 actorSeed, uint256 amount) public {
        amount = bound(amount, 1, 1000e18);
        address actor = _getOrCreateActor(actorSeed);

        uint256 balanceBefore = token.balanceOf(actor);
        token.mint(actor, amount);
        uint256 balanceAfter = token.balanceOf(actor);

        // Update ghost variables
        ghost_mintSum += (balanceAfter - balanceBefore);
    }

    function burn(uint256 actorSeed, uint256 amount) public {
        address actor = _getOrCreateActor(actorSeed);
        uint256 balance = token.balanceOf(actor);

        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        uint256 balanceBefore = token.balanceOf(actor);
        vm.prank(actor);
        token.burn(amount);
        uint256 balanceAfter = token.balanceOf(actor);

        // Update ghost variables
        ghost_burnSum += (balanceBefore - balanceAfter);
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
        address from = _getOrCreateActor(fromSeed);
        address to = _getOrCreateActor(toSeed);

        if (from == to) return;

        uint256 balance = token.balanceOf(from);
        if (balance == 0) return;

        amount = bound(amount, 1, balance);

        vm.prank(from);
        token.transfer(to, amount);
    }

    function _getOrCreateActor(uint256 seed) internal returns (address) {
        if (actors.length == 0) {
            address newActor = address(uint160(bound(seed, 1, type(uint160).max)));
            actors.push(newActor);
            isActor[newActor] = true;
            return newActor;
        }

        uint256 index = bound(seed, 0, actors.length - 1);
        return actors[index];
    }

    function getAllActors() external view returns (address[] memory) {
        return actors;
    }
}

// Invariant test contract
contract TokenInvariantTest is Test {
    ERC20 public token;
    TokenHandler public handler;

    function setUp() public {
        token = new ERC20("Test", "TEST");
        handler = new TokenHandler(token);

        // Configure invariant testing
        targetContract(address(handler));

        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = TokenHandler.mint.selector;
        selectors[1] = TokenHandler.burn.selector;
        selectors[2] = TokenHandler.transfer.selector;

        targetSelector(FuzzSelector({
            addr: address(handler),
            selectors: selectors
        }));
    }

    // Invariant: Total supply equals sum of all balances
    function invariant_TotalSupplyEqualsBalances() public {
        address[] memory actors = handler.getAllActors();
        uint256 sumOfBalances = 0;

        for (uint256 i = 0; i < actors.length; i++) {
            sumOfBalances += token.balanceOf(actors[i]);
        }

        assertEq(token.totalSupply(), sumOfBalances);
    }

    // Invariant: Total supply equals mints minus burns
    function invariant_TotalSupplyEqualsGhostVars() public {
        uint256 expectedTotalSupply = handler.ghost_mintSum() - handler.ghost_burnSum();
        assertEq(token.totalSupply(), expectedTotalSupply);
    }

    // Invariant: No account has negative balance
    function invariant_NoNegativeBalances() public {
        address[] memory actors = handler.getAllActors();

        for (uint256 i = 0; i < actors.length; i++) {
            assertGe(token.balanceOf(actors[i]), 0);
        }
    }

    // Invariant: Total supply never exceeds maximum
    function invariant_TotalSupplyWithinBounds() public {
        assertLe(token.totalSupply(), type(uint256).max);
        assertGe(token.totalSupply(), 0);
    }
}
```

### Advanced Invariant Patterns

```solidity
contract AdvancedInvariantTest is Test {
    DeFiProtocol public protocol;
    ProtocolHandler public handler;

    function setUp() public {
        protocol = new DeFiProtocol();
        handler = new ProtocolHandler(protocol);

        targetContract(address(handler));
    }

    // Time-based invariant
    function invariant_InterestAccruesOverTime() public {
        if (handler.totalDeposited() > 0) {
            uint256 expectedInterest = handler.calculateExpectedInterest();
            uint256 actualInterest = protocol.totalAccruedInterest();

            // Allow for small rounding errors
            assertApproxEqRel(actualInterest, expectedInterest, 0.01e18); // 1% tolerance
        }
    }

    // Economic invariant
    function invariant_ProtocolSolvency() public {
        uint256 totalAssets = protocol.totalAssets();
        uint256 totalLiabilities = protocol.totalLiabilities();

        // Protocol should always be solvent
        assertGe(totalAssets, totalLiabilities);
    }

    // Complex state invariant
    function invariant_StateConsistency() public {
        address[] memory users = handler.getAllUsers();

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];

            // Individual user state should be consistent
            uint256 deposited = protocol.userDeposits(user);
            uint256 borrowed = protocol.userBorrows(user);
            uint256 collateral = protocol.userCollateral(user);

            if (borrowed > 0) {
                // Borrowed amount should not exceed collateral capacity
                uint256 maxBorrow = (collateral * protocol.collateralFactor()) / 1e18;
                assertLe(borrowed, maxBorrow);
            }
        }
    }
}
```

##  Advanced Fuzzing Techniques

### Structured Fuzzing

```solidity
struct FuzzInput {
    address user;
    uint256 amount;
    uint8 action; // 0 = deposit, 1 = withdraw, 2 = borrow, 3 = repay
    uint32 timeJump;
}

function testFuzz_StructuredInput(FuzzInput memory input) public {
    // Normalize input
    input.user = address(uint160(bound(uint160(input.user), 1, type(uint160).max)));
    input.amount = bound(input.amount, 1, 1000000e18);
    input.action = uint8(bound(input.action, 0, 3));
    input.timeJump = uint32(bound(input.timeJump, 0, 365 days));

    // Time travel
    vm.warp(block.timestamp + input.timeJump);

    // Execute action
    if (input.action == 0) {
        _deposit(input.user, input.amount);
    } else if (input.action == 1) {
        _withdraw(input.user, input.amount);
    } else if (input.action == 2) {
        _borrow(input.user, input.amount);
    } else {
        _repay(input.user, input.amount);
    }

    // Verify invariants after each action
    _checkInvariants();
}
```

### Differential Fuzzing

```solidity
contract DifferentialFuzzTest is Test {
    Calculator public calc1; // Original implementation
    Calculator public calc2; // Optimized implementation

    function setUp() public {
        calc1 = new Calculator();
        calc2 = new OptimizedCalculator();
    }

    function testFuzz_DifferentialCalculation(uint256 a, uint256 b) public {
        vm.assume(a <= type(uint128).max);
        vm.assume(b <= type(uint128).max);

        uint256 result1 = calc1.multiply(a, b);
        uint256 result2 = calc2.multiply(a, b);

        // Both implementations should give same result
        assertEq(result1, result2);
    }
}
```

### Metamorphic Testing

```solidity
function testFuzz_MetamorphicSorting(uint256[] memory array) public {
    vm.assume(array.length <= 100); // Reasonable size

    // Property: Sorting twice should give same result as sorting once
    uint256[] memory onceSorted = sorter.sort(array);
    uint256[] memory twiceSorted = sorter.sort(onceSorted);

    assertEq(onceSorted.length, twiceSorted.length);
    for (uint256 i = 0; i < onceSorted.length; i++) {
        assertEq(onceSorted[i], twiceSorted[i]);
    }
}
```

##  Fuzzing Configuration

### foundry.toml Configuration

```toml
[profile.default]
# Fuzz testing configuration
fuzz = { runs = 256 }

[profile.ci]
# More runs for CI
fuzz = { runs = 10000 }

[profile.deep]
# Extensive fuzzing
fuzz = { runs = 100000 }

# Invariant testing configuration
[invariant]
runs = 256
depth = 15
fail_on_revert = false
call_override = false
dictionary_weight = 40
include_storage = true
include_push_bytes = true

[fuzz]
# Seed for reproducible fuzzing
seed = "0x1"

# Maximum test case shrinking attempts
max_test_rejects = 65536

# Gas limit for fuzz tests
gas_limit = 9223372036854775807
```

### Programmatic Configuration

```solidity
function testFuzz_WithCustomConfig(uint256 input) public {
    // Configure fuzzing for this specific test
    vm.assume(input != 0);

    // Your test logic
}

// Use custom dictionary for better fuzzing
function targetArtifactSelectors() public returns (FuzzSelector[] memory) {
    FuzzSelector[] memory selectors = new FuzzSelector[](1);

    bytes4[] memory functionSelectors = new bytes4[](2);
    functionSelectors[0] = MyContract.criticalFunction.selector;
    functionSelectors[1] = MyContract.anotherFunction.selector;

    selectors[0] = FuzzSelector({
        addr: address(myContract),
        selectors: functionSelectors
    });

    return selectors;
}
```

##  Common Patterns

### The Fuzzing Lifecycle

```solidity
contract FuzzLifecycleTest is Test {
    MyContract public myContract;

    // State tracking for stateful fuzzing
    mapping(address => uint256) public expectedBalances;
    address[] public allUsers;

    function setUp() public {
        myContract = new MyContract();
    }

    function testFuzz_StatefulOperations(
        uint256 userSeed,
        uint256 amount,
        uint8 operation
    ) public {
        // 1. Normalize inputs
        address user = _getOrCreateUser(userSeed);
        amount = bound(amount, 1, 1000e18);
        operation = uint8(bound(operation, 0, 2));

        // 2. Record state before
        uint256 balanceBefore = myContract.balanceOf(user);
        uint256 totalSupplyBefore = myContract.totalSupply();

        // 3. Execute operation
        if (operation == 0) {
            myContract.deposit(user, amount);
            expectedBalances[user] += amount;
        } else if (operation == 1 && balanceBefore >= amount) {
            myContract.withdraw(user, amount);
            expectedBalances[user] -= amount;
        } else {
            return; // Skip invalid operations
        }

        // 4. Verify state after
        assertEq(myContract.balanceOf(user), expectedBalances[user]);

        // 5. Check global invariants
        _checkGlobalInvariants();
    }

    function _getOrCreateUser(uint256 seed) internal returns (address) {
        if (allUsers.length < 10) {
            address newUser = makeAddr(string(abi.encodePacked("user", allUsers.length)));
            allUsers.push(newUser);
            return newUser;
        }

        uint256 index = bound(seed, 0, allUsers.length - 1);
        return allUsers[index];
    }

    function _checkGlobalInvariants() internal {
        uint256 sumOfBalances = 0;
        for (uint256 i = 0; i < allUsers.length; i++) {
            sumOfBalances += myContract.balanceOf(allUsers[i]);
        }
        assertEq(sumOfBalances, myContract.totalSupply());
    }
}
```

### Error Boundary Testing

```solidity
function testFuzz_ErrorBoundaries(uint256 amount, address user) public {
    amount = bound(amount, 0, type(uint256).max);
    user = address(uint160(bound(uint160(user), 0, type(uint160).max)));

    if (amount == 0) {
        vm.expectRevert(ZeroAmount.selector);
        myContract.deposit(user, amount);
    } else if (user == address(0)) {
        vm.expectRevert(ZeroAddress.selector);
        myContract.deposit(user, amount);
    } else if (amount > myContract.maxDeposit()) {
        vm.expectRevert(ExceedsMaxDeposit.selector);
        myContract.deposit(user, amount);
    } else {
        // Should succeed
        myContract.deposit(user, amount);
        assertEq(myContract.balanceOf(user), amount);
    }
}
```

##  Best Practices

### 1. Input Validation Strategy

```solidity
//  Good: Comprehensive input validation
function testFuzz_GoodInputValidation(
    address user,
    uint256 amount,
    uint256 deadline
) public {
    // Use bound for numeric values
    amount = bound(amount, 1, 1000000e18);
    deadline = bound(deadline, block.timestamp, block.timestamp + 365 days);

    // Use assume for complex conditions
    vm.assume(user != address(0));
    vm.assume(user != address(this));
    vm.assume(amount <= myContract.maxAllowedAmount());

    // Your test logic
}

//  Bad: Insufficient input validation
function testFuzz_BadInputValidation(address user, uint256 amount) public {
    myContract.deposit(user, amount); // May fail with invalid inputs
}
```

### 2. Property Selection

```solidity
//  Good: Test fundamental properties
function testProperty_FundamentalProperty(uint256 input) public {
    // Test properties that must always hold
    // - Conservation laws
    // - Mathematical identities
    // - Business logic constraints
}

//  Bad: Test implementation details
function testProperty_ImplementationDetail(uint256 input) public {
    // Don't test how something is done, test what it should do
}
```

### 3. Shrinking-Friendly Tests

```solidity
//  Good: Will shrink to minimal failing case
function testFuzz_ShrinkingFriendly(uint256 amount) public {
    amount = bound(amount, 1, 1000);

    // Simple, direct assertion
    assertTrue(myContract.isValidAmount(amount));
}

//  Bad: Complex conditions make shrinking difficult
function testFuzz_ComplexShrinking(uint256 a, uint256 b, uint256 c, bool flag) public {
    // Too many interdependent conditions
    if (flag && a > b && b > c && c > 0) {
        // Test logic
    }
}
```

### 4. Performance Optimization

```solidity
//  Good: Efficient fuzzing
function testFuzz_Efficient(uint256 input) public {
    input = bound(input, 1, 1000); // Bound early

    // Cache expensive operations
    uint256 cachedValue = myContract.expensiveCalculation();

    // Use efficient assertions
    assertEq(result, expected);
}

//  Bad: Inefficient fuzzing
function testFuzz_Inefficient(uint256 input) public {
    vm.assume(input > 0 && input < 1000); // assume is slower than bound

    // Repeated expensive operations
    for (uint256 i = 0; i < 100; i++) {
        myContract.expensiveCalculation();
    }
}
```

### 5. Debugging Fuzz Failures

```solidity
function testFuzz_DebuggingExample(uint256 amount, address user) public {
    // Add detailed error messages
    require(amount > 0, "Amount must be positive");
    require(user != address(0), "User cannot be zero address");

    // Log important values for debugging
    emit log_named_uint("amount", amount);
    emit log_named_address("user", user);

    // Your test logic
    myContract.deposit(user, amount);

    // Detailed assertion messages
    assertEq(
        myContract.balanceOf(user),
        amount,
        "Balance mismatch after deposit"
    );
}
```

### 6. Fuzz Test Organization

```solidity
contract MyContractFuzzTest is Test {
    // ============ SETUP ============
    function setUp() public { }

    // ============ BASIC FUZZING ============
    function testFuzz_BasicOperations() public { }

    // ============ PROPERTY TESTING ============
    function testProperty_MathematicalProperties() public { }

    // ============ EDGE CASES ============
    function testFuzz_EdgeCases() public { }

    // ============ INVARIANT HELPERS ============
    function _checkInvariants() internal { }
}
```

---

**Fuzzing mastered!**  Your contracts are now battle-tested against millions of possible inputs.

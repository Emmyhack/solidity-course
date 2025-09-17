# Foundry Testing Guide

Comprehensive guide to testing Solidity contracts with Foundry's powerful testing framework.

##  Table of Contents

1. [Testing Philosophy](#testing-philosophy)
2. [Test Structure](#test-structure)
3. [Basic Unit Tests](#basic-unit-tests)
4. [Advanced Testing Techniques](#advanced-testing-techniques)
5. [Fuzzing & Property Testing](#fuzzing--property-testing)
6. [Invariant Testing](#invariant-testing)
7. [Mocking & Forking](#mocking--forking)
8. [Gas Testing](#gas-testing)
9. [Integration Testing](#integration-testing)
10. [Best Practices](#best-practices)

##  Testing Philosophy

### Why Test Smart Contracts?

Smart contracts are immutable once deployed and handle valuable assets. Comprehensive testing is critical for:

- **Security**: Prevent exploits and vulnerabilities
- **Correctness**: Ensure business logic works as intended
- **Regression Prevention**: Catch bugs introduced by changes
- **Documentation**: Tests serve as executable specifications
- **Confidence**: Deploy with certainty your contract works

### Testing Pyramid for Smart Contracts

```
    /\
   /  \ Integration Tests (Few)
  /____\
 /      \ Unit Tests (Many)
/__________\
Fuzzing & Property Tests (Continuous)
```

##  Test Structure

### Test File Organization

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/YourContract.sol";

contract YourContractTest is Test {
    // Contract instance
    YourContract public yourContract;

    // Test accounts
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    // Test constants
    uint256 public constant INITIAL_BALANCE = 1000e18;

    // Events (must match contract)
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        // Deploy contract and setup state
        yourContract = new YourContract();
    }

    // Test functions...
}
```

### Naming Conventions

```solidity
//  Good test naming
function test_TransferTokens() public { }
function test_RevertWhen_InsufficientBalance() public { }
function testFuzz_DepositAmount(uint256 amount) public { }
function invariant_TotalSupplyEqualsIndividualBalances() public { }

//  Poor test naming
function test1() public { }
function testTransfer() public { }
function check() public { }
```

##  Basic Unit Tests

### Setup and Teardown

```solidity
contract TokenTest is Test {
    Token public token;
    address public owner = address(this);
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        // Runs before each test
        token = new Token("TestToken", "TEST", 1000000e18);

        // Setup initial state
        token.transfer(alice, 10000e18);
        token.transfer(bob, 5000e18);
    }

    function tearDown() public {
        // Optional: cleanup after tests
        // Usually not needed in Foundry
    }
}
```

### Assertion Functions

```solidity
function test_Assertions() public {
    // Equality assertions
    assertEq(token.totalSupply(), 1000000e18);
    assertEq(token.balanceOf(alice), 10000e18);

    // Boolean assertions
    assertTrue(token.balanceOf(alice) > 0);
    assertFalse(token.paused());

    // Inequality assertions
    assertGt(token.balanceOf(alice), token.balanceOf(bob)); // greater than
    assertGe(token.balanceOf(alice), 10000e18); // greater or equal
    assertLt(token.balanceOf(bob), token.balanceOf(alice)); // less than
    assertLe(token.balanceOf(bob), 5000e18); // less or equal

    // Approximate equality (for floating point-like calculations)
    assertApproxEqAbs(calculated, expected, 1e15); // within absolute tolerance
    assertApproxEqRel(calculated, expected, 0.01e18); // within relative tolerance (1%)
}
```

### Testing Events

```solidity
function test_EventEmission() public {
    // Method 1: Basic event expectation
    vm.expectEmit(true, true, false, true);
    emit Transfer(owner, alice, 1000e18);
    token.transfer(alice, 1000e18);

    // Method 2: Capture and verify events
    vm.recordLogs();
    token.transfer(alice, 1000e18);

    Vm.Log[] memory logs = vm.getRecordedLogs();
    assertEq(logs.length, 1);
    assertEq(logs[0].topics[0], keccak256("Transfer(address,address,uint256)"));
}
```

### Testing Reverts

```solidity
function test_RevertConditions() public {
    // Method 1: Expect specific error
    vm.expectRevert(Token.InsufficientBalance.selector);
    vm.prank(alice);
    token.transfer(bob, 20000e18); // Alice only has 10000

    // Method 2: Expect error with message
    vm.expectRevert("ERC20: transfer amount exceeds balance");
    vm.prank(alice);
    token.transfer(bob, 20000e18);

    // Method 3: Expect any revert
    vm.expectRevert();
    vm.prank(alice);
    token.transfer(bob, 20000e18);

    // Method 4: Test multiple revert conditions
    bytes4[] memory selectors = new bytes4[](2);
    selectors[0] = Token.InsufficientBalance.selector;
    selectors[1] = Token.TransferToZeroAddress.selector;

    vm.expectRevert(selectors[0]);
    vm.prank(alice);
    token.transfer(bob, 20000e18);
}
```

##  Advanced Testing Techniques

### Pranking (Impersonation)

```solidity
function test_Pranking() public {
    // Single call impersonation
    vm.prank(alice);
    token.transfer(bob, 1000e18);

    // Multiple calls impersonation
    vm.startPrank(alice);
    token.approve(bob, 5000e18);
    token.transfer(bob, 1000e18);
    vm.stopPrank();

    // Prank with specific origin
    vm.prank(alice, alice); // msg.sender = alice, tx.origin = alice
}
```

### Time Manipulation

```solidity
function test_TimeTravel() public {
    uint256 initialTime = block.timestamp;

    // Move forward 1 day
    vm.warp(block.timestamp + 1 days);
    assertEq(block.timestamp, initialTime + 1 days);

    // Skip blocks
    vm.roll(block.number + 100);
    assertEq(block.number, 101); // Assuming started at block 1

    // Combined time and block manipulation
    vm.warp(block.timestamp + 1 weeks);
    vm.roll(block.number + 1000);
}
```

### Dealing with External Calls

```solidity
function test_MockExternalCalls() public {
    // Mock return data
    vm.mockCall(
        address(externalContract),
        abi.encodeWithSelector(ExternalContract.getPrice.selector),
        abi.encode(100e18)
    );

    // Verify call was made
    vm.expectCall(
        address(externalContract),
        abi.encodeWithSelector(ExternalContract.getPrice.selector)
    );

    uint256 price = myContract.fetchPrice();
    assertEq(price, 100e18);
}
```

### Environment Variable Testing

```solidity
function test_EnvironmentVariables() public {
    // Set environment variables
    vm.setEnv("TEST_VAR", "test_value");
    assertEq(vm.envString("TEST_VAR"), "test_value");

    // Test with different types
    vm.setEnv("TEST_UINT", "12345");
    assertEq(vm.envUint("TEST_UINT"), 12345);

    vm.setEnv("TEST_BOOL", "true");
    assertTrue(vm.envBool("TEST_BOOL"));
}
```

##  Fuzzing & Property Testing

### Basic Fuzzing

```solidity
function testFuzz_Transfer(uint256 amount) public {
    // Bound the input to valid range
    amount = bound(amount, 0, token.balanceOf(alice));

    uint256 aliceBalanceBefore = token.balanceOf(alice);
    uint256 bobBalanceBefore = token.balanceOf(bob);

    vm.prank(alice);
    token.transfer(bob, amount);

    // Verify post-conditions
    assertEq(token.balanceOf(alice), aliceBalanceBefore - amount);
    assertEq(token.balanceOf(bob), bobBalanceBefore + amount);
}
```

### Advanced Fuzzing

```solidity
function testFuzz_ComplexScenario(
    address sender,
    address recipient,
    uint256 amount,
    bool shouldApprove
) public {
    // Assume valid conditions
    vm.assume(sender != address(0));
    vm.assume(recipient != address(0));
    vm.assume(sender != recipient);
    vm.assume(amount > 0 && amount <= 1000000e18);

    // Setup
    deal(address(token), sender, amount * 2);

    if (shouldApprove) {
        vm.prank(sender);
        token.approve(address(this), amount);

        // Test transferFrom
        token.transferFrom(sender, recipient, amount);
    } else {
        // Test direct transfer
        vm.prank(sender);
        token.transfer(recipient, amount);
    }

    assertEq(token.balanceOf(recipient), amount);
}
```

### Property-Based Testing

```solidity
function testFuzz_PropertyConservation(
    uint256 amount1,
    uint256 amount2,
    address user1,
    address user2
) public {
    // Bound inputs
    amount1 = bound(amount1, 1, 1000000e18);
    amount2 = bound(amount2, 1, 1000000e18);
    vm.assume(user1 != user2);
    vm.assume(user1 != address(0) && user2 != address(0));

    // Property: Total supply should remain constant
    uint256 totalSupplyBefore = token.totalSupply();

    // Perform operations
    deal(address(token), user1, amount1);
    deal(address(token), user2, amount2);

    vm.prank(user1);
    token.transfer(user2, amount1 / 2);

    // Verify property holds
    assertEq(token.totalSupply(), totalSupplyBefore);
}
```

##  Invariant Testing

### Setup Invariant Tests

```solidity
// Create separate contract for invariant testing
contract TokenInvariantTest is Test {
    Token public token;
    TokenHandler public handler;

    function setUp() public {
        token = new Token("TestToken", "TEST", 1000000e18);
        handler = new TokenHandler(token);

        // Set target contract for invariant testing
        targetContract(address(handler));

        // Set target selectors
        bytes4[] memory selectors = new bytes4[](3);
        selectors[0] = TokenHandler.transfer.selector;
        selectors[1] = TokenHandler.mint.selector;
        selectors[2] = TokenHandler.burn.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
    }

    function invariant_TotalSupplyEqualsIndividualBalances() public {
        uint256 totalSupply = token.totalSupply();
        uint256 sumOfBalances = handler.sumOfBalances();
        assertEq(totalSupply, sumOfBalances);
    }

    function invariant_BalancesNeverNegative() public {
        address[] memory users = handler.getUsers();
        for (uint256 i = 0; i < users.length; i++) {
            assertGe(token.balanceOf(users[i]), 0);
        }
    }
}

// Handler contract for invariant testing
contract TokenHandler {
    Token public token;
    address[] public users;
    mapping(address => bool) public isUser;

    constructor(Token _token) {
        token = _token;
    }

    function transfer(uint256 userIndex, uint256 recipientIndex, uint256 amount) public {
        if (users.length < 2) return;

        userIndex = bound(userIndex, 0, users.length - 1);
        recipientIndex = bound(recipientIndex, 0, users.length - 1);

        if (userIndex == recipientIndex) return;

        address user = users[userIndex];
        address recipient = users[recipientIndex];

        amount = bound(amount, 0, token.balanceOf(user));

        vm.prank(user);
        token.transfer(recipient, amount);
    }

    function mint(uint256 amount) public {
        amount = bound(amount, 1, 1000000e18);

        address newUser = address(uint160(users.length + 1));
        if (!isUser[newUser]) {
            users.push(newUser);
            isUser[newUser] = true;
        }

        token.mint(newUser, amount);
    }

    function sumOfBalances() public view returns (uint256) {
        uint256 sum = 0;
        for (uint256 i = 0; i < users.length; i++) {
            sum += token.balanceOf(users[i]);
        }
        return sum;
    }

    function getUsers() public view returns (address[] memory) {
        return users;
    }
}
```

##  Mocking & Forking

### Mainnet Forking

```solidity
contract ForkTest is Test {
    uint256 public mainnetFork;

    // Mainnet addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86a33E6417C7C4944E7E72f0B3b9d8D2FAb0b;
    address public constant WHALE = 0x8EB8a3b98659Cce290402893d0123abb75E3ab28;

    function setUp() public {
        // Create fork at specific block
        mainnetFork = vm.createFork(vm.envString("ETH_RPC_URL"), 18000000);
        vm.selectFork(mainnetFork);
    }

    function test_ForkInteraction() public {
        // Interact with real contracts
        IERC20 weth = IERC20(WETH);
        uint256 whaleBalance = weth.balanceOf(WHALE);

        // Impersonate whale
        vm.startPrank(WHALE);
        weth.transfer(address(this), 1e18);
        vm.stopPrank();

        assertEq(weth.balanceOf(address(this)), 1e18);
        assertEq(weth.balanceOf(WHALE), whaleBalance - 1e18);
    }

    function test_MultipleForksRollback() public {
        // Create multiple forks
        uint256 fork1 = vm.createFork(vm.envString("ETH_RPC_URL"), 18000000);
        uint256 fork2 = vm.createFork(vm.envString("ETH_RPC_URL"), 18100000);

        // Test on fork1
        vm.selectFork(fork1);
        assertEq(block.number, 18000000);

        // Test on fork2
        vm.selectFork(fork2);
        assertEq(block.number, 18100000);

        // Back to original
        vm.selectFork(mainnetFork);
    }
}
```

### Advanced Mocking

```solidity
function test_AdvancedMocking() public {
    address mockContract = address(0x1234);

    // Mock multiple calls with different return values
    vm.mockCall(
        mockContract,
        abi.encodeWithSelector(IERC20.balanceOf.selector, alice),
        abi.encode(1000e18)
    );

    vm.mockCall(
        mockContract,
        abi.encodeWithSelector(IERC20.balanceOf.selector, bob),
        abi.encode(500e18)
    );

    // Clear specific mock
    vm.clearMockedCalls();

    // Mock call that reverts
    vm.mockCallRevert(
        mockContract,
        abi.encodeWithSelector(IERC20.transfer.selector, alice, 1000e18),
        "Insufficient balance"
    );
}
```

##  Gas Testing

### Basic Gas Testing

```solidity
function test_GasUsage() public {
    uint256 gasStart = gasleft();
    token.transfer(alice, 1000e18);
    uint256 gasUsed = gasStart - gasleft();

    // Assert reasonable gas usage
    assertLt(gasUsed, 50000);
    console.log("Gas used for transfer:", gasUsed);
}
```

### Gas Snapshots

```solidity
function test_GasSnapshot() public {
    // This will create a gas snapshot
    vm.snapshot();

    uint256 gasUsed = gasleft();
    token.transfer(alice, 1000e18);
    gasUsed = gasUsed - gasleft();

    // Gas snapshots are automatically compared between runs
    console.log("Transfer gas:", gasUsed);
}
```

### Gas Benchmarking

```solidity
function test_GasBenchmark() public {
    // Warm up (account for cold storage costs)
    token.transfer(alice, 1);

    // Measure multiple operations
    uint256 gasStart = gasleft();
    for (uint256 i = 0; i < 10; i++) {
        token.transfer(alice, 1e18);
    }
    uint256 gasUsed = gasStart - gasleft();

    console.log("Average gas per transfer:", gasUsed / 10);
}
```

##  Integration Testing

### Multi-Contract Integration

```solidity
contract DeFiIntegrationTest is Test {
    Token public token;
    LiquidityPool public pool;
    Router public router;

    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");

    function setUp() public {
        // Deploy all contracts
        token = new Token("TestToken", "TEST", 1000000e18);
        pool = new LiquidityPool(address(token));
        router = new Router(address(pool));

        // Setup initial state
        token.transfer(alice, 10000e18);
        token.transfer(bob, 10000e18);

        // Add initial liquidity
        vm.startPrank(alice);
        token.approve(address(pool), 5000e18);
        pool.addLiquidity(5000e18);
        vm.stopPrank();
    }

    function test_CompleteUserJourney() public {
        // User journey: Approve -> Swap -> Check balance
        vm.startPrank(bob);

        uint256 swapAmount = 1000e18;
        token.approve(address(router), swapAmount);

        uint256 expectedOutput = router.getAmountOut(swapAmount);
        uint256 balanceBefore = address(bob).balance;

        router.swapTokensForETH(swapAmount, expectedOutput);

        uint256 balanceAfter = address(bob).balance;
        assertGe(balanceAfter - balanceBefore, expectedOutput);

        vm.stopPrank();
    }
}
```

##  Best Practices

### Test Organization

```solidity
contract TokenTest is Test {
    // ============ STATE VARIABLES ============
    Token public token;
    address public owner;
    address public alice;

    // ============ SETUP ============
    function setUp() public {
        // Initialization code
    }

    // ============ UNIT TESTS ============
    function test_BasicFunctionality() public { }

    // ============ INTEGRATION TESTS ============
    function test_ComplexScenarios() public { }

    // ============ FUZZ TESTS ============
    function testFuzz_Parameters(uint256 param) public { }

    // ============ INVARIANT TESTS ============
    function invariant_Properties() public { }

    // ============ HELPERS ============
    function _helperFunction() internal { }
}
```

### Common Patterns

```solidity
// Pattern 1: Given-When-Then structure
function test_TransferTokens() public {
    // Given
    uint256 amount = 1000e18;
    uint256 aliceBalanceBefore = token.balanceOf(alice);

    // When
    vm.prank(alice);
    token.transfer(bob, amount);

    // Then
    assertEq(token.balanceOf(alice), aliceBalanceBefore - amount);
}

// Pattern 2: Setup-Execute-Verify
function test_ApprovalWorkflow() public {
    // Setup
    _setupTokenBalances();

    // Execute
    _performApprovalAndTransfer();

    // Verify
    _verifyFinalState();
}

// Pattern 3: Edge case testing
function test_EdgeCases() public {
    // Test with zero
    _testWithZeroAmount();

    // Test with maximum value
    _testWithMaxAmount();

    // Test boundary conditions
    _testBoundaryConditions();
}
```

### Performance Tips

```solidity
//  Efficient testing
function test_Efficient() public {
    // Use makeAddr for test addresses (cheaper than new addresses)
    address user = makeAddr("user");

    // Use deal for setting balances (cheaper than minting)
    deal(address(token), user, 1000e18);

    // Batch assertions
    (uint256 balance, uint256 allowance) = token.getBalanceAndAllowance(user, spender);
    assertEq(balance, expectedBalance);
    assertEq(allowance, expectedAllowance);
}

//  Inefficient testing
function test_Inefficient() public {
    // Creating new addresses is expensive
    address user = address(uint160(block.timestamp));

    // Multiple separate calls
    assertEq(token.balanceOf(user), expectedBalance);
    assertEq(token.allowance(user, spender), expectedAllowance);
}
```

### Error Handling

```solidity
function test_RobustErrorHandling() public {
    // Test all error conditions
    vm.expectRevert(Token.InsufficientBalance.selector);
    vm.prank(alice);
    token.transfer(bob, token.balanceOf(alice) + 1);

    vm.expectRevert(Token.ZeroAddress.selector);
    vm.prank(alice);
    token.transfer(address(0), 1000e18);

    // Test error messages are descriptive
    try token.transfer(address(0), 1000e18) {
        fail("Should have reverted");
    } catch Error(string memory reason) {
        assertEq(reason, "Transfer to zero address");
    }
}
```

---

**Testing complete!**  Your contracts are now thoroughly tested and ready for deployment.

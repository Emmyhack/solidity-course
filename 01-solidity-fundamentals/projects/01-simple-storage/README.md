# Project 1: Simple Storage Contract

Create a smart contract that manages stored data with access controls and events.

## Project Objectives

Build a storage contract that demonstrates:

- State variables and data persistence
- Function visibility and access control
- Events and logging
- Input validation with require statements
- Basic contract interaction patterns

##  Requirements

### Core Features

1. **Data Storage**: Store and retrieve different types of data
2. **Access Control**: Only authorized users can modify data
3. **Event Logging**: Log all important changes
4. **Input Validation**: Validate all inputs with meaningful error messages

### Specific Functions to Implement

```solidity
// Store and retrieve a number
function storeNumber(uint256 _number) public
function getNumber() public view returns (uint256)

// Store and retrieve a string
function storeText(string memory _text) public
function getText() public view returns (string memory)

// Store user data
function storeUserData(string memory _name, uint256 _age) public
function getUserData(address _user) public view returns (string memory, uint256)

// Admin functions
function addAuthorizedUser(address _user) public
function removeAuthorizedUser(address _user) public
function isAuthorized(address _user) public view returns (bool)
```

### Events to Implement

```solidity
event NumberStored(uint256 number, address storedBy);
event TextStored(string text, address storedBy);
event UserDataStored(address user, string name, uint256 age);
event UserAuthorized(address user, address authorizedBy);
event UserDeauthorized(address user, address deauthorizedBy);
```

##  Implementation Steps

### Step 1: Contract Structure

1. Create the contract with appropriate license and pragma
2. Define state variables for storing data
3. Define events for logging changes
4. Implement constructor to set contract owner

### Step 2: Access Control

1. Create mapping to track authorized users
2. Add modifier for owner-only functions
3. Add modifier for authorized-user functions
4. Implement authorization management functions

### Step 3: Storage Functions

1. Implement number storage with validation
2. Implement text storage with validation
3. Implement user data storage with validation
4. Add appropriate require statements

### Step 4: View Functions

1. Implement getter functions for stored data
2. Add utility functions for contract information
3. Ensure all view functions are properly marked

### Step 5: Testing & Deployment

1. Test all functions in Remix
2. Test access control works correctly
3. Verify events are emitted properly
4. Test edge cases and error conditions

##  File Structure

Create these files in the `projects/01-simple-storage/` directory:

```
01-simple-storage/
├── README.md (this file)
├── SimpleStorage.sol (your implementation)
├── test-plan.md (testing instructions)
└── deployment-notes.md (deployment steps)
```

##  Acceptance Criteria

Your contract should:

- [ ] Deploy successfully without errors
- [ ] Allow owner to authorize/deauthorize users
- [ ] Allow authorized users to store data
- [ ] Prevent unauthorized users from storing data
- [ ] Emit events for all state changes
- [ ] Handle edge cases gracefully
- [ ] Have meaningful error messages
- [ ] Follow Solidity best practices

##  Testing Checklist

Test these scenarios:

- [ ] Deploy contract (owner should be authorized)
- [ ] Store number as owner
- [ ] Store text as owner
- [ ] Store user data as owner
- [ ] Try storing as unauthorized user (should fail)
- [ ] Authorize a new user
- [ ] Store data as newly authorized user
- [ ] Deauthorize user and try storing (should fail)
- [ ] Try authorizing user as non-owner (should fail)
- [ ] Check all events are emitted correctly

##  Bonus Challenges

If you complete the basic requirements, try these:

1. Add a function to clear all stored data (owner only)
2. Add a counter that tracks how many times data has been stored
3. Add a function to get all authorized users (hint: you'll need an array)
4. Add data history - store previous values with timestamps
5. Add a pause mechanism that stops all storage operations

##  Code Review Points

When reviewing your code, check:

- Is the code well-commented and readable?
- Are all require statements meaningful?
- Are events emitted at the right times?
- Is access control implemented correctly?
- Are there any potential security issues?
- Is gas usage optimized where possible?

##  Learning Resources

- [Solidity by Example - Storage](https://solidity-by-example.org/)
- [OpenZeppelin Access Control](https://docs.openzeppelin.com/contracts/4.x/access-control)
- [Ethereum Events Documentation](https://docs.soliditylang.org/en/latest/contracts.html#events)

---

**Ready to code?** Start implementing `SimpleStorage.sol` and don't forget to test thoroughly! 

Need help? Check the [solution](../solutions/01-simple-storage-solution.sol) only after attempting the project yourself.

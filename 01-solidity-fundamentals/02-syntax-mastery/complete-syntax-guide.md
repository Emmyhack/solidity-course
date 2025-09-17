# Solidity Syntax Mastery - Every Element Explained

🎯 **Goal**: Master every piece of Solidity syntax through practical examples and real-world applications.

## 🗂️ Learning Path Overview

### **📚 What You'll Master**

1. **[Contract Structure](#contract-structure)** - How smart contracts are organized
2. **[Variables & Data Types](#variables--data-types)** - Storing different kinds of data
3. **[Functions](#functions)** - Code that does things
4. **[Modifiers](#modifiers)** - Reusable code snippets for security
5. **[Events](#events)** - Logging what happens
6. **[Error Handling](#error-handling)** - Dealing with problems
7. **[Inheritance](#inheritance)** - Reusing code from other contracts
8. **[Libraries](#libraries)** - Shared utility functions

### **🚀 Real-World Project**: Digital Banking System

As we learn each syntax element, we'll build a complete **Digital Bank** that handles:

- 💰 Account creation and management
- 💸 Deposits and withdrawals
- 🔄 Transfers between accounts
- 📊 Interest calculations
- 🛡️ Security and access controls
- 📈 Transaction history

---

## 📋 Contract Structure

### **🏗️ Basic Contract Template**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DigitalBank {
    // 1. State Variables (permanent storage)
    // 2. Events (logging)
    // 3. Modifiers (reusable code)
    // 4. Constructor (initialization)
    // 5. Functions (functionality)
}
```

**🔍 SYNTAX BREAKDOWN:**

#### **License and Version Declaration**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
```

- **Purpose**: Legal compliance and compiler version
- **Real-World**: Like copyright notice on software
- **Why Important**: Required by most blockchain networks

#### **Contract Declaration**

```solidity
contract DigitalBank {
    // Contract body
}
```

- **`contract`**: Keyword to create a smart contract
- **`DigitalBank`**: Contract name (like class name in OOP)
- **`{ }`**: Contract body container
- **Real-World**: Like creating a new business entity

---

## 🗄️ Variables & Data Types

### **📊 State Variables (Permanent Storage)**

```solidity
contract DigitalBank {
    // Address types
    address public owner;                    // Single address
    address payable public bankVault;        // Address that can receive Ether

    // Numeric types
    uint256 public totalSupply;             // Unsigned integer (0 to very large)
    int256 public bankProfit;               // Signed integer (negative to positive)
    uint8 public interestRate;              // Small integer (0-255)

    // Boolean
    bool public bankIsOpen;                 // True or false

    // String and bytes
    string public bankName;                 // Text data
    bytes32 public bankLicense;             // Fixed-size byte array

    // Mappings (like dictionaries)
    mapping(address => uint256) public balances;           // Address to balance
    mapping(address => bool) public isCustomer;           // Address to status
    mapping(address => string) public customerNames;      // Address to name

    // Arrays
    address[] public customers;             // Dynamic array of addresses
    uint256[10] public monthlyProfits;     // Fixed-size array

    // Structs (custom data types)
    struct Account {
        string name;
        uint256 balance;
        uint256 accountNumber;
        bool isActive;
        uint256 createdAt;
    }

    // Mapping of address to struct
    mapping(address => Account) public accounts;
}
```

**🔍 DETAILED SYNTAX BREAKDOWN:**

#### **Address Types**

```solidity
address public owner;
address payable public bankVault;
```

- **`address`**: Holds Ethereum addresses (20 bytes)
- **`address payable`**: Can receive Ether transfers
- **`public`**: Automatically creates getter function
- **Real-World**: Like bank account numbers or employee IDs

#### **Numeric Types**

```solidity
uint256 public totalSupply;    // 0 to 2^256-1
int256 public bankProfit;      // -2^255 to 2^255-1
uint8 public interestRate;     // 0 to 255
```

- **`uint256`**: Unsigned integer (no negative numbers)
- **`int256`**: Signed integer (can be negative)
- **`uint8`**: Small unsigned integer (saves gas)
- **Real-World**: Like account balances, temperatures, counts

#### **Mapping (Key-Value Storage)**

```solidity
mapping(address => uint256) public balances;
```

- **`mapping`**: Keyword for key-value storage
- **`address => uint256`**: Key type => Value type
- **`public`**: Creates automatic getter function
- **Real-World**: Like a phone book (name → phone number)

#### **Structs (Custom Data Types)**

```solidity
struct Account {
    string name;           // Customer name
    uint256 balance;       // Account balance
    uint256 accountNumber; // Unique account ID
    bool isActive;         // Account status
    uint256 createdAt;     // Creation timestamp
}
```

- **`struct`**: Groups related data together
- **Real-World**: Like a customer record in a database

### **⚡ Memory vs Storage vs Calldata**

```solidity
function createAccount(
    string memory _name,        // Temporary data in function
    string calldata _id        // Read-only external data
) public {
    // Storage - permanent blockchain storage
    accounts[msg.sender].name = _name;

    // Memory - temporary during function execution
    string memory tempName = _name;

    // Calldata - read-only function parameter data
    // _id is in calldata (more gas efficient)
}
```

**🔍 STORAGE LOCATION BREAKDOWN:**

- **`storage`**: Permanent blockchain storage (expensive)
- **`memory`**: Temporary RAM-like storage (moderate cost)
- **`calldata`**: Read-only function parameters (cheapest)

---

## ⚙️ Functions

### **📝 Function Anatomy**

```solidity
function functionName(
    parameterType parameterName
) visibility mutability returns (returnType) {
    // Function body
}
```

### **🏦 Banking Functions with Every Syntax**

```solidity
contract DigitalBank {
    // Pure function - no state reading/writing
    function calculateInterest(
        uint256 principal,
        uint8 rate,
        uint256 time
    ) public pure returns (uint256) {
        return (principal * rate * time) / 100;
    }

    // View function - reads state but doesn't modify
    function getBalance(address customer) public view returns (uint256) {
        return balances[customer];
    }

    // Payable function - can receive Ether
    function deposit() public payable {
        require(msg.value > 0, "Deposit must be greater than 0");
        balances[msg.sender] += msg.value;
        totalSupply += msg.value;
    }

    // Function with multiple return values
    function getAccountInfo(address customer) public view returns (
        string memory name,
        uint256 balance,
        bool isActive,
        uint256 accountNumber
    ) {
        Account memory account = accounts[customer];
        return (
            account.name,
            account.balance,
            account.isActive,
            account.accountNumber
        );
    }

    // Internal function - only callable within this contract
    function _updateInterest(address customer) internal {
        uint256 interest = calculateInterest(
            balances[customer],
            interestRate,
            1
        );
        balances[customer] += interest;
    }

    // Private function - only callable within this exact contract
    function _validateCustomer(address customer) private view returns (bool) {
        return accounts[customer].isActive;
    }
}
```

**🔍 FUNCTION SYNTAX BREAKDOWN:**

#### **Visibility Modifiers**

```solidity
function publicFunction() public { }      // Anyone can call
function externalFunction() external { }  // Only external calls
function internalFunction() internal { }  // This contract + inheriting
function privateFunction() private { }    // Only this exact contract
```

#### **State Mutability**

```solidity
function pureFunction() public pure { }     // No state access
function viewFunction() public view { }     // Read state only
function payableFunction() public payable { } // Can receive Ether
// No keyword = can modify state
```

#### **Function Parameters**

```solidity
function transfer(
    address to,              // Required parameter
    uint256 amount          // Required parameter
) public {
    // Function body
}
```

#### **Return Values**

```solidity
// Single return
function getBalance() public view returns (uint256) {
    return balances[msg.sender];
}

// Multiple returns
function getInfo() public view returns (string memory, uint256, bool) {
    return ("John", 1000, true);
}

// Named returns
function getDetails() public view returns (
    string memory customerName,
    uint256 customerBalance
) {
    customerName = "John";
    customerBalance = 1000;
    // Automatically returns named variables
}
```

---

## 🛡️ Modifiers

### **🔒 Security Modifiers for Banking**

```solidity
contract DigitalBank {
    address public owner;
    mapping(address => bool) public isCustomer;

    // Modifier definition
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;  // Placeholder for function body
    }

    modifier onlyCustomer() {
        require(isCustomer[msg.sender], "Only customers can call this function");
        _;
    }

    modifier validAmount(uint256 amount) {
        require(amount > 0, "Amount must be greater than 0");
        require(amount <= balances[msg.sender], "Insufficient balance");
        _;
    }

    modifier notZeroAddress(address addr) {
        require(addr != address(0), "Cannot use zero address");
        _;
    }

    // Using modifiers
    function setInterestRate(uint8 newRate) public onlyOwner {
        interestRate = newRate;
    }

    function withdraw(uint256 amount)
        public
        onlyCustomer
        validAmount(amount)
    {
        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function transferTo(address to, uint256 amount)
        public
        onlyCustomer
        validAmount(amount)
        notZeroAddress(to)
    {
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
}
```

**🔍 MODIFIER SYNTAX BREAKDOWN:**

#### **Basic Modifier Structure**

```solidity
modifier modifierName(parameters) {
    // Validation code before function
    require(condition, "Error message");
    _;  // This is where the function body will execute
    // Code after function execution (if any)
}
```

#### **Using Modifiers**

```solidity
function myFunction() public modifierName(parameter) {
    // Function body executes where _ is in modifier
}
```

#### **Multiple Modifiers**

```solidity
function complexFunction()
    public
    modifier1
    modifier2(parameter)
    modifier3
{
    // Modifiers execute in order: modifier1, modifier2, modifier3
}
```

---

## 📡 Events

### **📊 Banking Event Logging**

```solidity
contract DigitalBank {
    // Event declarations
    event AccountCreated(
        address indexed customer,     // Indexed for filtering
        string name,                 // Not indexed
        uint256 indexed accountNumber, // Indexed for filtering
        uint256 timestamp
    );

    event Deposit(
        address indexed from,
        uint256 amount,
        uint256 newBalance,
        uint256 timestamp
    );

    event Withdrawal(
        address indexed to,
        uint256 amount,
        uint256 newBalance,
        uint256 timestamp
    );

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 timestamp
    );

    // Emitting events in functions
    function createAccount(string memory name) public {
        uint256 accountNumber = customers.length + 1;

        accounts[msg.sender] = Account({
            name: name,
            balance: 0,
            accountNumber: accountNumber,
            isActive: true,
            createdAt: block.timestamp
        });

        customers.push(msg.sender);
        isCustomer[msg.sender] = true;

        // Emit event
        emit AccountCreated(
            msg.sender,
            name,
            accountNumber,
            block.timestamp
        );
    }

    function deposit() public payable {
        require(msg.value > 0, "Must deposit more than 0");

        balances[msg.sender] += msg.value;

        // Emit event
        emit Deposit(
            msg.sender,
            msg.value,
            balances[msg.sender],
            block.timestamp
        );
    }
}
```

**🔍 EVENT SYNTAX BREAKDOWN:**

#### **Event Declaration**

```solidity
event EventName(
    dataType indexed parameter1,  // Indexed for filtering
    dataType parameter2,          // Not indexed
    dataType indexed parameter3   // Indexed for filtering
);
```

#### **Event Parameters**

- **`indexed`**: Allows filtering by this parameter (max 3 indexed per event)
- **Non-indexed**: Stored in event data but not filterable
- **Real-World**: Like database indexes for fast searching

#### **Emitting Events**

```solidity
emit EventName(value1, value2, value3);
```

#### **Why Events Matter**

- **Frontend Integration**: Web apps can listen for events
- **Audit Trail**: Permanent log of all actions
- **Gas Efficient**: Cheaper than storing data in state variables
- **External Monitoring**: Other contracts can react to events

---

## ⚠️ Error Handling

### **🚨 Banking Security with Error Handling**

```solidity
contract DigitalBank {
    // Custom error definitions (more gas efficient)
    error InsufficientBalance(uint256 requested, uint256 available);
    error UnauthorizedAccess(address caller);
    error InvalidAmount(uint256 amount);
    error AccountNotFound(address account);

    function withdrawAdvanced(uint256 amount) public {
        // Method 1: require() - most common
        require(isCustomer[msg.sender], "Not a customer");
        require(amount > 0, "Amount must be positive");

        // Method 2: Custom errors with revert (gas efficient)
        if (amount > balances[msg.sender]) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        // Method 3: assert() - for internal errors only
        assert(balances[msg.sender] >= amount); // Should never fail if above checks pass

        balances[msg.sender] -= amount;
        payable(msg.sender).transfer(amount);
    }

    function safeTransfer(address to, uint256 amount) public {
        // Multiple require statements
        require(to != address(0), "Cannot transfer to zero address");
        require(to != msg.sender, "Cannot transfer to yourself");
        require(isCustomer[msg.sender], "Sender not a customer");
        require(amount > 0, "Amount must be positive");

        // Custom error for complex condition
        if (amount > balances[msg.sender]) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount, block.timestamp);
    }

    // Try-catch for external calls (advanced)
    function callExternalContract(address target) public {
        try ExternalContract(target).someFunction() returns (bool success) {
            // Handle success
            if (success) {
                // Do something
            }
        } catch Error(string memory reason) {
            // Handle revert with reason
            revert(string(abi.encodePacked("External call failed: ", reason)));
        } catch (bytes memory lowLevelData) {
            // Handle other failures
            revert("External call failed with unknown error");
        }
    }
}
```

**🔍 ERROR HANDLING SYNTAX BREAKDOWN:**

#### **require() Statement**

```solidity
require(condition, "Error message");
```

- **Purpose**: Validate inputs and conditions
- **Gas**: Refunds remaining gas if condition fails
- **When to use**: Input validation, access control

#### **Custom Errors**

```solidity
// Declaration
error ErrorName(parameter1, parameter2);

// Usage
if (condition) {
    revert ErrorName(value1, value2);
}
```

- **Purpose**: More gas efficient than require strings
- **When to use**: Frequent error conditions

#### **assert() Statement**

```solidity
assert(condition);
```

- **Purpose**: Check internal invariants
- **Gas**: Consumes all remaining gas if fails
- **When to use**: Internal logic validation (should never fail)

#### **try-catch (External Calls)**

```solidity
try externalContract.function() returns (returnType value) {
    // Success handling
} catch Error(string memory reason) {
    // Revert with reason
} catch (bytes memory lowLevelData) {
    // Other failures
}
```

---

## 🧬 Inheritance

### **🏦 Building Banking Hierarchy**

```solidity
// Base contract
contract BankingBase {
    address public owner;
    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // Virtual function - can be overridden
    function deposit() public virtual payable {
        balances[msg.sender] += msg.value;
        emit Deposit(msg.sender, msg.value);
    }
}

// Inherited contract
contract SavingsAccount is BankingBase {
    uint8 public interestRate = 5;

    // Override the deposit function
    function deposit() public override payable {
        super.deposit(); // Call parent function

        // Add interest calculation
        uint256 interest = (msg.value * interestRate) / 100;
        balances[msg.sender] += interest;
    }

    // New function specific to savings
    function calculateInterest(address account) public view returns (uint256) {
        return (balances[account] * interestRate) / 100;
    }
}

// Multiple inheritance
contract PremiumSavings is SavingsAccount {
    mapping(address => bool) public isPremium;

    function setPremiumStatus(address account, bool status) public onlyOwner {
        isPremium[account] = status;
    }

    // Override with additional logic
    function deposit() public override payable {
        super.deposit(); // Call SavingsAccount.deposit()

        // Premium customers get bonus
        if (isPremium[msg.sender]) {
            uint256 bonus = msg.value / 100; // 1% bonus
            balances[msg.sender] += bonus;
        }
    }
}
```

**🔍 INHERITANCE SYNTAX BREAKDOWN:**

#### **Basic Inheritance**

```solidity
contract Child is Parent {
    // Child inherits all public/internal functions and variables
}
```

#### **Virtual and Override**

```solidity
// Parent contract
function myFunction() public virtual {
    // Can be overridden
}

// Child contract
function myFunction() public override {
    // Overrides parent function
}
```

#### **Super Keyword**

```solidity
function myFunction() public override {
    super.myFunction(); // Call parent version
    // Additional logic here
}
```

#### **Multiple Inheritance**

```solidity
contract Child is Parent1, Parent2 {
    // Inherits from both parents
    // Must handle function conflicts
}
```

---

## 📚 Libraries

### **🔧 Banking Utility Library**

```solidity
// Library definition
library MathUtils {
    // Library functions are internal by default
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Subtraction underflow");
        return a - b;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) return 0;
        uint256 c = a * b;
        require(c / a == b, "Multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "Division by zero");
        return a / b;
    }
}

// Using library with 'using for'
contract DigitalBank {
    using MathUtils for uint256;

    mapping(address => uint256) public balances;

    function deposit() public payable {
        // Using library function with dot notation
        balances[msg.sender] = balances[msg.sender].add(msg.value);
    }

    function withdraw(uint256 amount) public {
        // Direct library call
        balances[msg.sender] = MathUtils.sub(balances[msg.sender], amount);
        payable(msg.sender).transfer(amount);
    }
}

// Advanced library with structs
library AccountLib {
    struct Account {
        uint256 balance;
        uint256 lastActivity;
        bool isActive;
    }

    function activate(Account storage account) internal {
        account.isActive = true;
        account.lastActivity = block.timestamp;
    }

    function deactivate(Account storage account) internal {
        account.isActive = false;
        account.lastActivity = block.timestamp;
    }

    function updateActivity(Account storage account) internal {
        account.lastActivity = block.timestamp;
    }
}

contract BankWithLibrary {
    using AccountLib for AccountLib.Account;

    mapping(address => AccountLib.Account) public accounts;

    function openAccount() public {
        accounts[msg.sender].activate(); // Using library function
    }

    function closeAccount() public {
        accounts[msg.sender].deactivate(); // Using library function
    }
}
```

**🔍 LIBRARY SYNTAX BREAKDOWN:**

#### **Library Declaration**

```solidity
library LibraryName {
    // Only internal and private functions
    function functionName(parameters) internal pure returns (returnType) {
        // Function body
    }
}
```

#### **Using Libraries**

```solidity
// Method 1: Direct call
LibraryName.functionName(parameters);

// Method 2: Using for directive
using LibraryName for dataType;
// Now you can call: variable.functionName(otherParameters)
```

#### **Library Restrictions**

- No state variables (stateless)
- No inheritance
- Cannot be destroyed
- Functions are `internal` or `private` only
- Cannot receive Ether

---

## 🎯 Complete Banking System Example

Here's how all these syntax elements work together in a real banking system:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Import library
library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "Addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "Subtraction underflow");
        return a - b;
    }
}

contract DigitalBank {
    using SafeMath for uint256;

    // State variables
    address public owner;
    string public bankName;
    uint8 public interestRate;
    uint256 public totalDeposits;

    // Struct
    struct Account {
        string customerName;
        uint256 balance;
        uint256 accountNumber;
        bool isActive;
        uint256 createdAt;
    }

    // Mappings
    mapping(address => Account) public accounts;
    mapping(address => bool) public isCustomer;
    address[] public customers;

    // Events
    event AccountCreated(address indexed customer, string name, uint256 accountNumber);
    event Deposit(address indexed customer, uint256 amount, uint256 newBalance);
    event Withdrawal(address indexed customer, uint256 amount, uint256 newBalance);
    event Transfer(address indexed from, address indexed to, uint256 amount);

    // Custom errors
    error InsufficientBalance(uint256 requested, uint256 available);
    error UnauthorizedAccess();
    error InvalidAmount();

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert UnauthorizedAccess();
        _;
    }

    modifier onlyCustomer() {
        require(isCustomer[msg.sender], "Not a customer");
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    // Constructor
    constructor(string memory _bankName, uint8 _interestRate) {
        owner = msg.sender;
        bankName = _bankName;
        interestRate = _interestRate;
    }

    // Functions
    function createAccount(string memory _name) public {
        require(!isCustomer[msg.sender], "Account already exists");
        require(bytes(_name).length > 0, "Name cannot be empty");

        uint256 accountNumber = customers.length + 1;

        accounts[msg.sender] = Account({
            customerName: _name,
            balance: 0,
            accountNumber: accountNumber,
            isActive: true,
            createdAt: block.timestamp
        });

        customers.push(msg.sender);
        isCustomer[msg.sender] = true;

        emit AccountCreated(msg.sender, _name, accountNumber);
    }

    function deposit() public payable onlyCustomer validAmount(msg.value) {
        accounts[msg.sender].balance = accounts[msg.sender].balance.add(msg.value);
        totalDeposits = totalDeposits.add(msg.value);

        emit Deposit(msg.sender, msg.value, accounts[msg.sender].balance);
    }

    function withdraw(uint256 amount) public onlyCustomer validAmount(amount) {
        if (amount > accounts[msg.sender].balance) {
            revert InsufficientBalance(amount, accounts[msg.sender].balance);
        }

        accounts[msg.sender].balance = accounts[msg.sender].balance.sub(amount);
        totalDeposits = totalDeposits.sub(amount);

        payable(msg.sender).transfer(amount);

        emit Withdrawal(msg.sender, amount, accounts[msg.sender].balance);
    }

    function transfer(address to, uint256 amount)
        public
        onlyCustomer
        validAmount(amount)
    {
        require(isCustomer[to], "Recipient is not a customer");

        if (amount > accounts[msg.sender].balance) {
            revert InsufficientBalance(amount, accounts[msg.sender].balance);
        }

        accounts[msg.sender].balance = accounts[msg.sender].balance.sub(amount);
        accounts[to].balance = accounts[to].balance.add(amount);

        emit Transfer(msg.sender, to, amount);
    }

    // View functions
    function getBalance() public view onlyCustomer returns (uint256) {
        return accounts[msg.sender].balance;
    }

    function getAccountInfo() public view onlyCustomer returns (
        string memory name,
        uint256 balance,
        uint256 accountNumber,
        bool isActive,
        uint256 createdAt
    ) {
        Account memory account = accounts[msg.sender];
        return (
            account.customerName,
            account.balance,
            account.accountNumber,
            account.isActive,
            account.createdAt
        );
    }

    // Owner functions
    function setInterestRate(uint8 newRate) public onlyOwner {
        require(newRate <= 20, "Interest rate too high");
        interestRate = newRate;
    }

    function getBankStats() public view onlyOwner returns (
        uint256 totalCustomers,
        uint256 totalDepositsAmount,
        uint256 bankBalance
    ) {
        return (
            customers.length,
            totalDeposits,
            address(this).balance
        );
    }
}
```

## 🎓 Syntax Summary Checklist

### **✅ Contract Structure**

- [ ] License declaration (`SPDX-License-Identifier`)
- [ ] Pragma statement (`pragma solidity`)
- [ ] Contract declaration (`contract Name`)
- [ ] Proper organization (state vars → events → modifiers → constructor → functions)

### **✅ Variables & Data Types**

- [ ] Address types (`address`, `address payable`)
- [ ] Numeric types (`uint256`, `int256`, `uint8`)
- [ ] Boolean (`bool`)
- [ ] Strings and bytes (`string`, `bytes32`)
- [ ] Mappings (`mapping(key => value)`)
- [ ] Arrays (`type[]`, `type[size]`)
- [ ] Structs (`struct Name { }`)
- [ ] Storage locations (`storage`, `memory`, `calldata`)

### **✅ Functions**

- [ ] Function declaration (`function name()`)
- [ ] Visibility (`public`, `external`, `internal`, `private`)
- [ ] State mutability (`pure`, `view`, `payable`)
- [ ] Parameters and return values
- [ ] Multiple return values
- [ ] Named returns

### **✅ Modifiers**

- [ ] Modifier declaration (`modifier name()`)
- [ ] Using modifiers in functions
- [ ] Multiple modifiers
- [ ] Placeholder (`_`)

### **✅ Events**

- [ ] Event declaration (`event Name()`)
- [ ] Indexed parameters
- [ ] Emitting events (`emit EventName()`)

### **✅ Error Handling**

- [ ] `require()` statements
- [ ] Custom errors
- [ ] `revert()` statements
- [ ] `assert()` for invariants
- [ ] `try-catch` for external calls

### **✅ Inheritance**

- [ ] Basic inheritance (`is Parent`)
- [ ] Virtual functions
- [ ] Override functions
- [ ] Super calls
- [ ] Multiple inheritance

### **✅ Libraries**

- [ ] Library declaration (`library Name`)
- [ ] Using libraries (`using LibraryName for Type`)
- [ ] Internal functions only
- [ ] No state variables

## 🚀 Next Steps

Congratulations! You now understand every piece of Solidity syntax. Ready to put it all together?

**Next Module**: [Real-World Projects](../03-real-projects/) - Build complete DeFi applications using everything you've learned!

**Recommended Path**:

1. **[Digital Bank System](../03-real-projects/digital-bank/)** - Your first complete DApp
2. **[NFT Marketplace](../03-real-projects/nft-marketplace/)** - Learn token standards
3. **[DeFi Protocol](../03-real-projects/defi-protocol/)** - Advanced DeFi concepts

Each project builds on the syntax you've mastered here! 🎯

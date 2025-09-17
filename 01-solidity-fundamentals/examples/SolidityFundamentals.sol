// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title SolidityFundamentals - Complete Syntax Guide
 * @author Solidity Course - Learn by Building Real DeFi
 * @notice Comprehensive demonstration of Solidity syntax with real-world examples
 * @dev Every syntax element explained with practical examples and use cases
 *
 * LEARNING GOALS:
 * - Master every Solidity data type with practical examples
 * - Understand when and why to use each syntax element
 * - See real-world applications of each concept
 * - Build foundation for complex DeFi protocols
 *
 * STRUCTURE:
 * 1. Data Types (all varieties with examples)
 * 2. Variables (state, local, global)
 * 3. Functions (all types with modifiers)
 * 4. Control Structures (loops, conditionals)
 * 5. Advanced Features (events, errors, modifiers)
 */

contract SolidityFundamentals {
    // ===== 1. DATA TYPES DEMONSTRATION =====

    // === BOOLEAN TYPE ===
    bool public isActive = true; // Default: false
    bool public isCompleted; // Automatically false
    bool private isInternalFlag = false; // Private boolean

    // Real-world usage: Protocol states, user permissions, feature flags
    bool public protocolPaused; // Emergency pause state
    bool public upgradeAllowed; // Upgrade authorization
    mapping(address => bool) public isWhitelisted; // User permissions

    // === INTEGER TYPES ===

    // Unsigned integers (only positive numbers + zero)
    uint8 public percentage = 85; // 0 to 255 (good for percentages)
    uint16 public tokenId = 12345; // 0 to 65,535 (NFT IDs)
    uint32 public timestamp32; // 0 to 4.3 billion (timestamps until 2106)
    uint64 public largeNumber; // 0 to 18.4 quintillion
    uint128 public veryLargeNumber; // 0 to 340 undecillion
    uint256 public balance = 1000000000000000000; // 1 ETH in wei (most common)
    uint public defaultUint = 100; // Same as uint256

    // Signed integers (positive, negative, zero)
    int8 public temperature = -15; // -128 to 127
    int16 public elevation = -50; // -32,768 to 32,767
    int32 public coordinate; // GPS coordinates
    int64 public bigSigned; // Large signed numbers
    int128 public hugeSigned; // Very large signed numbers
    int256 public balance_signed; // Can be negative (debt systems)
    int public defaultInt = -42; // Same as int256

    // Real-world usage examples:
    uint256 public constant MIN_DEPOSIT = 0.001 ether; // Minimum deposit amount
    uint256 public constant MAX_SUPPLY = 21000000; // Bitcoin-style max supply
    uint8 public constant DECIMALS = 18; // Token decimals (ERC20 standard)
    uint32 public lockPeriod = 7 days; // Time-based locks
    int256 public poolBalance; // Can be negative (debt pools)

    // === ADDRESS TYPE ===
    address public owner; // Ethereum address (20 bytes)
    address payable public treasury; // Can receive ETH
    address private admin; // Private admin address
    address constant ZERO_ADDRESS = address(0); // Zero address constant

    // Real-world address usage:
    address public tokenContract; // External contract address
    mapping(address => uint256) public balances; // User balances (ERC20 pattern)
    mapping(address => bool) public authorized; // Access control
    address[] public stakeholders; // Dynamic array of addresses

    // === BYTES TYPES ===

    // Fixed-size bytes (more gas efficient)
    bytes1 public flag = 0x01; // Single byte
    bytes4 public selector; // Function selector
    bytes8 public shortId; // 8-byte identifier
    bytes16 public uuid; // UUID storage
    bytes32 public hash; // Keccak256 hash result
    bytes32 public merkleRoot; // Merkle tree root

    // Dynamic bytes (flexible size)
    bytes public data; // Dynamic byte array
    bytes public encryptedData; // Encrypted information

    // Real-world bytes usage:
    bytes32 public constant DOMAIN_SEPARATOR = keccak256("MyProtocol");
    bytes4 public constant SELECTOR =
        bytes4(keccak256("transfer(address,uint256)"));
    mapping(bytes32 => bool) public processedHashes; // Prevent replay attacks

    // === STRING TYPE ===
    string public name = "MyToken"; // Dynamic string
    string public symbol = "MTK"; // Token symbol
    string private secretCode; // Private string
    string public constant PROTOCOL_NAME = "DeFi Protocol"; // Constant string

    // Real-world string usage:
    mapping(string => address) public nameToAddress; // ENS-style mapping
    mapping(address => string) public addressToName; // Reverse lookup
    string[] public supportedNetworks; // List of networks

    // === ARRAY TYPES ===

    // Fixed-size arrays
    uint256[5] public fixedNumbers; // Exactly 5 numbers
    address[10] public topHolders; // Top 10 token holders
    bool[7] public weekDays; // Days of week flags

    // Dynamic arrays
    uint256[] public allNumbers; // Unlimited size
    address[] public allUsers; // All registered users
    string[] public categories; // Category list

    // Nested arrays
    uint256[][] public matrix; // 2D array
    mapping(address => uint256[]) public userTransactions; // User's transaction list

    // Real-world array usage:
    address[] public validators; // Proof-of-stake validators
    uint256[] public rewardRates; // Historical reward rates
    mapping(address => bytes32[]) public userHashes; // User's data hashes

    // === MAPPING TYPES ===

    // Simple mappings
    mapping(address => uint256) public tokenBalance; // ERC20 balances
    mapping(uint256 => address) public tokenOwner; // NFT ownership
    mapping(string => bool) public validCodes; // Code validation

    // Nested mappings
    mapping(address => mapping(address => uint256)) public allowances; // ERC20 allowances
    mapping(address => mapping(uint256 => bool)) public permissions; // User permissions
    mapping(bytes32 => mapping(address => bool)) public votes; // Governance votes

    // Complex nested mappings
    mapping(address => mapping(string => mapping(uint256 => bool)))
        public complexData;
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public tripleMapping;

    // Real-world mapping patterns:
    mapping(address => bool) public isBlacklisted; // Security blacklist
    mapping(bytes32 => uint256) public proposalVotes; // Governance voting
    mapping(address => mapping(bytes4 => bool)) public functionAccess; // Function-level permissions

    // === STRUCT TYPES ===

    // Simple struct
    struct User {
        address userAddress;
        string name;
        uint256 balance;
        bool isActive;
        uint256 joinDate;
    }

    // Complex struct with nested data
    struct LendingPool {
        address asset; // Asset being lent
        uint256 totalSupply; // Total supplied
        uint256 totalBorrowed; // Total borrowed
        uint256 interestRate; // Current interest rate
        bool isActive; // Pool status
        mapping(address => uint256) userDeposits; // User deposits in pool
    }

    // Struct with arrays
    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool executed;
        address[] voters; // List of voters
        mapping(address => bool) hasVoted; // Voting tracker
    }

    // Using structs
    User public adminUser; // Single user instance
    mapping(address => User) public users; // User registry
    LendingPool[] public pools; // Array of pools
    mapping(uint256 => Proposal) public proposals; // Governance proposals

    // === ENUM TYPES ===

    // Simple enum
    enum Status {
        Pending,
        Active,
        Suspended,
        Closed
    }
    Status public currentStatus = Status.Pending;

    // Complex enum for DeFi
    enum TransactionType {
        Deposit,
        Withdrawal,
        Transfer,
        Swap,
        Stake,
        Unstake,
        Claim,
        Liquidation
    }

    enum RiskLevel {
        Low,
        Medium,
        High,
        Critical
    }
    enum UserTier {
        Basic,
        Premium,
        VIP,
        Institutional
    }

    // Using enums
    mapping(address => UserTier) public userTiers;
    mapping(uint256 => TransactionType) public transactionTypes;
    TransactionType[] public supportedTransactions;

    // ===== 2. VARIABLE TYPES =====

    // === STATE VARIABLES ===
    // Stored permanently on blockchain, cost gas to modify

    uint256 public stateVariable = 100; // Public state variable
    uint256 private privateState = 200; // Private state variable
    uint256 internal internalState = 300; // Internal state variable
    uint256 constant CONSTANT_VALUE = 1000; // Compile-time constant
    uint256 immutable IMMUTABLE_VALUE; // Set once in constructor

    // === GLOBAL VARIABLES (Built-in) ===

    function globalVariablesExample()
        public
        view
        returns (
            address sender, // msg.sender - who called the function
            uint256 value, // msg.value - ETH sent with transaction
            bytes memory data, // msg.data - transaction data
            bytes4 sig, // msg.sig - function signature
            uint256 gasLeft, // gasleft() - remaining gas
            uint256 timestamp, // block.timestamp - current block time
            uint256 blockNumber, // block.number - current block number
            address coinbase, // block.coinbase - current miner
            uint256 difficulty, // block.difficulty - current difficulty
            uint256 gasLimit, // block.gaslimit - current gas limit
            bytes32 blockHash, // blockhash(block.number-1) - previous block hash
            uint256 chainId, // block.chainid - current chain ID
            uint256 txOrigin // tx.origin - original transaction sender
        )
    {
        return (
            msg.sender,
            msg.value,
            msg.data,
            msg.sig,
            gasleft(),
            block.timestamp,
            block.number,
            block.coinbase,
            block.difficulty,
            block.gaslimit,
            blockhash(block.number - 1),
            block.chainid,
            tx.origin
        );
    }

    // ===== 3. FUNCTION TYPES =====

    // Constructor - runs once when contract is deployed
    constructor(uint256 _immutableValue) {
        IMMUTABLE_VALUE = _immutableValue;
        owner = msg.sender;
        treasury = payable(msg.sender);
        adminUser = User({
            userAddress: msg.sender,
            name: "Admin",
            balance: 0,
            isActive: true,
            joinDate: block.timestamp
        });
    }

    // === FUNCTION VISIBILITY ===

    // PUBLIC - can be called from anywhere
    function publicFunction() public pure returns (string memory) {
        return "Called from anywhere";
    }

    // EXTERNAL - can only be called from outside the contract
    function externalFunction() external pure returns (string memory) {
        return "Called from outside only";
    }

    // INTERNAL - can only be called from within this contract or derived contracts
    function internalFunction() internal pure returns (string memory) {
        return "Called from within contract";
    }

    // PRIVATE - can only be called from within this contract
    function privateFunction() private pure returns (string memory) {
        return "Called from this contract only";
    }

    // === FUNCTION STATE MUTABILITY ===

    // VIEW - reads state but doesn't modify it
    function viewFunction() public view returns (uint256) {
        return stateVariable; // Can read state
    }

    // PURE - doesn't read or modify state
    function pureFunction(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b; // Only uses parameters and local variables
    }

    // PAYABLE - can receive ETH
    function payableFunction() public payable {
        // Can receive ETH, msg.value available
        balances[msg.sender] += msg.value;
    }

    // DEFAULT (no keyword) - can modify state
    function defaultFunction() public {
        stateVariable = 42; // Can modify state
    }

    // === FUNCTION PARAMETERS ===

    // Memory parameters (for complex types)
    function memoryExample(
        string memory _name,
        uint256[] memory _numbers,
        User memory _user
    ) public pure returns (string memory) {
        return _name; // Parameters are copied to memory
    }

    // Calldata parameters (read-only, gas efficient)
    function calldataExample(
        string calldata _name,
        uint256[] calldata _numbers
    ) public pure returns (string memory) {
        return _name; // Parameters are read-only references
    }

    // Storage parameters (for internal functions)
    function storageExample() internal {
        User storage user = users[msg.sender]; // Reference to storage
        user.balance = 100; // Modifies storage directly
    }

    // === RETURN VALUES ===

    // Single return value
    function singleReturn() public pure returns (uint256) {
        return 42;
    }

    // Multiple return values
    function multipleReturns()
        public
        pure
        returns (uint256 number, string memory text, bool flag)
    {
        return (42, "Hello", true);
    }

    // Named return values
    function namedReturns() public pure returns (uint256 result, bool success) {
        result = 100;
        success = true;
        // No need for return statement
    }

    // ===== 4. CONTROL STRUCTURES =====

    // === CONDITIONALS ===

    function conditionalExample(
        uint256 _value
    ) public pure returns (string memory) {
        if (_value > 100) {
            return "High value";
        } else if (_value > 50) {
            return "Medium value";
        } else {
            return "Low value";
        }
    }

    // Ternary operator
    function ternaryExample(
        bool _condition
    ) public pure returns (string memory) {
        return _condition ? "True result" : "False result";
    }

    // === LOOPS ===

    // For loop
    function forLoopExample() public pure returns (uint256 sum) {
        for (uint256 i = 0; i < 10; i++) {
            sum += i;
        }
        return sum;
    }

    // While loop
    function whileLoopExample() public pure returns (uint256 result) {
        uint256 i = 0;
        while (i < 5) {
            result += i;
            i++;
        }
        return result;
    }

    // Do-while loop
    function doWhileExample() public pure returns (uint256 result) {
        uint256 i = 0;
        do {
            result += i;
            i++;
        } while (i < 3);
        return result;
    }

    // Loop with break and continue
    function breakContinueExample() public pure returns (uint256 sum) {
        for (uint256 i = 0; i < 20; i++) {
            if (i < 5) {
                continue; // Skip to next iteration
            }
            if (i > 15) {
                break; // Exit loop
            }
            sum += i;
        }
        return sum;
    }

    // ===== 5. ADVANCED FEATURES =====

    // === EVENTS ===

    // Simple event
    event Transfer(address indexed from, address indexed to, uint256 value);

    // Complex event with multiple parameters
    event UserRegistered(
        address indexed user,
        string name,
        uint256 tier,
        uint256 timestamp
    );

    // Event with array data
    event BatchTransfer(
        address indexed from,
        address[] to,
        uint256[] amounts,
        bytes32 batchId
    );

    // Emitting events
    function emitEvents() public {
        emit Transfer(address(0), msg.sender, 1000);
        emit UserRegistered(msg.sender, "New User", 1, block.timestamp);
    }

    // === CUSTOM ERRORS ===

    // Simple error
    error Unauthorized();

    // Error with parameters
    error InsufficientBalance(uint256 available, uint256 required);

    // Complex error
    error InvalidOperation(
        address user,
        string operation,
        uint256 timestamp,
        bytes32 reason
    );

    // Using errors
    function errorExample() public view {
        if (msg.sender != owner) {
            revert Unauthorized();
        }
        if (balances[msg.sender] < 100) {
            revert InsufficientBalance(balances[msg.sender], 100);
        }
    }

    // === MODIFIERS ===

    // Simple modifier
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _; // Execute function
    }

    // Modifier with parameters
    modifier hasMinBalance(uint256 _minBalance) {
        require(balances[msg.sender] >= _minBalance, "Insufficient balance");
        _;
    }

    // Modifier with pre and post conditions
    modifier validTransaction() {
        require(msg.value > 0, "No ETH sent");
        uint256 balanceBefore = address(this).balance - msg.value;
        _;
        assert(address(this).balance > balanceBefore);
    }

    // Using modifiers
    function restrictedFunction() public onlyOwner hasMinBalance(50) {
        // Function logic here
        stateVariable = 999;
    }

    // === INHERITANCE CONCEPTS ===

    // Virtual function (can be overridden)
    function virtualFunction() public pure virtual returns (string memory) {
        return "Base implementation";
    }

    // === REAL-WORLD EXAMPLES ===

    // ERC20-style transfer function
    function transfer(address _to, uint256 _amount) public returns (bool) {
        require(_to != address(0), "Invalid recipient");
        require(balances[msg.sender] >= _amount, "Insufficient balance");

        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        emit Transfer(msg.sender, _to, _amount);
        return true;
    }

    // Governance voting function
    function vote(uint256 _proposalId, bool _support) public {
        require(_proposalId < proposals.length, "Invalid proposal");
        require(!proposals[_proposalId].hasVoted[msg.sender], "Already voted");

        proposals[_proposalId].hasVoted[msg.sender] = true;
        proposals[_proposalId].voters.push(msg.sender);

        if (_support) {
            proposals[_proposalId].forVotes++;
        } else {
            proposals[_proposalId].againstVotes++;
        }
    }

    // Staking function with time locks
    function stake(uint256 _amount) public payable {
        require(_amount > 0, "Amount must be positive");
        require(msg.value == _amount, "ETH amount mismatch");

        balances[msg.sender] += _amount;
        users[msg.sender].balance += _amount;
        users[msg.sender].isActive = true;

        emit Transfer(address(0), msg.sender, _amount);
    }

    // Batch operation example
    function batchTransfer(
        address[] calldata _recipients,
        uint256[] calldata _amounts
    ) public returns (bool) {
        require(_recipients.length == _amounts.length, "Array length mismatch");

        uint256 totalAmount = 0;
        for (uint256 i = 0; i < _amounts.length; i++) {
            totalAmount += _amounts[i];
        }

        require(balances[msg.sender] >= totalAmount, "Insufficient balance");

        for (uint256 i = 0; i < _recipients.length; i++) {
            balances[msg.sender] -= _amounts[i];
            balances[_recipients[i]] += _amounts[i];
            emit Transfer(msg.sender, _recipients[i], _amounts[i]);
        }

        return true;
    }

    // === HELPER FUNCTIONS ===

    // Math operations
    function mathOperations(
        uint256 a,
        uint256 b
    )
        public
        pure
        returns (
            uint256 addition,
            uint256 subtraction,
            uint256 multiplication,
            uint256 division,
            uint256 modulo,
            uint256 power
        )
    {
        addition = a + b;
        subtraction = a - b; // Will revert if b > a (underflow protection)
        multiplication = a * b;
        division = a / b; // Will revert if b == 0
        modulo = a % b;
        power = a ** b;

        return (addition, subtraction, multiplication, division, modulo, power);
    }

    // String operations
    function stringOperations(
        string memory _str1,
        string memory _str2
    ) public pure returns (string memory concatenated, bool areEqual) {
        concatenated = string(abi.encodePacked(_str1, _str2));
        areEqual = keccak256(bytes(_str1)) == keccak256(bytes(_str2));

        return (concatenated, areEqual);
    }

    // Array operations
    function arrayOperations() public {
        // Add to array
        allNumbers.push(42);
        allUsers.push(msg.sender);

        // Get array length
        uint256 numbersLength = allNumbers.length;
        uint256 usersLength = allUsers.length;

        // Access array element
        if (allNumbers.length > 0) {
            uint256 firstNumber = allNumbers[0];
            uint256 lastNumber = allNumbers[allNumbers.length - 1];
        }

        // Remove from array (pop removes last element)
        if (allNumbers.length > 0) {
            allNumbers.pop();
        }
    }

    // Receive function - handles plain ETH transfers
    receive() external payable {
        balances[msg.sender] += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }

    // Fallback function - handles non-existent function calls
    fallback() external payable {
        // Handle unknown function calls
        revert("Function not found");
    }
}

/**
 * USAGE GUIDE:
 *
 * This contract demonstrates every major Solidity syntax element with:
 * 1. Clear explanations and comments
 * 2. Real-world usage examples
 * 3. Best practices and patterns
 * 4. Common pitfalls and how to avoid them
 *
 * NEXT STEPS:
 * 1. Deploy this contract on a testnet
 * 2. Interact with each function to see how they work
 * 3. Modify examples to experiment with syntax
 * 4. Use these patterns in your own contracts
 *
 * This contract serves as a comprehensive reference for Solidity development
 * and provides the foundation for building complex DeFi protocols.
 */

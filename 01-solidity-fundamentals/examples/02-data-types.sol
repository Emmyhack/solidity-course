// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Data Types Demo
 * @dev Comprehensive overview of Solidity data types
 *
 * This contract demonstrates:
 * - All major Solidity data types
 * - Memory vs Storage
 * - Type conversions
 * - Default values
 */

contract DataTypesDemo {
    // ======================
    // VALUE TYPES
    // ======================

    // Boolean
    bool public isActive = true;

    // Integers (unsigned)
    uint8 public smallNumber = 255; // 0 to 255
    uint256 public largeNumber = 1000000; // 0 to 2^256-1
    uint public defaultUint = 42; // uint = uint256

    // Integers (signed)
    int8 public smallSigned = -128; // -128 to 127
    int256 public largeSigned = -1000000; // -2^255 to 2^255-1

    // Address types
    address public owner;
    address payable public recipient;

    // Bytes (fixed-size)
    bytes1 public singleByte = 0x42;
    bytes32 public hash =
        0x123456789abcdef123456789abcdef123456789abcdef123456789abcdef12;

    // ======================
    // REFERENCE TYPES
    // ======================

    // Dynamic arrays
    uint[] public numbers;
    address[] public users;

    // Fixed-size arrays
    uint[5] public fixedNumbers;

    // String (dynamic bytes)
    string public name = "Solidity Course";

    // Mapping (key-value store)
    mapping(address => uint256) public balances;
    mapping(address => bool) public whitelist;

    // Struct (custom type)
    struct Person {
        string name;
        uint256 age;
        bool isActive;
    }

    Person public founder;
    mapping(uint256 => Person) public people;

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor() {
        owner = msg.sender;
        recipient = payable(msg.sender);

        // Initialize arrays
        numbers.push(1);
        numbers.push(2);
        numbers.push(3);

        fixedNumbers[0] = 10;
        fixedNumbers[1] = 20;

        // Initialize struct
        founder = Person("Satoshi", 45, true);

        // Initialize mappings
        balances[msg.sender] = 1000;
        whitelist[msg.sender] = true;
    }

    // ======================
    // FUNCTIONS
    // ======================

    /**
     * @dev Demonstrates working with arrays
     */
    function arrayOperations() public {
        numbers.push(4); // Add element
        numbers.pop(); // Remove last element
        uint len = numbers.length; // Get length

        // You can access but not modify in view functions
        // uint first = numbers[0];
    }

    /**
     * @dev Demonstrates mapping operations
     */
    function mappingOperations(address user, uint256 amount) public {
        balances[user] = amount; // Set value
        bool isWhitelisted = whitelist[user]; // Get value (default: false)

        // Note: You cannot iterate over mappings
        // Use arrays if you need to iterate
    }

    /**
     * @dev Demonstrates struct operations
     */
    function createPerson(
        uint256 id,
        string memory _name,
        uint256 _age
    ) public {
        people[id] = Person(_name, _age, true);

        // Alternative syntax:
        // people[id] = Person({
        //     name: _name,
        //     age: _age,
        //     isActive: true
        // });
    }

    /**
     * @dev Demonstrates type conversions
     */
    function typeConversions() public pure returns (uint256, address, bytes32) {
        // Number conversions
        uint8 small = 100;
        uint256 large = uint256(small); // Safe upcast

        // Address conversions
        address addr = 0x742d35Cc6634C0532925a3b8D8B4f5b9C0e4a8e1;
        uint256 addrAsNumber = uint256(uint160(addr));

        // Bytes conversions
        bytes memory data = "Hello";
        bytes32 fixedData = bytes32(data);

        return (large, addr, fixedData);
    }

    /**
     * @dev Demonstrates memory vs storage
     */
    function memoryVsStorage() public {
        // Storage: permanent, expensive
        founder.age = 46; // Modifies blockchain state

        // Memory: temporary, cheaper
        Person memory tempPerson = Person("Temp", 25, false);
        tempPerson.age = 26; // Only modifies local copy

        // To save to storage, assign back:
        people[999] = tempPerson;
    }

    // ======================
    // VIEW FUNCTIONS (READ-ONLY)
    // ======================

    function getNumbers() public view returns (uint[] memory) {
        return numbers;
    }

    function getBalance(address user) public view returns (uint256) {
        return balances[user];
    }

    function getPerson(uint256 id) public view returns (Person memory) {
        return people[id];
    }

    // ======================
    // DEFAULT VALUES
    // ======================

    function getDefaultValues()
        public
        pure
        returns (
            bool, // false
            uint256, // 0
            int256, // 0
            address, // 0x0000000000000000000000000000000000000000
            bytes32 // 0x0000000000000000000000000000000000000000000000000000000000000000
        )
    {
        bool defaultBool;
        uint256 defaultUint;
        int256 defaultInt;
        address defaultAddress;
        bytes32 defaultBytes;

        return (
            defaultBool,
            defaultUint,
            defaultInt,
            defaultAddress,
            defaultBytes
        );
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. VALUE TYPES: Stored directly, copied when assigned
 *    - bool, uint, int, address, bytes1-32
 *
 * 2. REFERENCE TYPES: Stored by reference, share data
 *    - arrays, strings, structs, mappings
 *
 * 3. MEMORY vs STORAGE:
 *    - Storage: Permanent, expensive, state variables
 *    - Memory: Temporary, cheaper, function parameters
 *
 * 4. MAPPINGS: Like hash tables, cannot iterate
 *
 * 5. ARRAYS: Dynamic (push/pop) or fixed-size
 *
 * 6. STRUCTS: Custom types, group related data
 *
 * 🚀 TRY THIS:
 * 1. Deploy and explore each function
 * 2. Try different data type combinations
 * 3. Notice gas costs for storage vs memory operations
 */

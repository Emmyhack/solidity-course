// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Functions & Control Flow Demo
 * @dev Comprehensive guide to Solidity functions and control structures
 *
 * This contract demonstrates:
 * - Function types and visibility
 * - Parameters and return values
 * - Control flow statements
 * - Error handling with require
 */

contract FunctionsAndControlFlow {
    // State variables for examples
    uint256 public counter = 0;
    mapping(address => uint256) public balances;
    address public owner;
    bool public paused = false;

    // Events
    event CounterIncremented(uint256 newValue);
    event Transfer(address from, address to, uint256 amount);

    constructor() {
        owner = msg.sender;
        balances[msg.sender] = 1000;
    }

    // ======================
    // FUNCTION VISIBILITY
    // ======================

    /**
     * @dev PUBLIC: Can be called by anyone, internally or externally
     */
    function publicFunction() public pure returns (string memory) {
        return "This is public";
    }

    /**
     * @dev EXTERNAL: Can only be called from outside the contract
     * More gas efficient than public for external calls
     */
    function externalFunction() external pure returns (string memory) {
        return "This is external";
    }

    /**
     * @dev INTERNAL: Can be called within this contract and derived contracts
     */
    function internalFunction() internal pure returns (string memory) {
        return "This is internal";
    }

    /**
     * @dev PRIVATE: Can only be called within this contract
     */
    function privateFunction() private pure returns (string memory) {
        return "This is private";
    }

    /**
     * @dev Function that calls internal and private functions
     */
    function callInternalFunctions()
        public
        view
        returns (string memory, string memory)
    {
        return (internalFunction(), privateFunction());
    }

    // ======================
    // FUNCTION MODIFIERS
    // ======================

    /**
     * @dev VIEW: Reads state but doesn't modify it (free to call)
     */
    function viewFunction() public view returns (uint256) {
        return counter;
    }

    /**
     * @dev PURE: Doesn't read or modify state (free to call)
     */
    function pureFunction(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev PAYABLE: Can receive Ether
     */
    function payableFunction() public payable {
        balances[msg.sender] += msg.value;
    }

    // ======================
    // PARAMETERS & RETURNS
    // ======================

    /**
     * @dev Function with multiple parameters
     */
    function multipleParameters(
        uint256 _number,
        string memory _text,
        bool _flag
    ) public pure returns (bool) {
        // Use parameters in function logic
        if (_number > 0 && _flag) {
            return bytes(_text).length > 0;
        }
        return false;
    }

    /**
     * @dev Function with multiple return values
     */
    function multipleReturns()
        public
        view
        returns (
            uint256 currentCounter,
            address contractOwner,
            uint256 contractBalance
        )
    {
        return (counter, owner, address(this).balance);
    }

    /**
     * @dev Named return values
     */
    function namedReturns(
        uint256 _input
    ) public pure returns (uint256 doubled, uint256 tripled, bool isEven) {
        doubled = _input * 2;
        tripled = _input * 3;
        isEven = _input % 2 == 0;
        // No need for explicit return statement
    }

    // ======================
    // CONTROL FLOW: IF/ELSE
    // ======================

    /**
     * @dev Demonstrates if/else statements
     */
    function checkNumber(uint256 _number) public pure returns (string memory) {
        if (_number == 0) {
            return "Number is zero";
        } else if (_number < 10) {
            return "Number is small";
        } else if (_number < 100) {
            return "Number is medium";
        } else {
            return "Number is large";
        }
    }

    /**
     * @dev Ternary operator (conditional expression)
     */
    function ternaryExample(
        uint256 _number
    ) public pure returns (string memory) {
        return _number % 2 == 0 ? "Even" : "Odd";
    }

    // ======================
    // CONTROL FLOW: LOOPS
    // ======================

    /**
     * @dev FOR loop example
     * WARNING: Be careful with loops in smart contracts due to gas limits!
     */
    function forLoopExample(uint256 _limit) public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 1; i <= _limit; i++) {
            sum += i;
        }

        return sum;
    }

    /**
     * @dev WHILE loop example
     */
    function whileLoopExample(uint256 _number) public pure returns (uint256) {
        uint256 result = 1;
        uint256 counter = _number;

        while (counter > 0) {
            result *= counter;
            counter--;
        }

        return result; // Returns factorial
    }

    /**
     * @dev Loop with break and continue
     */
    function loopWithBreakContinue() public pure returns (uint256) {
        uint256 sum = 0;

        for (uint256 i = 1; i <= 20; i++) {
            if (i % 2 == 0) {
                continue; // Skip even numbers
            }

            if (i > 15) {
                break; // Stop when i > 15
            }

            sum += i;
        }

        return sum; // Sum of odd numbers 1, 3, 5, 7, 9, 11, 13, 15
    }

    // ======================
    // ERROR HANDLING
    // ======================

    /**
     * @dev REQUIRE: Most common way to handle errors
     */
    function requireExample(uint256 _amount) public {
        require(_amount > 0, "Amount must be greater than zero");
        require(_amount <= 1000, "Amount too large");
        require(!paused, "Contract is paused");

        counter += _amount;
        emit CounterIncremented(counter);
    }

    /**
     * @dev Transfer function with multiple require statements
     */
    function transfer(address _to, uint256 _amount) public {
        require(_to != address(0), "Cannot transfer to zero address");
        require(_amount > 0, "Amount must be positive");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        require(_to != msg.sender, "Cannot transfer to yourself");

        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        emit Transfer(msg.sender, _to, _amount);
    }

    /**
     * @dev Only owner modifier pattern
     */
    function onlyOwnerExample() public {
        require(msg.sender == owner, "Only owner can call this function");
        paused = !paused;
    }

    // ======================
    // COMPLEX EXAMPLES
    // ======================

    /**
     * @dev Complex function combining multiple concepts
     */
    function complexFunction(
        address[] memory _recipients,
        uint256[] memory _amounts
    ) public returns (bool success) {
        // Input validation
        require(
            _recipients.length == _amounts.length,
            "Arrays length mismatch"
        );
        require(_recipients.length > 0, "No recipients provided");
        require(_recipients.length <= 10, "Too many recipients");

        uint256 totalAmount = 0;

        // Calculate total amount needed
        for (uint256 i = 0; i < _amounts.length; i++) {
            require(_amounts[i] > 0, "Amount must be positive");
            totalAmount += _amounts[i];
        }

        // Check if sender has enough balance
        require(balances[msg.sender] >= totalAmount, "Insufficient balance");

        // Execute transfers
        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            uint256 amount = _amounts[i];

            // Skip invalid recipients but don't fail
            if (recipient == address(0) || recipient == msg.sender) {
                continue;
            }

            balances[msg.sender] -= amount;
            balances[recipient] += amount;

            emit Transfer(msg.sender, recipient, amount);
        }

        return true;
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    function getContractInfo()
        public
        view
        returns (
            uint256 currentCounter,
            address contractOwner,
            bool isPaused,
            uint256 myBalance
        )
    {
        return (counter, owner, paused, balances[msg.sender]);
    }

    // Function to receive Ether
    receive() external payable {
        balances[msg.sender] += msg.value;
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. VISIBILITY:
 *    - public: Anyone can call
 *    - external: Only external calls (gas efficient)
 *    - internal: This contract + inherited contracts
 *    - private: Only this contract
 *
 * 2. STATE MUTABILITY:
 *    - pure: No state access (cheapest)
 *    - view: Read state only (free)
 *    - payable: Can receive Ether
 *    - (default): Can modify state
 *
 * 3. CONTROL FLOW:
 *    - if/else: Conditional execution
 *    - for/while: Loops (watch gas limits!)
 *    - break/continue: Loop control
 *
 * 4. ERROR HANDLING:
 *    - require(): Input validation + error messages
 *    - Always validate inputs first
 *    - Fail fast with clear error messages
 *
 * 🚀 TRY THIS:
 * 1. Test different function types
 * 2. Try calling external functions internally (will fail)
 * 3. Experiment with loops and gas limits
 * 4. Test require statements with invalid inputs
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./IExternalContract.sol";

/**
 * @title Error Handling Mechanisms
 * @dev Comprehensive guide to error handling in Solidity
 *
 * This contract demonstrates:
 * - require(), assert(), and revert() usage patterns
 * - Custom error types for gas optimization
 * - Try-catch blocks for external calls
 * - Error propagation strategies
 * - Graceful failure handling
 * - Error logging and debugging techniques
 */

contract ErrorHandlingMechanisms {
    // ======================
    // CUSTOM ERROR TYPES
    // ======================

    // Custom errors are more gas-efficient than strings
    error InsufficientBalance(uint256 requested, uint256 available);
    error UnauthorizedAccess(address caller, address required);
    error InvalidAddress(address provided);
    error TransferFailed(address to, uint256 amount);
    error ContractPaused();
    error InvalidAmount(uint256 amount);
    error DeadlineExpired(uint256 deadline, uint256 currentTime);
    error ArrayIndexOutOfBounds(uint256 index, uint256 length);
    error DivisionByZero();
    error InvalidState(string expected, string actual);

    // ======================
    // STATE VARIABLES
    // ======================

    mapping(address => uint256) public balances;
    mapping(address => bool) public authorized;

    address public owner;
    bool public paused = false;
    uint256 public totalSupply;

    // For demonstrating external call handling
    address[] public externalContracts;

    // Events for error tracking
    event ErrorOccurred(
        string errorType,
        address indexed user,
        string description
    );
    event RecoveryExecuted(string action, address indexed user);
    event FallbackExecuted(string reason, bytes data);

    // ======================
    // MODIFIERS WITH ERROR HANDLING
    // ======================

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert UnauthorizedAccess(msg.sender, owner);
        }
        _;
    }

    modifier onlyAuthorized() {
        if (!authorized[msg.sender] && msg.sender != owner) {
            revert UnauthorizedAccess(msg.sender, address(0));
        }
        _;
    }

    modifier whenNotPaused() {
        if (paused) {
            revert ContractPaused();
        }
        _;
    }

    modifier validAddress(address _addr) {
        if (_addr == address(0)) {
            revert InvalidAddress(_addr);
        }
        _;
    }

    modifier nonZeroAmount(uint256 _amount) {
        if (_amount == 0) {
            revert InvalidAmount(_amount);
        }
        _;
    }

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor() {
        owner = msg.sender;
        authorized[msg.sender] = true;
        balances[msg.sender] = 1000000;
        totalSupply = 1000000;
    }

    // ======================
    // REQUIRE() EXAMPLES
    // ======================

    /**
     * @dev Transfer tokens with require() validation
     * require() is used for input validation and conditions that could fail
     */
    function transferWithRequire(address _to, uint256 _amount) public {
        require(_to != address(0), "Cannot transfer to zero address");
        require(_amount > 0, "Amount must be positive");
        require(balances[msg.sender] >= _amount, "Insufficient balance");
        require(!paused, "Contract is paused");

        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }

    /**
     * @dev Batch transfer with detailed error messages
     */
    function batchTransferWithRequire(
        address[] memory _recipients,
        uint256[] memory _amounts
    ) public {
        require(
            _recipients.length == _amounts.length,
            "Arrays length mismatch"
        );
        require(_recipients.length > 0, "No recipients provided");
        require(_recipients.length <= 100, "Too many recipients (max 100)");

        uint256 totalAmount = 0;

        // First pass: validate all inputs and calculate total
        for (uint256 i = 0; i < _amounts.length; i++) {
            require(
                _recipients[i] != address(0),
                "Recipient cannot be zero address"
            );
            require(_amounts[i] > 0, "Amount must be positive");
            totalAmount += _amounts[i];
        }

        require(
            balances[msg.sender] >= totalAmount,
            "Insufficient balance for batch transfer"
        );

        // Second pass: execute transfers
        for (uint256 i = 0; i < _recipients.length; i++) {
            balances[msg.sender] -= _amounts[i];
            balances[_recipients[i]] += _amounts[i];
        }
    }

    // ======================
    // REVERT() WITH CUSTOM ERRORS
    // ======================

    /**
     * @dev Transfer tokens with custom errors (gas-efficient)
     */
    function transferWithCustomErrors(address _to, uint256 _amount) public {
        if (_to == address(0)) {
            revert InvalidAddress(_to);
        }

        if (_amount == 0) {
            revert InvalidAmount(_amount);
        }

        if (paused) {
            revert ContractPaused();
        }

        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance(_amount, balances[msg.sender]);
        }

        balances[msg.sender] -= _amount;
        balances[_to] += _amount;
    }

    /**
     * @dev Withdraw with deadline check
     */
    function withdrawWithDeadline(uint256 _amount, uint256 _deadline) public {
        if (block.timestamp > _deadline) {
            revert DeadlineExpired(_deadline, block.timestamp);
        }

        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance(_amount, balances[msg.sender]);
        }

        balances[msg.sender] -= _amount;
        payable(msg.sender).transfer(_amount);
    }

    // ======================
    // ASSERT() EXAMPLES
    // ======================

    /**
     * @dev Assert is used for internal consistency checks
     * Should never fail if code is correct
     */
    function transferWithAssert(address _to, uint256 _amount) public {
        // Use require for input validation
        if (_to == address(0)) {
            revert InvalidAddress(_to);
        }
        if (balances[msg.sender] < _amount) {
            revert InsufficientBalance(_amount, balances[msg.sender]);
        }

        uint256 senderBalanceBefore = balances[msg.sender];
        uint256 recipientBalanceBefore = balances[_to];
        uint256 totalBefore = totalSupply;

        // Execute transfer
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        // Assert internal consistency (should never fail)
        assert(balances[msg.sender] == senderBalanceBefore - _amount);
        assert(balances[_to] == recipientBalanceBefore + _amount);
        assert(totalSupply == totalBefore); // Total supply unchanged
    }

    /**
     * @dev Mathematical operations with assert
     */
    function safeDivision(
        uint256 _numerator,
        uint256 _denominator
    ) public pure returns (uint256) {
        if (_denominator == 0) {
            revert DivisionByZero();
        }

        uint256 result = _numerator / _denominator;

        // Assert mathematical property
        assert(
            _numerator == result * _denominator + (_numerator % _denominator)
        );

        return result;
    }

    // ======================
    // TRY-CATCH EXAMPLES
    // ======================

    /**
     * @dev Call external contract with try-catch
     */
    function callExternalContract(
        address _contract,
        uint256 _value
    ) public returns (bool success, string memory errorMessage) {
        try IExternalContract(_contract).riskyFunction(_value) returns (
            bool result
        ) {
            return (result, "");
        } catch Error(string memory reason) {
            // Catch revert with error message
            emit ErrorOccurred("External call failed", msg.sender, reason);
            return (false, reason);
        } catch Panic(uint errorCode) {
            // Catch assert failure or panic
            emit ErrorOccurred(
                "External call panicked",
                msg.sender,
                string(abi.encodePacked("Code: ", errorCode))
            );
            return (false, "Panic occurred");
        } catch (bytes memory /* lowLevelData */) {
            // Catch other low-level failures
            emit ErrorOccurred(
                "External call failed (low-level)",
                msg.sender,
                "Unknown error"
            );
            return (false, "Low-level error");
        }
    }

    /**
     * @dev Batch external calls with error handling
     */
    function batchExternalCalls(
        address[] memory _contracts,
        uint256[] memory _values
    ) public returns (bool[] memory results, string[] memory errors) {
        require(_contracts.length == _values.length, "Arrays length mismatch");

        results = new bool[](_contracts.length);
        errors = new string[](_contracts.length);

        for (uint256 i = 0; i < _contracts.length; i++) {
            try
                IExternalContract(_contracts[i]).riskyFunction(_values[i])
            returns (bool result) {
                results[i] = result;
                errors[i] = "";
            } catch Error(string memory reason) {
                results[i] = false;
                errors[i] = reason;
            } catch {
                results[i] = false;
                errors[i] = "Unknown error";
            }
        }
    }

    // ======================
    // GRACEFUL FAILURE PATTERNS
    // ======================

    /**
     * @dev Transfer with fallback mechanism
     */
    function transferWithFallback(
        address _to,
        uint256 _amount
    ) public returns (bool success) {
        try this.transferWithCustomErrors(_to, _amount) {
            return true;
        } catch Error(string memory reason) {
            // Log error and continue
            emit ErrorOccurred("Transfer failed", msg.sender, reason);

            // Attempt recovery mechanism
            if (balances[msg.sender] >= _amount / 2) {
                try this.transferWithCustomErrors(_to, _amount / 2) {
                    emit RecoveryExecuted("Partial transfer", msg.sender);
                    return true;
                } catch {
                    emit RecoveryExecuted("Recovery failed", msg.sender);
                    return false;
                }
            }
            return false;
        }
    }

    /**
     * @dev Safe array access with bounds checking
     */
    function safeArrayAccess(
        uint256[] memory _array,
        uint256 _index
    ) public pure returns (uint256 value, bool success) {
        if (_index >= _array.length) {
            return (0, false);
        }
        return (_array[_index], true);
    }

    /**
     * @dev Safe array access with custom error
     */
    function safeArrayAccessWithError(
        uint256[] memory _array,
        uint256 _index
    ) public pure returns (uint256) {
        if (_index >= _array.length) {
            revert ArrayIndexOutOfBounds(_index, _array.length);
        }
        return _array[_index];
    }

    // ======================
    // ERROR RECOVERY MECHANISMS
    // ======================

    /**
     * @dev Emergency withdrawal with error handling
     */
    function emergencyWithdraw() public {
        uint256 balance = balances[msg.sender];

        if (balance == 0) {
            revert InsufficientBalance(1, 0);
        }

        // Clear balance first (checks-effects-interactions)
        balances[msg.sender] = 0;

        // Attempt withdrawal with error handling
        try this.sendEther(msg.sender, balance) {
            emit RecoveryExecuted(
                "Emergency withdrawal successful",
                msg.sender
            );
        } catch {
            // Restore balance if transfer fails
            balances[msg.sender] = balance;
            emit ErrorOccurred(
                "Emergency withdrawal failed",
                msg.sender,
                "Transfer failed"
            );
            revert TransferFailed(msg.sender, balance);
        }
    }

    /**
     * @dev Helper function for ether transfer
     */
    function sendEther(address _to, uint256 _amount) external {
        require(msg.sender == address(this), "Only self-call allowed");
        payable(_to).transfer(_amount);
    }

    // ======================
    // STATE VALIDATION PATTERNS
    // ======================

    enum ContractState {
        Inactive,
        Active,
        Paused,
        Emergency
    }
    ContractState public contractState = ContractState.Active;

    /**
     * @dev State-dependent function execution
     */
    function stateAwareFunction(uint256 _value) public {
        if (contractState == ContractState.Inactive) {
            revert InvalidState("Active", "Inactive");
        }

        if (contractState == ContractState.Paused) {
            revert ContractPaused();
        }

        if (contractState == ContractState.Emergency) {
            // Only allow emergency functions
            revert InvalidState("Non-emergency", "Emergency");
        }

        // Normal function logic
        balances[msg.sender] += _value;
    }

    // ======================
    // DEBUGGING HELPERS
    // ======================

    /**
     * @dev Function with comprehensive error reporting
     */
    function debugTransfer(
        address _to,
        uint256 _amount
    ) public returns (string memory) {
        if (_to == address(0)) {
            return "Error: Invalid recipient address";
        }

        if (_amount == 0) {
            return "Error: Amount cannot be zero";
        }

        if (balances[msg.sender] < _amount) {
            return
                string(
                    abi.encodePacked(
                        "Error: Insufficient balance. Required: ",
                        _amount,
                        ", Available: ",
                        balances[msg.sender]
                    )
                );
        }

        if (paused) {
            return "Error: Contract is paused";
        }

        // Execute transfer
        balances[msg.sender] -= _amount;
        balances[_to] += _amount;

        return "Success: Transfer completed";
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }

    function setAuthorized(address _user, bool _authorized) external onlyOwner {
        authorized[_user] = _authorized;
    }

    function setContractState(ContractState _state) external onlyOwner {
        contractState = _state;
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    function getBalance(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function getContractInfo()
        external
        view
        returns (bool isPaused, ContractState state, uint256 supply)
    {
        return (paused, contractState, totalSupply);
    }

    // Function to receive Ether
    receive() external payable {}

    // Fallback function
    fallback() external payable {
        emit FallbackExecuted("Fallback called", msg.data);
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. ERROR HANDLING MECHANISMS:
 *    - require(): Input validation, external conditions
 *    - assert(): Internal consistency, should never fail
 *    - revert(): Custom errors, gas-efficient failures
 *    - try-catch: External call error handling
 *
 * 2. CUSTOM ERRORS:
 *    - More gas-efficient than string messages
 *    - Can include parameters for debugging
 *    - Better for automated error handling
 *    - Improved developer experience
 *
 * 3. ERROR RECOVERY:
 *    - Graceful degradation patterns
 *    - Fallback mechanisms
 *    - State restoration on failure
 *    - Emergency procedures
 *
 * 4. VALIDATION STRATEGIES:
 *    - Input validation (require)
 *    - State validation (modifiers)
 *    - Output validation (assert)
 *    - External call validation (try-catch)
 *
 * 5. BEST PRACTICES:
 *    - Fail fast with clear error messages
 *    - Use appropriate error mechanism
 *    - Implement recovery when possible
 *    - Log errors for debugging
 *    - Validate early and often
 *
 * ⚠️ SECURITY NOTES:
 * - Don't expose sensitive information in errors
 * - Validate all external inputs
 * - Handle external call failures gracefully
 * - Use assert only for invariants
 * - Consider gas costs of error handling
 *
 * 🚀 TRY THIS:
 * 1. Test each error mechanism
 * 2. Compare gas costs of different approaches
 * 3. Implement your own error recovery
 * 4. Build comprehensive validation system
 */

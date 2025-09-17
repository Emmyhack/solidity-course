// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Counter
 * @dev Simple counter contract for demonstrating Foundry basics
 * @notice This is a basic example contract for the Foundry tutorial
 */
contract Counter {
    // State variables
    uint256 private _count;
    address public owner;
    bool public paused;

    // Events
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

    // Errors
    error ContractPaused();
    error OnlyOwner();
    error CannotDecrementBelowZero();
    error ZeroAddress();

    // Modifiers
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /**
     * @dev Contract constructor
     * @param _initialCount Initial count value
     */
    constructor(uint256 _initialCount) {
        _count = _initialCount;
        owner = msg.sender;
        paused = false;
    }

    /**
     * @dev Increment the counter by 1
     * @notice Can only be called when contract is not paused
     */
    function increment() external whenNotPaused {
        _count++;
        emit CountIncremented(_count, msg.sender);
    }

    /**
     * @dev Decrement the counter by 1
     * @notice Can only be called when contract is not paused and count > 0
     */
    function decrement() external whenNotPaused {
        if (_count == 0) revert CannotDecrementBelowZero();
        _count--;
        emit CountDecremented(_count, msg.sender);
    }

    /**
     * @dev Increment the counter by a specified amount
     * @param _amount Amount to increment by
     */
    function incrementBy(uint256 _amount) external whenNotPaused {
        _count += _amount;
        emit CountIncremented(_count, msg.sender);
    }

    /**
     * @dev Decrement the counter by a specified amount
     * @param _amount Amount to decrement by
     */
    function decrementBy(uint256 _amount) external whenNotPaused {
        if (_count < _amount) revert CannotDecrementBelowZero();
        _count -= _amount;
        emit CountDecremented(_count, msg.sender);
    }

    /**
     * @dev Reset counter to zero (only owner)
     */
    function reset() external onlyOwner {
        _count = 0;
        emit CountReset(msg.sender);
    }

    /**
     * @dev Set counter to specific value (only owner)
     * @param _newCount New count value
     */
    function setCount(uint256 _newCount) external onlyOwner {
        _count = _newCount;
        emit CountIncremented(_count, msg.sender);
    }

    /**
     * @dev Toggle pause state (only owner)
     */
    function togglePause() external onlyOwner {
        paused = !paused;
        emit PauseToggled(paused, msg.sender);
    }

    /**
     * @dev Transfer ownership (only current owner)
     * @param _newOwner Address of the new owner
     */
    function transferOwnership(address _newOwner) external onlyOwner {
        if (_newOwner == address(0)) revert ZeroAddress();

        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @dev Get current count value
     * @return Current count
     */
    function count() external view returns (uint256) {
        return _count;
    }

    /**
     * @dev Get contract information
     * @return currentCount Current count value
     * @return contractOwner Owner address
     * @return isPaused Pause state
     */
    function getInfo()
        external
        view
        returns (uint256 currentCount, address contractOwner, bool isPaused)
    {
        return (_count, owner, paused);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Hello World Contract
 * @dev Your very first smart contract!
 *
 * This contract demonstrates:
 * - Basic contract structure
 * - State variables
 * - Public functions
 * - String manipulation
 * - Events
 */

contract HelloWorld {
    // State variable - stored permanently on blockchain
    string public message;

    // Owner of the contract
    address public owner;

    // Event - logs when message is updated
    event MessageUpdated(string newMessage, address updatedBy);

    /**
     * @dev Constructor runs once when contract is deployed
     * @param _initialMessage The starting message
     */
    constructor(string memory _initialMessage) {
        message = _initialMessage;
        owner = msg.sender; // Person who deploys the contract
    }

    /**
     * @dev Updates the stored message
     * @param _newMessage The new message to store
     */
    function updateMessage(string memory _newMessage) public {
        message = _newMessage;
        emit MessageUpdated(_newMessage, msg.sender);
    }

    /**
     * @dev Returns the current message
     * @return The stored message
     */
    function getMessage() public view returns (string memory) {
        return message;
    }

    /**
     * @dev Returns contract info
     * @return Current message and owner address
     */
    function getInfo() public view returns (string memory, address) {
        return (message, owner);
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. SPDX License: Required at top of every contract
 * 2. Pragma: Specifies Solidity compiler version
 * 3. Contract: Like a class in other programming languages
 * 4. State Variables: Stored permanently on blockchain (costs gas)
 * 5. Constructor: Runs once during deployment
 * 6. Functions: Can modify state (costs gas) or just read (free)
 * 7. Events: Cheap way to log important changes
 * 8. msg.sender: Built-in variable for transaction sender
 *
 * 🚀 TRY THIS:
 * 1. Deploy this contract in Remix
 * 2. Call updateMessage() with different strings
 * 3. Check the events tab to see MessageUpdated logs
 * 4. Try calling getMessage() - notice it's free!
 */

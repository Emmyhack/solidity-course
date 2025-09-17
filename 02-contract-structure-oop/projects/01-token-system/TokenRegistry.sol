// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./AccessControl.sol";

/**
 * @title TokenRegistry
 * @dev Registry for tracking approved tokens in the protocol
 * @notice Demonstrates registry pattern and modular contract design
 */
contract TokenRegistry is AccessControl {
    mapping(address => bool) public isRegistered;
    address[] public registeredTokens;

    event TokenRegistered(address indexed token);
    event TokenUnregistered(address indexed token);

    function registerToken(address token) external onlyRole(ADMIN_ROLE) {
        require(!isRegistered[token], "TokenRegistry: already registered");
        isRegistered[token] = true;
        registeredTokens.push(token);
        emit TokenRegistered(token);
    }

    function unregisterToken(address token) external onlyRole(ADMIN_ROLE) {
        require(isRegistered[token], "TokenRegistry: not registered");
        isRegistered[token] = false;
        // Remove from array (gas-inefficient, for demo)
        for (uint256 i = 0; i < registeredTokens.length; i++) {
            if (registeredTokens[i] == token) {
                registeredTokens[i] = registeredTokens[
                    registeredTokens.length - 1
                ];
                registeredTokens.pop();
                break;
            }
        }
        emit TokenUnregistered(token);
    }

    function getRegisteredTokens() external view returns (address[] memory) {
        return registeredTokens;
    }
}

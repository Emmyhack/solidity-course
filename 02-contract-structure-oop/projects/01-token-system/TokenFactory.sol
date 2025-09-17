// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./Token.sol";
import "./AccessControl.sol";

/**
 * @title TokenFactory
 * @dev Deploys new Token contracts and tracks them
 * @notice Demonstrates factory pattern and contract registry
 */
contract TokenFactory is AccessControl {
    address[] public tokens;

    event TokenCreated(
        address indexed token,
        string name,
        string symbol,
        uint8 decimals,
        uint256 initialSupply
    );

    function createToken(
        string calldata name,
        string calldata symbol,
        uint8 decimals,
        uint256 initialSupply
    ) external onlyRole(ADMIN_ROLE) returns (address) {
        Token newToken = new Token(
            name,
            symbol,
            decimals,
            initialSupply,
            msg.sender
        );
        tokens.push(address(newToken));
        emit TokenCreated(
            address(newToken),
            name,
            symbol,
            decimals,
            initialSupply
        );
        return address(newToken);
    }

    function getTokens() external view returns (address[] memory) {
        return tokens;
    }
}

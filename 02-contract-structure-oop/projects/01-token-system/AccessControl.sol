// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title AccessControl
 * @dev Role-based access control system for modular contracts
 * @notice Demonstrates advanced OOP and security patterns
 *
 * Features:
 * - Role management (admin, minter, pauser)
 * - Grant/revoke roles
 * - Role-based modifiers
 * - Event-driven architecture
 */
contract AccessControl {
    mapping(bytes32 => mapping(address => bool)) private _roles;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    event RoleGranted(bytes32 indexed role, address indexed account);
    event RoleRevoked(bytes32 indexed role, address indexed account);

    modifier onlyRole(bytes32 role) {
        require(_roles[role][msg.sender], "AccessControl: missing role");
        _;
    }

    function grantRole(
        bytes32 role,
        address account
    ) external onlyRole(ADMIN_ROLE) {
        _roles[role][account] = true;
        emit RoleGranted(role, account);
    }

    function revokeRole(
        bytes32 role,
        address account
    ) external onlyRole(ADMIN_ROLE) {
        _roles[role][account] = false;
        emit RoleRevoked(role, account);
    }

    function hasRole(bytes32 role, address account) public view returns (bool) {
        return _roles[role][account];
    }

    // Initial admin setup
    constructor() {
        _roles[ADMIN_ROLE][msg.sender] = true;
        emit RoleGranted(ADMIN_ROLE, msg.sender);
    }
}

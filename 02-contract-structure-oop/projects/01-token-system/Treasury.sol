// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./AccessControl.sol";
import "./Token.sol";

/**
 * @title Treasury
 * @dev Manages token reserves and payments for the protocol
 * @notice Demonstrates modular contract design and secure fund management
 */
contract Treasury is AccessControl {
    Token public token;

    event FundsDeposited(address indexed from, uint256 amount);
    event FundsWithdrawn(address indexed to, uint256 amount);

    constructor(address tokenAddress) {
        token = Token(tokenAddress);
    }

    function deposit(uint256 amount) external {
        require(
            token.transferFrom(msg.sender, address(this), amount),
            "Treasury: transfer failed"
        );
        emit FundsDeposited(msg.sender, amount);
    }

    function withdraw(
        address to,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) {
        require(
            token.balanceOf(address(this)) >= amount,
            "Treasury: insufficient funds"
        );
        require(token.transfer(to, amount), "Treasury: transfer failed");
        emit FundsWithdrawn(to, amount);
    }

    function treasuryBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }
}

# Assignment 3: Digital Wallet

Create a multi-user digital wallet with allowances and transaction limits.

## 🎯 Objective

Build a wallet contract that manages balances, allowances, and implements daily spending limits.

## 📋 Requirements

### Core Features

```solidity
// Balance management
function deposit() public payable
function withdraw(uint256 amount) public
function transfer(address to, uint256 amount) public
function getBalance(address user) public view returns (uint256)

// Allowance system
function approve(address spender, uint256 amount) public
function transferFrom(address from, address to, uint256 amount) public
function getAllowance(address owner, address spender) public view returns (uint256)

// Daily limits
function setDailyLimit(uint256 limit) public
function getDailySpent(address user) public view returns (uint256)
function getRemainingDailyLimit(address user) public view returns (uint256)
```

### Advanced Features

- Transaction history tracking
- Emergency pause functionality
- Multi-signature requirements for large amounts
- Interest calculation on stored funds

## ✅ Requirements Checklist

- [ ] Users can deposit and withdraw Ether
- [ ] Transfer between users works
- [ ] Allowance system prevents unauthorized transfers
- [ ] Daily limits are enforced
- [ ] Transaction history is maintained
- [ ] Emergency pause stops all operations
- [ ] Events track all financial operations

## 🧪 Test Scenarios

1. Deposit Ether to contract
2. Transfer between users
3. Test allowance system
4. Hit daily limit and verify blocking
5. Test emergency pause
6. Verify transaction history

---

**Estimated Time**: 4-5 hours

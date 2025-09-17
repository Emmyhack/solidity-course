# Assignment 1: Calculator Contract

Build a smart contract calculator with memory and history features.

## 🎯 Objective

Create a calculator contract that performs basic arithmetic operations and maintains a history of calculations.

## 📋 Requirements

### Core Functions

Implement these calculator functions:

```solidity
function add(uint256 a, uint256 b) public returns (uint256)
function subtract(uint256 a, uint256 b) public returns (uint256)
function multiply(uint256 a, uint256 b) public returns (uint256)
function divide(uint256 a, uint256 b) public returns (uint256)
function power(uint256 base, uint256 exponent) public returns (uint256)
```

### Memory Functions

```solidity
function getLastResult() public view returns (uint256)
function clearMemory() public
function getCalculationCount() public view returns (uint256)
```

### History Functions

```solidity
struct Calculation {
    string operation;
    uint256 operand1;
    uint256 operand2;
    uint256 result;
    address calculator;
    uint256 timestamp;
}

function getHistory(uint256 index) public view returns (Calculation memory)
function getHistoryLength() public view returns (uint256)
function clearHistory() public // Owner only
```

## ✅ Requirements Checklist

- [ ] All arithmetic functions work correctly
- [ ] Division by zero is handled properly
- [ ] Results are stored in memory
- [ ] Calculation history is maintained
- [ ] Events are emitted for each calculation
- [ ] Only owner can clear history
- [ ] Overflow protection (use SafeMath concepts)

## 🧪 Test Cases

1. Test basic arithmetic operations
2. Test division by zero (should revert)
3. Test memory functions
4. Test history tracking
5. Test owner-only functions

---

**Estimated Time**: 2-3 hours

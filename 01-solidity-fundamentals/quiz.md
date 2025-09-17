# Module 1 Quiz: Solidity Fundamentals

Test your knowledge of basic Solidity concepts!

## Instructions

- Answer all questions
- Explain your reasoning for complex questions
- No external resources allowed
- Take your time to think through each question

---

## Question 1: Basic Syntax (10 points)

Which of the following is the correct way to declare a public uint256 variable named `balance`?

A) `uint256 public balance;`
B) `public uint256 balance;`
C) `uint balance public;`
D) `var public balance: uint256;`

**Answer**: \_\_\_\_

---

## Question 2: Function Visibility (15 points)

What's the difference between `public` and `external` function visibility? When would you use each?

**Answer**:

---

## Question 3: Data Types (10 points)

What is the default value for each of these data types?

- `bool`: \_\_\_\_
- `uint256`: \_\_\_\_
- `address`: \_\_\_\_
- `string`: \_\_\_\_

---

## Question 4: Memory vs Storage (20 points)

Explain the difference between `memory` and `storage` in Solidity. Give an example of when you would use each.

**Answer**:

---

## Question 5: Code Analysis (20 points)

What's wrong with this function? How would you fix it?

```solidity
function transfer(address to, uint amount) public {
    balances[msg.sender] = balances[msg.sender] - amount;
    balances[to] = balances[to] + amount;
}
```

**Issues identified**:

**Fixed version**:

```solidity
// Your corrected code here
```

---

## Question 6: Events (15 points)

Why are events important in smart contracts? Write an event declaration for a token transfer.

**Importance**:

**Event declaration**:

```solidity
// Your event here
```

---

## Question 7: Require Statements (10 points)

Complete this function with appropriate require statements:

```solidity
function withdraw(uint256 amount) public {
    // Add require statements here

    balances[msg.sender] -= amount;
    payable(msg.sender).transfer(amount);
}
```

**Your solution**:

```solidity
function withdraw(uint256 amount) public {
    // Your require statements here

    balances[msg.sender] -= amount;
    payable(msg.sender).transfer(amount);
}
```

---

## Bonus Question: Gas Optimization (5 points)

How could you optimize this loop for gas efficiency?

```solidity
function sumArray(uint256[] memory numbers) public pure returns (uint256) {
    uint256 sum = 0;
    for (uint256 i = 0; i < numbers.length; i++) {
        sum = sum + numbers[i];
    }
    return sum;
}
```

**Optimized version**:

---

## Scoring

- **90-100**: Excellent! You've mastered the fundamentals
- **80-89**: Good understanding, review weak areas
- **70-79**: Solid foundation, practice more
- **Below 70**: Review module content and retake quiz

## Answer Key

_Complete the quiz first, then check solutions in the solutions folder_

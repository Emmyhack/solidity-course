# Module 4 Quiz: Error Handling & Security

Test your understanding of smart contract security and error handling mechanisms.

## Instructions

- Choose the best answer for each question
- Some questions may have multiple correct answers
- Review the explanations after completing the quiz

---

## Question 1: Reentrancy Protection

Which of the following is the BEST practice to prevent reentrancy attacks?

A) Use `tx.origin` instead of `msg.sender` for authentication
B) Follow the Checks-Effects-Interactions pattern
C) Always use `transfer()` instead of `call()`
D) Implement a simple boolean lock

**Answer: B**

**Explanation**: The Checks-Effects-Interactions pattern ensures that all state changes occur before external calls, preventing reentrancy attacks. Option A is incorrect as `tx.origin` is vulnerable to attacks. Option C is outdated as `transfer()` has gas limitations. Option D (simple lock) is less robust than proper reentrancy guards.

---

## Question 2: Custom Errors

What are the advantages of using custom errors over string revert messages?

A) Lower gas costs
B) Better error handling in client applications
C) Ability to include parameters for debugging
D) All of the above

**Answer: D**

**Explanation**: Custom errors introduced in Solidity 0.8.4 provide all these benefits: they're more gas-efficient than string messages, easier to handle programmatically, and can include parameters for better debugging.

---

## Question 3: Integer Arithmetic

In Solidity 0.8.0+, which statement about integer arithmetic is correct?

A) Overflow and underflow still occur silently
B) SafeMath library is still required for all arithmetic
C) Overflow and underflow cause automatic reverts
D) Manual checks are always needed for safe arithmetic

**Answer: C**

**Explanation**: Solidity 0.8.0+ introduced automatic overflow/underflow protection that causes transactions to revert when arithmetic operations would overflow or underflow.

---

## Question 4: Access Control

Which of these access control patterns is MOST secure?

```solidity
// Option A
modifier onlyOwner() {
    require(tx.origin == owner);
    _;
}

// Option B
modifier onlyOwner() {
    require(msg.sender == owner);
    _;
}

// Option C
modifier onlyOwner() {
    if (msg.sender != owner) {
        revert UnauthorizedAccess(msg.sender, owner);
    }
    _;
}
```

A) Option A
B) Option B  
C) Option C
D) All are equally secure

**Answer: C**

**Explanation**: Option C is most secure as it uses `msg.sender` (not vulnerable like `tx.origin`), uses custom errors for gas efficiency, and provides detailed error information. Option A is vulnerable to phishing attacks.

---

## Question 5: External Call Safety

What's the correct way to handle external call failures?

```solidity
// Option A
recipient.call{value: amount}("");

// Option B
(bool success, ) = recipient.call{value: amount}("");
require(success, "Transfer failed");

// Option C
(bool success, ) = recipient.call{value: amount}("");
if (!success) {
    pendingWithdrawals[recipient] += amount;
    emit TransferFailed(recipient, amount);
}
```

A) Option A - Trust the call will succeed
B) Option B - Always revert on failure
C) Option C - Handle failure gracefully
D) Use `transfer()` instead

**Answer: C**

**Explanation**: Option C handles failures gracefully by storing failed transfers for later withdrawal, which prevents DoS attacks and provides better user experience.

---

## Question 6: Front-Running Protection

Which technique BEST protects against front-running attacks?

A) Using private mempools
B) Commit-reveal schemes
C) Higher gas prices
D) Time delays

**Answer: B**

**Explanation**: Commit-reveal schemes hide transaction details during the commit phase, making front-running impossible as attackers can't see the actual values being submitted.

---

## Question 7: Oracle Security

What's the most robust approach for oracle price feeds?

A) Use a single, trusted oracle
B) Use multiple oracles with median calculation
C) Cache prices to avoid frequent calls
D) Always use the latest price

**Answer: B**

**Explanation**: Using multiple oracles with median or average calculation provides redundancy and makes price manipulation much more difficult.

---

## Question 8: Emergency Controls

Which emergency control mechanism is MOST appropriate for a DeFi protocol?

A) Owner can withdraw all funds at any time
B) Pausable contract with timelock for unpause
C) Immediate shutdown with no recovery
D) Emergency withdrawal only for the owner

**Answer: B**

**Explanation**: A pausable contract with timelock for unpausing provides emergency protection while preventing abuse and ensuring community oversight.

---

## Question 9: Gas Optimization

Which pattern is MOST gas-efficient for error handling?

```solidity
// Option A
require(amount > 0, "Amount must be greater than zero");

// Option B
if (amount == 0) {
    revert InvalidAmount(amount);
}

// Option C
assert(amount > 0);
```

A) Option A
B) Option B
C) Option C
D) All are equally efficient

**Answer: B**

**Explanation**: Custom errors (Option B) are the most gas-efficient for error handling, especially when including parameters. Option C uses `assert` incorrectly for input validation.

---

## Question 10: Vulnerability Assessment

Identify the vulnerability in this code:

```solidity
function withdraw() external {
    uint256 amount = balances[msg.sender];
    require(amount > 0, "No balance");

    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");

    balances[msg.sender] = 0;
}
```

A) No vulnerability present
B) Reentrancy vulnerability
C) Integer overflow vulnerability  
D) Access control vulnerability

**Answer: B**

**Explanation**: This code is vulnerable to reentrancy because the external call happens before updating the balance. An attacker could recursively call withdraw() before the balance is set to zero.

---

## Question 11: Error Types

When should you use `assert()` vs `require()` vs `revert()`?

A) `assert()` for any condition checking
B) `require()` for internal consistency, `assert()` for input validation
C) `require()` for input validation, `assert()` for internal consistency, `revert()` with custom errors
D) They're all interchangeable

**Answer: C**

**Explanation**: `require()` is for input validation and external conditions, `assert()` is for internal consistency checks that should never fail, and `revert()` with custom errors provides the most gas-efficient error handling.

---

## Question 12: Security Testing

Which testing approach is MOST comprehensive for security?

A) Unit tests only
B) Static analysis only
C) Manual code review only
D) Combination of automated tools, manual review, and formal verification

**Answer: D**

**Explanation**: A comprehensive security approach combines multiple methodologies: automated tools catch common patterns, manual review finds logic issues, and formal verification proves mathematical properties.

---

## Score Interpretation

- **11-12 correct**: Expert level - You have mastery of security concepts
- **9-10 correct**: Advanced level - Strong understanding with minor gaps
- **7-8 correct**: Intermediate level - Good foundation, need more practice
- **5-6 correct**: Beginner level - Review security fundamentals
- **<5 correct**: Study required - Focus on security basics first

---

## Key Takeaways

1. **Security First**: Always prioritize security over convenience or gas optimization
2. **Defense in Depth**: Implement multiple layers of protection
3. **Fail Securely**: When things go wrong, fail in the safest possible state
4. **Continuous Learning**: Security best practices evolve constantly
5. **Test Thoroughly**: Use multiple testing approaches for comprehensive coverage

## Additional Resources

- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [SWC Registry](https://swcregistry.io/) - Vulnerability classifications
- [OpenZeppelin Security Guidelines](https://docs.openzeppelin.com/contracts/4.x/security)
- [Secureum Security Bootcamp](https://secureum.substack.com/)

---

**Remember**: In smart contract development, being 99% secure is not good enough. Strive for perfection and always err on the side of caution. 

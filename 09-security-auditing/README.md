# Module 9: Security & Auditing

Master smart contract security through real exploit analysis, comprehensive auditing techniques, and production-grade security implementations.

## 📚 Module Overview

This module provides comprehensive coverage of smart contract security, from understanding common vulnerabilities to conducting professional audits. You'll learn through real exploit case studies and build secure, production-ready contracts.

**Duration:** 40-45 hours  
**Difficulty:** Expert  
**Prerequisites:** Modules 1-8

## 🎯 Learning Objectives

By the end of this module, you will be able to:

- Identify and prevent common smart contract vulnerabilities
- Conduct comprehensive security audits using professional tools
- Implement advanced security patterns and best practices
- Analyze real-world exploits and understand attack vectors
- Design secure contract architectures from the ground up
- Use formal verification and symbolic execution tools
- Build incident response and recovery mechanisms
- Implement proper access controls and permission systems
- Handle secure upgrades and emergency procedures
- Understand MEV (Maximal Extractable Value) attacks and prevention

## 📖 Module Structure

### 9.1 Common Vulnerabilities (12-15 hours)

- **Topics:** Reentrancy, overflow, access control, oracle manipulation
- **Practice:** Exploit vulnerable contracts, implement fixes
- **Files:** `vulnerabilities/`, exploit examples

### 9.2 Auditing Tools & Techniques (10-12 hours)

- **Topics:** Static analysis, dynamic testing, formal verification
- **Practice:** Audit real contracts with professional tools
- **Files:** `auditing/`, security analysis

### 9.3 Advanced Security Patterns (8-10 hours)

- **Topics:** Circuit breakers, timelock, multi-sig, proxy security
- **Practice:** Implement security mechanisms
- **Files:** `patterns/`, security implementations

### 9.4 Incident Response & Recovery (6-8 hours)

- **Topics:** Emergency procedures, upgrade mechanisms, fund recovery
- **Practice:** Design recovery systems
- **Files:** `incident-response/`, emergency contracts

### 9.5 MEV & Front-running Protection (4-6 hours)

- **Topics:** MEV attacks, commit-reveal schemes, batching
- **Practice:** Build MEV-resistant protocols
- **Files:** `mev-protection/`, protection mechanisms

## 📁 Module Files

```
09-security-auditing/
├── README.md                    # This file
├── vulnerabilities/
│   ├── README.md               # Vulnerability guide
│   ├── ReentrancyExamples.sol  # Reentrancy attacks & fixes
│   ├── OverflowUnderflow.sol   # Integer vulnerabilities
│   ├── AccessControlFlaws.sol  # Permission bypass examples
│   ├── OracleManipulation.sol  # Price oracle attacks
│   ├── FlashLoanAttacks.sol    # Flash loan exploit patterns
│   └── FrontRunningExamples.sol # MEV and front-running
├── auditing/
│   ├── README.md               # Auditing methodology
│   ├── StaticAnalysis.md       # Tool usage guide
│   ├── audit-checklist.md      # Comprehensive checklist
│   ├── AuditReport.md          # Sample audit report
│   └── tools/                  # Auditing tool configs
├── patterns/
│   ├── README.md               # Security patterns guide
│   ├── CircuitBreaker.sol      # Emergency stops
│   ├── TimelockController.sol  # Delayed execution
│   ├── MultiSigWallet.sol      # Multi-signature security
│   ├── UpgradeableProxy.sol    # Secure proxy patterns
│   └── AccessControlRegistry.sol # Advanced permissions
├── incident-response/
│   ├── README.md               # Incident response guide
│   ├── EmergencySystem.sol     # Emergency procedures
│   ├── FundRecovery.sol        # Asset recovery mechanisms
│   ├── UpgradeGovernance.sol   # Secure upgrade systems
│   └── PostMortemTemplate.md   # Incident analysis template
├── mev-protection/
│   ├── README.md               # MEV protection guide
│   ├── CommitReveal.sol        # Commit-reveal schemes
│   ├── BatchAuction.sol        # Fair price discovery
│   ├── FlashbotsIntegration.sol # MEV mitigation
│   └── OrderProtection.sol     # Order flow protection
├── case-studies/
│   ├── the-dao-exploit/        # Historical DAO hack analysis
│   ├── flash-loan-attacks/     # Recent flash loan exploits
│   ├── bridge-hacks/           # Cross-chain bridge attacks
│   └── defi-exploits/          # DeFi protocol attacks
└── assignments/
    ├── vulnerability-hunt.md    # Find and fix vulnerabilities
    ├── audit-practice.md       # Conduct security audit
    ├── security-design.md      # Design secure protocol
    └── solutions/              # Assignment solutions
```

## 🚨 Critical Vulnerabilities

### 1. Reentrancy Attacks

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title ReentrancyExamples
 * @dev Demonstrates reentrancy vulnerabilities and proper fixes
 */
contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    // VULNERABLE: Classic reentrancy attack vector
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // DANGER: External call before state update
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // VULNERABLE: State updated after external call
        balances[msg.sender] -= amount;
    }
}

/**
 * @title AttackContract
 * @dev Exploits reentrancy vulnerability
 */
contract ReentrancyAttacker {
    VulnerableBank public bank;
    uint256 public attackAmount = 1 ether;

    constructor(address _bank) {
        bank = VulnerableBank(_bank);
    }

    function attack() external payable {
        require(msg.value >= attackAmount, "Need attack funds");
        bank.deposit{value: attackAmount}();
        bank.withdraw(attackAmount);
    }

    // Reentrancy attack happens here
    receive() external payable {
        if (address(bank).balance >= attackAmount) {
            bank.withdraw(attackAmount);
        }
    }
}

/**
 * @title SecureBank
 * @dev Properly secured against reentrancy
 */
contract SecureBank is ReentrancyGuard {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    // SECURE: Multiple protection mechanisms
    function withdraw(uint256 amount) external nonReentrant {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        // Checks-Effects-Interactions pattern
        balances[msg.sender] -= amount; // Effects first

        // Interactions last
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }

    // Alternative: Pull over Push pattern
    mapping(address => uint256) public withdrawalCredits;

    function requestWithdrawal(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        withdrawalCredits[msg.sender] += amount;
    }

    function claimWithdrawal() external nonReentrant {
        uint256 amount = withdrawalCredits[msg.sender];
        require(amount > 0, "No pending withdrawal");

        withdrawalCredits[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");
    }
}
```

### 2. Oracle Manipulation Attacks

```solidity
/**
 * @title OracleManipulation
 * @dev Demonstrates oracle attacks and mitigation strategies
 */

// VULNERABLE: Single oracle dependency
contract VulnerableLending {
    IPriceOracle public priceOracle;
    mapping(address => uint256) public collateral;
    mapping(address => uint256) public borrowed;

    uint256 public constant COLLATERAL_RATIO = 150; // 150%

    function borrow(address token, uint256 amount) external {
        uint256 collateralValue = getCollateralValue(msg.sender);
        uint256 maxBorrow = (collateralValue * 100) / COLLATERAL_RATIO;

        require(borrowed[msg.sender] + amount <= maxBorrow, "Insufficient collateral");

        borrowed[msg.sender] += amount;
        // Transfer tokens...
    }

    function getCollateralValue(address user) public view returns (uint256) {
        // VULNERABLE: Single price source
        uint256 price = priceOracle.getPrice(collateralToken);
        return collateral[user] * price;
    }
}

// SECURE: Multiple oracle protection
contract SecureLending {
    struct PriceData {
        uint256 price;
        uint256 timestamp;
        uint256 roundId;
    }

    mapping(address => PriceData) public lastPrices;
    address[] public priceOracles;
    uint256 public maxPriceDeviation = 500; // 5%
    uint256 public priceValidityPeriod = 1 hours;

    function getSecurePrice(address token) public view returns (uint256) {
        uint256[] memory prices = new uint256[](priceOracles.length);
        uint256 validPrices = 0;

        // Get prices from multiple oracles
        for (uint256 i = 0; i < priceOracles.length; i++) {
            try IPriceOracle(priceOracles[i]).getPrice(token) returns (uint256 price) {
                if (price > 0) {
                    prices[validPrices] = price;
                    validPrices++;
                }
            } catch {
                // Oracle failed, skip
            }
        }

        require(validPrices >= 2, "Insufficient oracle data");

        // Calculate median price
        uint256 medianPrice = _calculateMedian(prices, validPrices);

        // Validate against historical price
        PriceData memory lastPrice = lastPrices[token];
        if (lastPrice.timestamp + priceValidityPeriod > block.timestamp) {
            uint256 deviation = _calculateDeviation(medianPrice, lastPrice.price);
            require(deviation <= maxPriceDeviation, "Price manipulation detected");
        }

        return medianPrice;
    }

    function _calculateMedian(uint256[] memory prices, uint256 length)
        internal
        pure
        returns (uint256)
    {
        // Sort prices
        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (prices[j] > prices[j + 1]) {
                    uint256 temp = prices[j];
                    prices[j] = prices[j + 1];
                    prices[j + 1] = temp;
                }
            }
        }

        if (length % 2 == 0) {
            return (prices[length / 2 - 1] + prices[length / 2]) / 2;
        } else {
            return prices[length / 2];
        }
    }

    function _calculateDeviation(uint256 newPrice, uint256 oldPrice)
        internal
        pure
        returns (uint256)
    {
        uint256 difference = newPrice > oldPrice ?
            newPrice - oldPrice : oldPrice - newPrice;
        return (difference * 10000) / oldPrice; // Basis points
    }
}
```

### 3. Flash Loan Attacks

```solidity
/**
 * @title FlashLoanAttacks
 * @dev Analysis of flash loan attack patterns and prevention
 */

// Example of a vulnerable DeFi protocol
contract VulnerableAMM {
    uint256 public reserveA = 1000000 * 10**18; // 1M tokens
    uint256 public reserveB = 1000000 * 10**18; // 1M tokens

    function swap(uint256 amountIn, bool aToB) external returns (uint256 amountOut) {
        if (aToB) {
            // VULNERABLE: Simple constant product without slippage protection
            amountOut = (reserveB * amountIn) / (reserveA + amountIn);
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            amountOut = (reserveA * amountIn) / (reserveB + amountIn);
            reserveB += amountIn;
            reserveA -= amountOut;
        }
    }
}

// Flash loan attack example
contract FlashLoanAttacker {
    VulnerableAMM public amm;
    IFlashLoanProvider public flashLoanProvider;

    function executeAttack() external {
        // 1. Get flash loan of 10M tokens
        uint256 loanAmount = 10000000 * 10**18;
        flashLoanProvider.flashLoan(loanAmount, abi.encode("attack"));
    }

    function onFlashLoan(uint256 amount, bytes calldata data) external {
        // 2. Use flash loan to manipulate AMM price
        uint256 swapOut = amm.swap(amount, true);

        // 3. Exploit arbitrage opportunity (simplified)
        // In reality, this would interact with other protocols

        // 4. Swap back to repay loan + fee
        amm.swap(swapOut, false);

        // 5. Repay flash loan (handled by flash loan provider)
    }
}

// Protection mechanisms
contract ProtectedAMM {
    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public lastTradeBlock;
    mapping(address => uint256) public lastUserTradeBlock;

    uint256 public maxSlippage = 300; // 3%
    uint256 public maxTradeSize = 10000 * 10**18; // Max per trade

    modifier protectedTrade() {
        // Protection 1: One trade per block per user
        require(lastUserTradeBlock[msg.sender] < block.number, "One trade per block");
        lastUserTradeBlock[msg.sender] = block.number;

        // Protection 2: Global cooldown
        require(lastTradeBlock < block.number, "Global cooldown");
        lastTradeBlock = block.number;
        _;
    }

    function swap(uint256 amountIn, bool aToB)
        external
        protectedTrade
        returns (uint256 amountOut)
    {
        require(amountIn <= maxTradeSize, "Trade too large");

        uint256 oldPrice = (reserveA * 10**18) / reserveB;

        if (aToB) {
            amountOut = (reserveB * amountIn) / (reserveA + amountIn);
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            amountOut = (reserveA * amountIn) / (reserveB + amountIn);
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        // Protection 3: Price impact limits
        uint256 newPrice = (reserveA * 10**18) / reserveB;
        uint256 priceImpact = _calculatePriceImpact(oldPrice, newPrice);
        require(priceImpact <= maxSlippage, "Slippage too high");
    }

    function _calculatePriceImpact(uint256 oldPrice, uint256 newPrice)
        internal
        pure
        returns (uint256)
    {
        uint256 difference = oldPrice > newPrice ?
            oldPrice - newPrice : newPrice - oldPrice;
        return (difference * 10000) / oldPrice;
    }
}
```

## 🛡️ Advanced Security Patterns

### 1. Circuit Breaker Pattern

```solidity
/**
 * @title CircuitBreaker
 * @dev Emergency stop mechanism for critical situations
 */
contract CircuitBreaker is AccessControl {
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");

    bool public circuitBreakerActive = false;
    uint256 public circuitBreakerActivatedAt;
    uint256 public constant CIRCUIT_BREAKER_TIMEOUT = 24 hours;

    // Withdrawal limits during emergency
    mapping(address => uint256) public emergencyWithdrawalLimits;
    mapping(address => uint256) public emergencyWithdrawalsUsed;

    event CircuitBreakerActivated(address indexed activator, string reason);
    event CircuitBreakerDeactivated(address indexed deactivator);
    event EmergencyWithdrawal(address indexed user, uint256 amount);

    modifier whenNotCircuitBroken() {
        require(!circuitBreakerActive, "Circuit breaker is active");
        _;
    }

    modifier onlyDuringEmergency() {
        require(circuitBreakerActive, "Not in emergency mode");
        require(
            block.timestamp <= circuitBreakerActivatedAt + CIRCUIT_BREAKER_TIMEOUT,
            "Emergency period expired"
        );
        _;
    }

    function activateCircuitBreaker(string calldata reason)
        external
        onlyRole(GUARDIAN_ROLE)
    {
        circuitBreakerActive = true;
        circuitBreakerActivatedAt = block.timestamp;
        emit CircuitBreakerActivated(msg.sender, reason);
    }

    function deactivateCircuitBreaker() external onlyRole(DEFAULT_ADMIN_ROLE) {
        circuitBreakerActive = false;
        emit CircuitBreakerDeactivated(msg.sender);
    }

    function emergencyWithdraw(uint256 amount) external onlyDuringEmergency {
        uint256 limit = emergencyWithdrawalLimits[msg.sender];
        uint256 used = emergencyWithdrawalsUsed[msg.sender];

        require(used + amount <= limit, "Emergency withdrawal limit exceeded");

        emergencyWithdrawalsUsed[msg.sender] += amount;

        // Perform withdrawal logic...

        emit EmergencyWithdrawal(msg.sender, amount);
    }
}
```

### 2. Multi-Signature Security

```solidity
/**
 * @title MultiSigWallet
 * @dev Production-grade multi-signature wallet with advanced features
 */
contract MultiSigWallet {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
        mapping(address => bool) isConfirmed;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredConfirmations;

    Transaction[] public transactions;

    // Advanced features
    uint256 public dailyLimit = 10 ether;
    uint256 public spentToday;
    uint256 public lastDay;

    mapping(address => uint256) public spentToday;

    event Deposit(address indexed sender, uint256 value);
    event Submission(uint256 indexed transactionId);
    event Confirmation(address indexed sender, uint256 indexed transactionId);
    event Execution(uint256 indexed transactionId);
    event RequirementChange(uint256 required);

    modifier onlyWallet() {
        require(msg.sender == address(this), "Only wallet can call");
        _;
    }

    modifier ownerExists(address owner) {
        require(isOwner[owner], "Owner does not exist");
        _;
    }

    modifier transactionExists(uint256 transactionId) {
        require(transactionId < transactions.length, "Transaction does not exist");
        _;
    }

    modifier confirmed(uint256 transactionId, address owner) {
        require(transactions[transactionId].isConfirmed[owner], "Not confirmed");
        _;
    }

    modifier notConfirmed(uint256 transactionId, address owner) {
        require(!transactions[transactionId].isConfirmed[owner], "Already confirmed");
        _;
    }

    modifier notExecuted(uint256 transactionId) {
        require(!transactions[transactionId].executed, "Already executed");
        _;
    }

    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length >= 3, "Minimum 3 owners required");
        require(_required >= 2 && _required <= _owners.length, "Invalid required confirmations");

        for (uint256 i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            require(!isOwner[_owners[i]], "Duplicate owner");

            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }

        requiredConfirmations = _required;
    }

    function submitTransaction(address to, uint256 value, bytes calldata data)
        external
        returns (uint256 transactionId)
    {
        require(isOwner[msg.sender], "Not an owner");

        transactionId = transactions.length;

        Transaction storage newTx = transactions.push();
        newTx.to = to;
        newTx.value = value;
        newTx.data = data;
        newTx.executed = false;
        newTx.confirmations = 0;

        emit Submission(transactionId);

        // Auto-confirm by submitter
        confirmTransaction(transactionId);
    }

    function confirmTransaction(uint256 transactionId)
        public
        ownerExists(msg.sender)
        transactionExists(transactionId)
        notConfirmed(transactionId, msg.sender)
    {
        Transaction storage txn = transactions[transactionId];
        txn.isConfirmed[msg.sender] = true;
        txn.confirmations++;

        emit Confirmation(msg.sender, transactionId);

        executeTransaction(transactionId);
    }

    function executeTransaction(uint256 transactionId)
        public
        notExecuted(transactionId)
    {
        Transaction storage txn = transactions[transactionId];

        if (txn.confirmations >= requiredConfirmations) {
            txn.executed = true;

            // Check daily limits for ETH transfers
            if (txn.to != address(0) && txn.value > 0) {
                if (isToday()) {
                    require(spentToday + txn.value <= dailyLimit, "Daily limit exceeded");
                    spentToday += txn.value;
                } else {
                    lastDay = today();
                    spentToday = txn.value;
                }
            }

            (bool success, ) = txn.to.call{value: txn.value}(txn.data);
            if (success) {
                emit Execution(transactionId);
            } else {
                txn.executed = false;
            }
        }
    }

    function revokeConfirmation(uint256 transactionId)
        external
        ownerExists(msg.sender)
        confirmed(transactionId, msg.sender)
        notExecuted(transactionId)
    {
        Transaction storage txn = transactions[transactionId];
        txn.isConfirmed[msg.sender] = false;
        txn.confirmations--;
    }

    // Emergency functions for small amounts
    function emergencyWithdraw(uint256 amount) external {
        require(isOwner[msg.sender], "Not an owner");
        require(amount <= 1 ether, "Amount too large for emergency withdrawal");

        payable(msg.sender).transfer(amount);
    }

    function isToday() private view returns (bool) {
        return today() == lastDay;
    }

    function today() private view returns (uint256) {
        return block.timestamp / 1 days;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
}
```

## 🔍 Professional Auditing Process

### 1. Automated Analysis Tools

```bash
# Static Analysis Tools
slither .                      # Vulnerability detection
mythril analyze contract.sol   # Symbolic execution
echidna contract.sol          # Fuzzing
manticore contract.py         # Symbolic execution

# Gas Analysis
hardhat-gas-reporter          # Gas usage analysis
eth-gas-reporter             # Detailed gas reporting

# Code Quality
solhint contracts/**/*.sol    # Solidity linting
prettier --write contracts/   # Code formatting
```

### 2. Manual Review Checklist

#### Access Control

- [ ] All functions have proper access modifiers
- [ ] Role-based access control implemented correctly
- [ ] No privilege escalation vulnerabilities
- [ ] Emergency functions properly protected

#### External Calls

- [ ] Reentrancy protection in place
- [ ] Checks-Effects-Interactions pattern followed
- [ ] Return values checked for external calls
- [ ] Gas limits considered for external calls

#### Input Validation

- [ ] All inputs validated and sanitized
- [ ] Proper bounds checking
- [ ] Division by zero checks
- [ ] Overflow/underflow protection

#### Economic Security

- [ ] No flash loan attack vectors
- [ ] Oracle manipulation resistance
- [ ] MEV protection mechanisms
- [ ] Fee calculation correctness

## 📊 Security Metrics & KPIs

### Code Quality Metrics

1. **Test Coverage**: >95% line coverage required
2. **Cyclomatic Complexity**: <10 per function
3. **Function Length**: <50 lines per function
4. **Contract Size**: <24KB deployment limit
5. **Gas Efficiency**: Optimized for mainnet costs

### Security Assessment Levels

1. **Critical**: Immediate fund loss risk
2. **High**: Significant impact, exploit likely
3. **Medium**: Limited impact, complex exploit
4. **Low**: Minimal impact, unlikely exploit
5. **Informational**: Best practice recommendations

This security module provides comprehensive coverage of smart contract security from basic vulnerabilities to advanced protection mechanisms, ensuring developers can build secure, production-ready protocols.

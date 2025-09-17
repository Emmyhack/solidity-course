# AMM DEX - Foundry Development Project

A comprehensive Automated Market Maker (AMM) Decentralized Exchange implementation built with Foundry, demonstrating advanced Solidity development, testing, and deployment practices.

##  Project Overview

This project showcases a production-ready AMM DEX with the following features:

- **Automated Market Making**: Constant product formula (x \* y = k)
- **Liquidity Provision**: Add/remove liquidity with LP tokens
- **Token Swapping**: Bidirectional token swaps with configurable fees
- **Flash Loans**: Uncollateralized loans with fee-based repayment
- **Security Features**: Reentrancy protection, access controls, emergency functions
- **Gas Optimization**: Efficient operations with detailed gas analysis

##  Architecture

### Core Components

1. **AMMDEX.sol**: Main AMM contract with all trading functionality
2. **MockERC20.sol**: ERC20 implementation for testing
3. **Comprehensive Test Suite**: Unit, integration, fuzz, and invariant tests
4. **Deployment Scripts**: Multi-network deployment with configuration
5. **Gas Analysis**: Detailed gas optimization and benchmarking

### Key Features

- **Constant Product AMM**: Classic x \* y = k formula with fee accumulation
- **LP Token System**: ERC20-compliant liquidity provider tokens
- **Flash Loan Integration**: Secure flash loans with callback mechanism
- **Multi-path Swapping**: Support for complex trading routes
- **Admin Controls**: Configurable fees and emergency functions

##  Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd 06-foundry-development/projects/01-amm-dex

# Install dependencies
forge install

# Compile contracts
forge build

# Run tests
forge test
```

### Local Development

```bash
# Start local blockchain
anvil

# Deploy to local network
forge script script/Deploy.s.sol:QuickDeploy --fork-url http://localhost:8545 --broadcast

# Run comprehensive tests
forge test -vv

# Generate gas report
forge test --gas-report

# Run fuzz tests
forge test --fuzz-runs 10000

# Run invariant tests
forge test --match-contract Invariant
```

##  Testing

This project demonstrates Foundry's advanced testing capabilities:

### Test Types

1. **Unit Tests** (`test/AMMDEX.t.sol`)

   - Individual function testing
   - Error condition validation
   - Event emission verification
   - Gas usage assertions

2. **Fuzz Tests**

   - Property-based testing with random inputs
   - Bounded fuzzing for realistic scenarios
   - Mathematical property verification

3. **Invariant Tests** (`test/Invariant.t.sol`)

   - System-wide property maintenance
   - Handler-based interaction testing
   - Long-running state verification

4. **Gas Optimization** (`gas-optimization/GasAnalysis.t.sol`)
   - Detailed gas usage analysis
   - Performance benchmarking
   - Optimization target verification

### Running Specific Tests

```bash
# Run only unit tests
forge test --match-contract AMMDEXTest

# Run fuzz tests with specific runs
forge test --match-test testFuzz --fuzz-runs 1000

# Run invariant tests
forge test --match-contract Invariant --invariant-runs 100

# Run gas analysis
forge test --match-contract GasOptimization --gas-report
```

##  Gas Analysis

Comprehensive gas optimization analysis is included:

| Operation                  | Gas Usage | Target |
| -------------------------- | --------- | ------ |
| Add Liquidity (First)      | ~250k     | < 250k |
| Add Liquidity (Subsequent) | ~200k     | < 200k |
| Remove Liquidity           | ~150k     | < 150k |
| Swap Exact Tokens          | ~120k     | < 120k |
| Flash Loan                 | ~100k     | < 100k |
| Skim                       | ~50k      | < 50k  |
| Sync                       | ~30k      | < 30k  |

##  Deployment

### Environment Setup

Create a `.env` file:

```bash
PRIVATE_KEY=0x...
SEPOLIA_RPC_URL=https://...
MAINNET_RPC_URL=https://...
ETHERSCAN_API_KEY=...
```

### Network Deployment

```bash
# Deploy to Sepolia testnet
forge script script/Deploy.s.sol:DeployAMMDEX \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# Deploy to mainnet (careful!)
forge script script/Deploy.s.sol:DeployAMMDEX \
  --rpc-url $MAINNET_RPC_URL \
  --broadcast \
  --verify \
  --slow \
  -vvvv
```

### Upgrade Existing Deployment

```bash
AMM_ADDRESS=0x... \
NEW_SWAP_FEE=25 \
forge script script/Deploy.s.sol:UpgradeAMM \
  --rpc-url $SEPOLIA_RPC_URL \
  --broadcast
```

##  Configuration

### Foundry Configuration (`foundry.toml`)

```toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.19"
optimizer = true
optimizer_runs = 200
via_ir = false

[profile.ci]
fuzz = { runs = 10_000 }
invariant = { runs = 1_000, depth = 100 }

[fuzz]
runs = 1000
max_test_rejects = 65536

[invariant]
runs = 256
depth = 15
fail_on_revert = false
```

### Network-Specific Settings

- **Local/Anvil**: Mock tokens with high initial supply
- **Sepolia**: Test tokens with moderate supply
- **Mainnet**: Integration with existing tokens (WETH, USDC)

##  Learning Objectives

This project demonstrates:

1. **Advanced Foundry Usage**

   - Complex test scenarios and patterns
   - Fuzz and invariant testing
   - Gas optimization analysis
   - Multi-network deployment

2. **DeFi Protocol Development**

   - AMM mathematics and implementation
   - Liquidity provision mechanisms
   - Flash loan integration
   - Security best practices

3. **Professional Development Practices**
   - Comprehensive test coverage
   - Documentation and comments
   - Gas optimization techniques
   - Deployment automation

##  Security Considerations

### Security Features

- **Reentrancy Protection**: All external calls protected
- **Access Controls**: Owner-only administrative functions
- **Input Validation**: Comprehensive parameter checking
- **Emergency Functions**: Skim and sync for recovery
- **Mathematical Safety**: Overflow protection and precision handling

### Audit Considerations

- Flash loan callback validation
- LP token mint/burn mechanics
- Fee calculation accuracy
- Price manipulation resistance
- Emergency scenario handling

##  Advanced Features

### Flash Loans

```solidity
// Flash loan implementation
function flashLoan(address token, uint256 amount, bytes calldata data) external {
    // Loan execution with callback
    IFlashLoanReceiver(msg.sender).executeOperation(token, amount, fee, data);
    // Repayment verification
}
```

### Invariant Testing

```solidity
// Critical system invariants
function invariant_constant_product_increases() public {
    // k = reserve0 * reserve1 should never decrease
}

function invariant_token_balance_consistency() public {
    // Reserves should match actual token balances
}
```

### Gas Optimization

```solidity
// Optimized reserve updates
function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
    // Efficient reserve storage updates
}
```

##  Educational Value

### Foundry Concepts Demonstrated

- **Testing Frameworks**: Unit, fuzz, and invariant testing
- **Deployment Scripts**: Multi-network deployment automation
- **Gas Analysis**: Comprehensive optimization techniques
- **Development Workflow**: Professional Solidity development

### DeFi Concepts Explained

- **Automated Market Making**: Constant product formula implementation
- **Liquidity Provision**: LP token economics and mechanisms
- **Flash Loans**: Uncollateralized lending with callbacks
- **Price Discovery**: Market-driven price determination

##  Next Steps

1. **Integration Testing**: Connect with other DeFi protocols
2. **Frontend Development**: Build React/Next.js interface
3. **Advanced Features**: Add limit orders, governance tokens
4. **Layer 2 Deployment**: Deploy to Polygon, Arbitrum, Optimism
5. **Security Audit**: Professional security review

##  License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

##  Contributing

Contributions are welcome! Please read the contributing guidelines and submit pull requests for any improvements.

---

** Disclaimer**: This is an educational project. Do not use in production without proper auditing and testing.

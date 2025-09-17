# Foundry Setup Guide

Complete installation and configuration guide for Foundry development environment.

##  Installation

### Step 1: Install Rust (if not already installed)

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Verify installation
rustc --version
cargo --version
```

### Step 2: Install Foundry

```bash
# Install Foundry using the official installer
curl -L https://foundry.paradigm.xyz | bash

# Reload your PATH or restart terminal
source ~/.bashrc  # or ~/.zshrc

# Install the latest version
foundryup

# Verify installation
forge --version
cast --version
anvil --version
chisel --version
```

### Step 3: VS Code Setup (Optional but Recommended)

```bash
# Install Solidity extensions
code --install-extension JuanBlanco.solidity
code --install-extension NomicFoundation.hardhat-solidity

# Install Foundry-specific extensions
code --install-extension heyproject.vscode-foundry
```

##  Project Initialization

### Create New Project

```bash
# Create a new Foundry project
forge init my-foundry-project
cd my-foundry-project

# Project structure will be created:
# ├── foundry.toml      # Configuration file
# ├── src/              # Contract source files
# ├── test/             # Test files
# ├── script/           # Deployment scripts
# └── lib/              # Dependencies
```

### Initialize in Existing Directory

```bash
# Initialize Foundry in current directory
forge init --force .

# This creates the basic structure without overwriting existing files
```

##  Configuration

### foundry.toml Configuration

```toml
[profile.default]
# Solidity compiler version
solc_version = "0.8.19"

# Source directory
src = "src"

# Test directory
test = "test"

# Output directory
out = "out"

# Library directory
libs = ["lib"]

# Optimizer settings
optimizer = true
optimizer_runs = 200

# Via IR compilation (for complex contracts)
via_ir = false

# EVM version
evm_version = "paris"

# Verbosity level
verbosity = 2

# Gas limit for tests
gas_limit = 9223372036854775807

# Gas price for tests
gas_price = 0

# Gas reports
gas_reports = ["*"]

# Enable ffi (foreign function interface)
ffi = false

# Enable ast output
ast = false

# Bytecode hash
bytecode_hash = "none"

# CBOR metadata
cbor_metadata = false

# Revert strings
revert_strings = "default"

# Sparse mode (faster for large codebases)
sparse_mode = false

[profile.ci]
# CI-specific settings
fuzz = { runs = 10000 }
invariant = { runs = 1000 }

[profile.lite]
# Lighter profile for development
optimizer_runs = 1
fuzz = { runs = 256 }

[dependencies]
# Git dependencies
forge-std = { git = "https://github.com/foundry-rs/forge-std", tag = "v1.0.0" }
openzeppelin-contracts = { git = "https://github.com/OpenZeppelin/openzeppelin-contracts", tag = "v4.8.0" }

[fmt]
# Formatting settings
line_length = 100
tab_width = 4
bracket_spacing = true
int_types = "long"

[doc]
# Documentation settings
out = "docs"
title = "My Project Documentation"
```

### Environment Variables

```bash
# Create .env file
cat > .env << 'EOF'
# RPC URLs
ETH_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY
GOERLI_RPC_URL=https://eth-goerli.alchemyapi.io/v2/YOUR_KEY
POLYGON_RPC_URL=https://polygon-mainnet.alchemyapi.io/v2/YOUR_KEY

# Private keys (for deployment)
PRIVATE_KEY=0x...
DEPLOYER_PRIVATE_KEY=0x...

# Etherscan API keys (for verification)
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY
POLYGONSCAN_API_KEY=YOUR_POLYGONSCAN_KEY

# Other configuration
DEFAULT_ANVIL_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
EOF

# Load environment variables
source .env
```

##  Dependency Management

### Install Dependencies

```bash
# Install OpenZeppelin contracts
forge install openzeppelin/openzeppelin-contracts

# Install Forge Standard Library
forge install foundry-rs/forge-std

# Install Solmate (gas-optimized contracts)
forge install transmissions11/solmate

# Install specific version
forge install openzeppelin/openzeppelin-contracts@v4.8.0

# List installed dependencies
forge list
```

### Update Dependencies

```bash
# Update all dependencies
forge update

# Update specific dependency
forge update lib/openzeppelin-contracts

# Update to specific version
forge update lib/openzeppelin-contracts --tag v4.9.0
```

### Remove Dependencies

```bash
# Remove dependency
forge remove openzeppelin-contracts

# This removes the git submodule and updates .gitmodules
```

##  Basic Commands

### Building

```bash
# Build all contracts
forge build

# Build with specific profile
forge build --profile ci

# Build and watch for changes
forge build --watch

# Clean build artifacts
forge clean
```

### Testing

```bash
# Run all tests
forge test

# Run tests with verbosity
forge test -vvv

# Run specific test
forge test --match-test testTransfer

# Run tests for specific contract
forge test --match-contract TokenTest

# Run tests with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

### Fuzzing

```bash
# Run fuzz tests
forge test --fuzz-runs 1000

# Run with specific seed for reproducibility
forge test --fuzz-seed 42

# Run specific fuzz test
forge test --match-test testFuzz_Transfer
```

### Formatting

```bash
# Format Solidity files
forge fmt

# Check formatting without modifying
forge fmt --check

# Format specific file
forge fmt src/Token.sol
```

##  Network Configuration

### Anvil (Local Network)

```bash
# Start local node
anvil

# Start with specific configuration
anvil --port 8545 --chain-id 31337 --accounts 20

# Fork mainnet
anvil --fork-url $ETH_RPC_URL

# Fork at specific block
anvil --fork-url $ETH_RPC_URL --fork-block-number 18000000
```

### Cast Operations

```bash
# Get balance
cast balance 0x... --rpc-url $ETH_RPC_URL

# Send transaction
cast send 0x... "transfer(address,uint256)" 0x... 1000 --private-key $PRIVATE_KEY

# Call view function
cast call 0x... "balanceOf(address)" 0x... --rpc-url $ETH_RPC_URL

# Get transaction receipt
cast receipt 0x... --rpc-url $ETH_RPC_URL
```

##  Debugging Setup

### VS Code Configuration

Create `.vscode/settings.json`:

```json
{
  "solidity.compileUsingRemoteVersion": "v0.8.19+commit.7dd6d404",
  "solidity.formatter": "forge",
  "solidity.monoRepoSupport": true,
  "solidity.packageDefaultDependenciesContractsDirectory": "src",
  "solidity.packageDefaultDependenciesDirectory": "lib",
  "files.associations": {
    "*.sol": "solidity"
  },
  "editor.formatOnSave": true
}
```

### Launch Configuration

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Forge Test",
      "type": "node",
      "request": "launch",
      "program": "forge",
      "args": ["test", "-vvv"],
      "cwd": "${workspaceFolder}",
      "console": "integratedTerminal"
    }
  ]
}
```

##  Project Structure

### Recommended Structure

```
my-foundry-project/
├── foundry.toml           # Configuration
├── .env                   # Environment variables
├── .gitignore            # Git ignore patterns
├── README.md             # Project documentation
├── remappings.txt        # Import remappings
├── src/                  # Contract source files
│   ├── Token.sol
│   ├── interfaces/
│   └── libraries/
├── test/                 # Test files
│   ├── Token.t.sol
│   ├── invariant/
│   ├── fuzz/
│   └── integration/
├── script/               # Deployment scripts
│   ├── Deploy.s.sol
│   └── migrations/
├── lib/                  # Dependencies (git submodules)
│   ├── forge-std/
│   └── openzeppelin-contracts/
└── docs/                 # Documentation
```

### Import Remappings

Create `remappings.txt`:

```
@openzeppelin/contracts/=lib/openzeppelin-contracts/contracts/
@forge-std/=lib/forge-std/src/
@solmate/=lib/solmate/src/
ds-test/=lib/forge-std/lib/ds-test/src/
```

##  Verification Checklist

After setup, verify everything works:

```bash
# 1. Check Foundry installation
forge --version
cast --version
anvil --version

# 2. Build sample project
forge build

# 3. Run sample tests
forge test

# 4. Format code
forge fmt

# 5. Generate gas report
forge test --gas-report

# 6. Start local node
anvil &

# 7. Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# 8. Verify deployment worked
cast balance 0x... --rpc-url http://localhost:8545
```

##  Common Issues

### Issue 1: Permission Denied

```bash
# Fix: Update PATH and reload shell
echo 'export PATH="$HOME/.foundry/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue 2: Git Submodule Issues

```bash
# Fix: Initialize submodules
git submodule update --init --recursive

# Or clone with submodules
git clone --recursive <repo-url>
```

### Issue 3: Compilation Errors

```bash
# Fix: Clean and rebuild
forge clean
forge build
```

### Issue 4: RPC Connection Issues

```bash
# Fix: Check environment variables
echo $ETH_RPC_URL

# Test connection
cast block-number --rpc-url $ETH_RPC_URL
```

##  Next Steps

Once setup is complete:

1. Review the [Basic Examples](../examples/)
2. Try the [Testing Tutorial](../testing/)
3. Experiment with [Fuzzing](../fuzzing/)
4. Build your first [Project](../projects/)

---

**Setup complete!**  You're ready to experience the power of Foundry development.

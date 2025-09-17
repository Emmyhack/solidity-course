# Hardhat Setup Guide

Complete installation and configuration guide for professional Hardhat development environment.

## 🛠 Prerequisites

Before installing Hardhat, ensure you have:

- **Node.js**: Version 16.0.0 or higher
- **npm** or **yarn**: Package manager
- **Git**: Version control system
- **Code Editor**: VS Code recommended

### Check Prerequisites

```bash
# Check Node.js version
node --version
# Should output v16.0.0 or higher

# Check npm version
npm --version

# Check Git version
git --version
```

## 🚀 Installation

### Step 1: Create Project Directory

```bash
# Create and navigate to project directory
mkdir my-hardhat-project
cd my-hardhat-project

# Initialize package.json
npm init -y
```

### Step 2: Install Hardhat

```bash
# Install Hardhat as dev dependency
npm install --save-dev hardhat

# Initialize Hardhat project
npx hardhat
```

### Hardhat Initialization Options

When running `npx hardhat`, you'll see these options:

```
? What do you want to do?
❯ Create a JavaScript project
  Create a TypeScript project
  Create an empty hardhat.config.js
  Quit
```

**Recommended:** Choose "Create a TypeScript project" for better development experience.

### Step 3: Install Dependencies

```bash
# Install Hardhat toolbox (includes most common plugins)
npm install --save-dev @nomicfoundation/hardhat-toolbox

# Install OpenZeppelin contracts
npm install @openzeppelin/contracts

# Install additional testing utilities
npm install --save-dev @nomicfoundation/hardhat-network-helpers
npm install --save-dev @nomicfoundation/hardhat-chai-matchers
npm install --save-dev @nomicfoundation/hardhat-ethers
npm install --save-dev @typechain/hardhat
npm install --save-dev typechain

# Install Ethers.js
npm install ethers

# Install dotenv for environment variables
npm install --save-dev dotenv
```

### Step 4: VS Code Extensions

Install these VS Code extensions for better development experience:

```bash
# Install Solidity extension
code --install-extension JuanBlanco.solidity

# Install Hardhat extension
code --install-extension NomicFoundation.hardhat-solidity

# Install TypeScript extension
code --install-extension ms-vscode.vscode-typescript-next
```

## ⚙️ Configuration

### Basic hardhat.config.ts

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.19",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};

export default config;
```

### Advanced Configuration

```typescript
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "dotenv/config";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          viaIR: true, // Enable IR-based code generation
        },
      },
      {
        version: "0.8.18", // For legacy contracts
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      chainId: 31337,
      accounts: {
        count: 20,
        initialIndex: 0,
        mnemonic: "test test test test test test test test test test test junk",
        path: "m/44'/60'/0'/0",
        accountsBalance: "10000000000000000000000", // 10,000 ETH
      },
      forking: process.env.MAINNET_RPC_URL
        ? {
            url: process.env.MAINNET_RPC_URL,
            blockNumber: 18500000, // Pin to specific block for deterministic tests
          }
        : undefined,
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 31337,
    },
    goerli: {
      url: process.env.GOERLI_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 5,
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 11155111,
    },
    mainnet: {
      url: process.env.MAINNET_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 1,
      gasPrice: "auto",
    },
    polygon: {
      url: process.env.POLYGON_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 137,
    },
    arbitrum: {
      url: process.env.ARBITRUM_RPC_URL || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
      chainId: 42161,
    },
  },
  gasReporter: {
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    gasPrice: 20,
    coinmarketcap: process.env.COINMARKETCAP_API_KEY,
    outputFile: "gas-report.txt",
    noColors: true,
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      polygon: process.env.POLYGONSCAN_API_KEY || "",
      arbitrumOne: process.env.ARBISCAN_API_KEY || "",
    },
  },
  typechain: {
    outDir: "typechain-types",
    target: "ethers-v6",
    alwaysGenerateOverloads: false,
    externalArtifacts: ["externalArtifacts/*.json"],
  },
  mocha: {
    timeout: 60000, // 60 seconds
    reporter: "spec",
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;
```

### Environment Variables (.env)

```bash
# Create .env file
touch .env

# Add environment variables
cat > .env << 'EOF'
# RPC URLs
MAINNET_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY
GOERLI_RPC_URL=https://eth-goerli.alchemyapi.io/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.alchemyapi.io/v2/YOUR_KEY
POLYGON_RPC_URL=https://polygon-mainnet.alchemyapi.io/v2/YOUR_KEY
ARBITRUM_RPC_URL=https://arb-mainnet.alchemyapi.io/v2/YOUR_KEY

# Private keys (for deployment)
PRIVATE_KEY=0x...
DEPLOYER_PRIVATE_KEY=0x...

# API keys for verification
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_KEY
POLYGONSCAN_API_KEY=YOUR_POLYGONSCAN_KEY
ARBISCAN_API_KEY=YOUR_ARBISCAN_KEY

# Gas reporting
REPORT_GAS=true
COINMARKETCAP_API_KEY=YOUR_CMC_KEY

# Other configuration
NODE_ENV=development
EOF
```

### Package.json Scripts

```json
{
  "name": "my-hardhat-project",
  "version": "1.0.0",
  "description": "",
  "main": "index.js",
  "scripts": {
    "compile": "hardhat compile",
    "test": "hardhat test",
    "test:coverage": "hardhat coverage",
    "test:gas": "REPORT_GAS=true hardhat test",
    "deploy:localhost": "hardhat run scripts/deploy.ts --network localhost",
    "deploy:goerli": "hardhat run scripts/deploy.ts --network goerli",
    "deploy:mainnet": "hardhat run scripts/deploy.ts --network mainnet",
    "verify:goerli": "hardhat run scripts/verify.ts --network goerli",
    "verify:mainnet": "hardhat run scripts/verify.ts --network mainnet",
    "node": "hardhat node",
    "console": "hardhat console",
    "clean": "hardhat clean",
    "size": "hardhat size-contracts",
    "lint": "solhint 'contracts/**/*.sol'",
    "lint:fix": "solhint 'contracts/**/*.sol' --fix",
    "format": "prettier --write 'contracts/**/*.sol' 'test/**/*.ts' 'scripts/**/*.ts'",
    "typechain": "hardhat typechain"
  },
  "devDependencies": {
    "@nomicfoundation/hardhat-toolbox": "^3.0.0",
    "@nomicfoundation/hardhat-network-helpers": "^1.0.0",
    "@nomicfoundation/hardhat-chai-matchers": "^2.0.0",
    "@nomicfoundation/hardhat-ethers": "^3.0.0",
    "@typechain/hardhat": "^8.0.0",
    "@typechain/ethers-v6": "^0.4.0",
    "chai": "^4.2.0",
    "ethers": "^6.4.0",
    "hardhat": "^2.17.0",
    "hardhat-gas-reporter": "^1.0.8",
    "solidity-coverage": "^0.8.0",
    "typechain": "^8.1.0",
    "typescript": "^5.0.0",
    "dotenv": "^16.0.0",
    "@types/node": "^20.0.0",
    "@types/mocha": "^10.0.0",
    "ts-node": "^10.0.0"
  },
  "dependencies": {
    "@openzeppelin/contracts": "^4.9.0"
  }
}
```

## 📁 Project Structure

### Recommended Structure

```
my-hardhat-project/
├── contracts/               # Solidity contracts
│   ├── Token.sol
│   ├── interfaces/
│   │   └── IToken.sol
│   └── libraries/
│       └── SafeMath.sol
├── test/                    # Test files
│   ├── Token.test.ts
│   ├── fixtures/
│   │   └── deploy.ts
│   └── helpers/
│       └── utils.ts
├── scripts/                 # Deployment and utility scripts
│   ├── deploy.ts
│   ├── verify.ts
│   └── interact.ts
├── tasks/                   # Custom Hardhat tasks
│   └── accounts.ts
├── typechain-types/         # Generated TypeScript types
├── artifacts/               # Compiled contracts
├── cache/                   # Hardhat cache
├── coverage/                # Coverage reports
├── .env                     # Environment variables
├── .gitignore               # Git ignore file
├── hardhat.config.ts        # Hardhat configuration
├── package.json             # Node.js package configuration
├── tsconfig.json            # TypeScript configuration
└── README.md                # Project documentation
```

### TypeScript Configuration (tsconfig.json)

```json
{
  "compilerOptions": {
    "target": "es2020",
    "module": "commonjs",
    "lib": ["es2020"],
    "outDir": "./dist",
    "rootDir": "./",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "typeRoots": ["./node_modules/@types", "./typechain-types"]
  },
  "include": ["./scripts", "./test", "./tasks", "./typechain-types/**/*"],
  "exclude": ["node_modules", "artifacts", "cache", "coverage"]
}
```

### Git Ignore (.gitignore)

```gitignore
# Hardhat files
cache
artifacts
typechain-types

# Coverage directory used by nyc
coverage
coverage.json
*.lcov

# Dependency directories
node_modules/

# Environment variables
.env
.env.local
.env.*.local

# Logs
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Runtime data
pids
*.pid
*.seed
*.pid.lock

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db

# Build outputs
dist/
build/

# Gas reports
gas-report.txt
```

## 🔧 Basic Commands

### Compilation

```bash
# Compile contracts
npx hardhat compile

# Clean compilation artifacts
npx hardhat clean

# Force recompilation
npx hardhat compile --force
```

### Testing

```bash
# Run all tests
npx hardhat test

# Run specific test file
npx hardhat test test/Token.test.ts

# Run tests with gas reporting
REPORT_GAS=true npx hardhat test

# Run tests with coverage
npx hardhat coverage
```

### Local Network

```bash
# Start local Hardhat node
npx hardhat node

# Deploy to local network
npx hardhat run scripts/deploy.ts --network localhost

# Open Hardhat console
npx hardhat console --network localhost
```

### Deployment

```bash
# Deploy to testnet
npx hardhat run scripts/deploy.ts --network goerli

# Deploy to mainnet
npx hardhat run scripts/deploy.ts --network mainnet

# Verify contract on Etherscan
npx hardhat verify --network goerli CONTRACT_ADDRESS "Constructor arg 1" "Constructor arg 2"
```

## 🐛 Troubleshooting

### Common Issues

#### Issue 1: Module Not Found

```bash
# Error: Cannot find module '@nomicfoundation/hardhat-toolbox'
# Solution: Install missing dependencies
npm install --save-dev @nomicfoundation/hardhat-toolbox
```

#### Issue 2: TypeScript Errors

```bash
# Error: Type errors in test files
# Solution: Generate TypeChain types
npx hardhat typechain
```

#### Issue 3: Network Connection

```bash
# Error: Cannot connect to network
# Solution: Check RPC URL and network configuration
npx hardhat node --hostname 0.0.0.0 --port 8545
```

#### Issue 4: Gas Estimation

```bash
# Error: Gas estimation failed
# Solution: Check contract logic and increase gas limit
# In hardhat.config.ts:
networks: {
  hardhat: {
    gas: 12000000,
    blockGasLimit: 0x1fffffffffffff,
  }
}
```

### Debugging Tips

```bash
# Enable verbose logging
DEBUG=hardhat:* npx hardhat test

# Check network status
npx hardhat run scripts/check-network.ts --network localhost

# Inspect contract size
npx hardhat size-contracts

# Check account balances
npx hardhat run scripts/check-balances.ts --network localhost
```

## ✅ Verification

### Test Your Setup

Create a simple test to verify everything works:

```typescript
// test/setup-verification.test.ts
import { expect } from "chai";
import { ethers } from "hardhat";

describe("Setup Verification", function () {
  it("Should deploy a simple contract", async function () {
    const [owner] = await ethers.getSigners();

    // Deploy a simple contract
    const SimpleStorage = await ethers.getContractFactory("SimpleStorage");
    const simpleStorage = await SimpleStorage.deploy();

    await simpleStorage.set(42);
    expect(await simpleStorage.get()).to.equal(42);
  });
});
```

Run the verification:

```bash
npx hardhat test test/setup-verification.test.ts
```

## 🚀 Next Steps

Once your Hardhat environment is set up:

1. **Create Your First Contract**: Start with a simple ERC20 token
2. **Write Tests**: Practice with the testing framework
3. **Deploy Locally**: Use the local Hardhat network
4. **Deploy to Testnet**: Try Goerli or Sepolia
5. **Explore Plugins**: Add more functionality with Hardhat plugins

## 📚 Additional Resources

- [Hardhat Documentation](https://hardhat.org/docs)
- [Ethers.js Documentation](https://docs.ethers.io/)
- [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)
- [Hardhat Tutorial](https://hardhat.org/tutorial)

---

**Setup complete!** 🎉 You're ready to build professional smart contracts with Hardhat.

# Module 5: Hardhat Development

Master professional Solidity development with Hardhat, the most popular Ethereum development environment.

##  Module Overview

This comprehensive module covers Hardhat development from setup to production deployment. You'll learn to build, test, and deploy smart contracts using industry-standard tools and workflows.

**Duration:** 28-35 hours  
**Difficulty:** Intermediate  
**Prerequisites:** Modules 1-4

##  Learning Objectives

By the end of this module, you will be able to:

- Set up and configure Hardhat development environment
- Write comprehensive test suites with Mocha/Chai
- Deploy contracts to multiple networks
- Verify contracts on block explorers
- Use advanced Hardhat plugins and tools
- Implement CI/CD pipelines for smart contracts
- Debug and optimize contract gas usage
- Manage deployments across environments

##  Topics Covered

### 1. Hardhat Setup & Configuration

- Project initialization and structure
- Hardhat configuration file
- Network configuration
- Environment variables and secrets management
- TypeScript integration

### 2. Testing Framework

- Writing unit tests with Mocha/Chai
- Integration testing strategies
- Test fixtures and helpers
- Coverage analysis
- Gas reporting
- Parallel test execution

### 3. Deployment & Verification

- Deployment scripts and automation
- Multi-network deployment
- Contract verification on Etherscan
- Upgrade patterns and proxy deployment
- Environment-specific configurations

### 4. Advanced Features

- Custom tasks and plugins
- Forking mainnet for testing
- Time manipulation in tests
- Event testing and filtering
- Contract interaction scripts

##  Development Environment

### Required Tools

```bash
# Node.js (v16+)
node --version

# npm or yarn
npm --version

# Git
git --version
```

### Project Setup

```bash
# Create new Hardhat project
npx hardhat

# Install dependencies
npm install --save-dev hardhat @nomicfoundation/hardhat-toolbox

# Install OpenZeppelin contracts
npm install @openzeppelin/contracts
```

##  Module Structure

- [**Setup Guide**](./setup/) - Complete environment setup
- [**Examples**](./examples/) - Sample projects and configurations
- [**Projects**](./projects/) - Build and deploy real contracts
- [**Testing**](./testing/) - Comprehensive testing strategies
- [**Deployment**](./deployment/) - Production deployment guides
- [**Solutions**](./solutions/) - Reference implementations

##  Getting Started

1. Follow the [Setup Guide](./setup/README.md)
2. Explore [Basic Project Structure](./examples/01-basic-setup/)
3. Build the [DeFi Lending Protocol](./projects/01-lending-protocol/)
4. Complete all testing assignments

##  Estimated Time

- **Setup & Configuration**: 2-3 hours
- **Testing Framework**: 4-5 hours
- **Deployment & Scripts**: 3-4 hours
- **Projects**: 8-10 hours
- **Total**: 17-22 hours

##  Prerequisites

- Completed Modules 1-4
- Node.js and npm familiarity
- Basic command line knowledge
- Understanding of JavaScript/TypeScript (helpful)

---

**Ready for professional development?** Start with [Hardhat Setup](./setup/README.md) 

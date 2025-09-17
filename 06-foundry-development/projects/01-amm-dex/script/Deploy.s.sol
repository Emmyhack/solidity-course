// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../src/AMMDEX.sol";
import "../src/MockERC20.sol";

/**
 * @title AMM DEX Deployment Script
 * @dev Professional deployment script demonstrating Foundry deployment patterns
 * @notice This script handles deployment across different networks with proper configuration
 */
contract DeployAMMDEX is Script {
    // ======================
    // CONFIGURATION
    // ======================

    struct DeploymentConfig {
        string tokenAName;
        string tokenASymbol;
        string tokenBName;
        string tokenBSymbol;
        uint256 initialMintA;
        uint256 initialMintB;
        uint256 initialLiquidityA;
        uint256 initialLiquidityB;
        string lpTokenName;
        string lpTokenSymbol;
    }

    // ======================
    // NETWORK CONFIGURATIONS
    // ======================

    function getConfig() internal view returns (DeploymentConfig memory) {
        uint256 chainId = block.chainid;

        if (chainId == 1) {
            // Mainnet
            return
                DeploymentConfig({
                    tokenAName: "Wrapped Ether",
                    tokenASymbol: "WETH",
                    tokenBName: "USD Coin",
                    tokenBSymbol: "USDC",
                    initialMintA: 1_000e18,
                    initialMintB: 1_000_000e6, // USDC has 6 decimals
                    initialLiquidityA: 10e18,
                    initialLiquidityB: 30_000e6,
                    lpTokenName: "WETH-USDC LP",
                    lpTokenSymbol: "WETH-USDC-LP"
                });
        } else if (chainId == 11155111) {
            // Sepolia
            return
                DeploymentConfig({
                    tokenAName: "Test Token A",
                    tokenASymbol: "TESTA",
                    tokenBName: "Test Token B",
                    tokenBSymbol: "TESTB",
                    initialMintA: 1_000_000e18,
                    initialMintB: 1_000_000e18,
                    initialLiquidityA: 100_000e18,
                    initialLiquidityB: 100_000e18,
                    lpTokenName: "Test AMM LP",
                    lpTokenSymbol: "TEST-LP"
                });
        } else {
            // Local/Anvil
            return
                DeploymentConfig({
                    tokenAName: "Mock Token A",
                    tokenASymbol: "MOCKA",
                    tokenBName: "Mock Token B",
                    tokenBSymbol: "MOCKB",
                    initialMintA: 1_000_000e18,
                    initialMintB: 1_000_000e18,
                    initialLiquidityA: 100_000e18,
                    initialLiquidityB: 100_000e18,
                    lpTokenName: "Mock AMM LP",
                    lpTokenSymbol: "MOCK-LP"
                });
        }
    }

    // ======================
    // DEPLOYMENT FUNCTION
    // ======================

    function run() external {
        DeploymentConfig memory config = getConfig();

        console.log("Starting AMM DEX Deployment on chain:", block.chainid);
        console.log("Deploying with configuration:");
        console.log(
            "   Token A:",
            config.tokenAName,
            "(",
            config.tokenASymbol,
            ")"
        );
        console.log(
            "   Token B:",
            config.tokenBName,
            "(",
            config.tokenBSymbol,
            ")"
        );

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deployer address:", deployer);
        console.log("Deployer balance:", deployer.balance / 1e18, "ETH");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy tokens (or use existing ones on mainnet)
        address tokenA;
        address tokenB;

        if (block.chainid == 1) {
            // Use existing tokens on mainnet
            tokenA = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH
            tokenB = 0xA0b86a33E6417c7C4a7D95FF4A9D925EF8FC9eec; // USDC
            console.log("Using existing mainnet tokens");
        } else {
            // Deploy mock tokens for testnets/local
            MockERC20 deployedTokenA = new MockERC20(
                config.tokenAName,
                config.tokenASymbol,
                18,
                config.initialMintA
            );

            MockERC20 deployedTokenB = new MockERC20(
                config.tokenBName,
                config.tokenBSymbol,
                18,
                config.initialMintB
            );

            tokenA = address(deployedTokenA);
            tokenB = address(deployedTokenB);

            console.log("Deployed Token A:", tokenA);
            console.log("Deployed Token B:", tokenB);
        }

        // Ensure proper token ordering
        if (tokenA > tokenB) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        // Deploy AMM DEX
        AMMDEX amm = new AMMDEX(
            tokenA,
            tokenB,
            config.lpTokenName,
            config.lpTokenSymbol
        );

        console.log("Deployed AMM DEX:", address(amm));

        // Add initial liquidity if not on mainnet
        if (block.chainid != 1) {
            _addInitialLiquidity(amm, tokenA, tokenB, config, deployer);
        }

        // Set reasonable fees
        amm.setSwapFee(30); // 0.3%
        amm.setFlashLoanFee(9); // 0.09%

        vm.stopBroadcast();

        console.log("Deployment completed successfully!");
        console.log("Contract Addresses:");
        console.log("   AMM DEX:", address(amm));
        console.log("   Token A:", tokenA);
        console.log("   Token B:", tokenB);

        _saveDeploymentInfo(address(amm), tokenA, tokenB);
        _verifyDeployment(amm, tokenA, tokenB);
    }

    // ======================
    // HELPER FUNCTIONS
    // ======================

    function _addInitialLiquidity(
        AMMDEX amm,
        address tokenA,
        address tokenB,
        DeploymentConfig memory config,
        address deployer
    ) internal {
        console.log("Adding initial liquidity...");

        // Approve tokens
        MockERC20(tokenA).approve(address(amm), config.initialLiquidityA);
        MockERC20(tokenB).approve(address(amm), config.initialLiquidityB);

        // Add liquidity
        (uint256 amountA, uint256 amountB, uint256 liquidity) = amm
            .addLiquidity(
                config.initialLiquidityA,
                config.initialLiquidityB,
                0,
                0,
                deployer,
                block.timestamp + 300
            );

        console.log("   Added Token A:", amountA / 1e18, config.tokenASymbol);
        console.log("   Added Token B:", amountB / 1e18, config.tokenBSymbol);
        console.log("   LP Tokens Minted:", liquidity / 1e18);
    }

    function _saveDeploymentInfo(
        address amm,
        address tokenA,
        address tokenB
    ) internal {
        string memory chainIdStr = vm.toString(block.chainid);
        string memory json = string.concat(
            "{\n",
            '  "chainId": ',
            chainIdStr,
            ",\n",
            '  "amm": "',
            vm.toString(amm),
            '",\n',
            '  "tokenA": "',
            vm.toString(tokenA),
            '",\n',
            '  "tokenB": "',
            vm.toString(tokenB),
            '",\n',
            '  "deployedAt": ',
            vm.toString(block.timestamp),
            ",\n",
            '  "blockNumber": ',
            vm.toString(block.number),
            "\n",
            "}"
        );

        string memory filename = string.concat(
            "deployments/",
            chainIdStr,
            ".json"
        );
        vm.writeFile(filename, json);
        console.log("Deployment info saved to:", filename);
    }

    function _verifyDeployment(
        AMMDEX amm,
        address tokenA,
        address tokenB
    ) internal {
        console.log("Verifying deployment...");

        // Verify token addresses
        require(address(amm.token0()) == tokenA, "Token A mismatch");
        require(address(amm.token1()) == tokenB, "Token B mismatch");

        // Verify ownership
        require(
            amm.owner() == vm.addr(vm.envUint("PRIVATE_KEY")),
            "Owner mismatch"
        );

        // Verify initial state
        (uint112 reserve0, uint112 reserve1, ) = amm.getReserves();
        console.log("   Reserve A:", reserve0 / 1e18);
        console.log("   Reserve B:", reserve1 / 1e18);
        console.log("   Total Supply:", amm.totalSupply() / 1e18);

        console.log("Deployment verification passed!");
    }
}

/**
 * @title Quick Local Deployment Script
 * @dev Simplified script for local testing
 */
contract QuickDeploy is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy tokens
        MockERC20 tokenA = new MockERC20("Token A", "TKNA", 18, 1_000_000e18);
        MockERC20 tokenB = new MockERC20("Token B", "TKNB", 18, 1_000_000e18);

        // Ensure ordering
        if (address(tokenA) > address(tokenB)) {
            (tokenA, tokenB) = (tokenB, tokenA);
        }

        // Deploy AMM
        AMMDEX amm = new AMMDEX(
            address(tokenA),
            address(tokenB),
            "Quick LP",
            "QUICK-LP"
        );

        // Add liquidity
        tokenA.approve(address(amm), 100_000e18);
        tokenB.approve(address(amm), 100_000e18);

        amm.addLiquidity(
            100_000e18,
            100_000e18,
            0,
            0,
            msg.sender,
            block.timestamp + 300
        );

        vm.stopBroadcast();

        console.log("AMM:", address(amm));
        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
    }
}

/**
 * @title Deployment Upgrade Script
 * @dev Script for upgrading AMM parameters
 */
contract UpgradeAMM is Script {
    function run() external {
        address ammAddress = vm.envAddress("AMM_ADDRESS");
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        AMMDEX amm = AMMDEX(ammAddress);

        // Update fees if needed
        uint256 newSwapFee = vm.envOr("NEW_SWAP_FEE", uint256(30));
        uint256 newFlashLoanFee = vm.envOr("NEW_FLASHLOAN_FEE", uint256(9));

        if (amm.swapFee() != newSwapFee) {
            amm.setSwapFee(newSwapFee);
            console.log("Updated swap fee to:", newSwapFee);
        }

        if (amm.flashloanFee() != newFlashLoanFee) {
            amm.setFlashLoanFee(newFlashLoanFee);
            console.log("Updated flash loan fee to:", newFlashLoanFee);
        }

        vm.stopBroadcast();

        console.log("AMM upgrade completed!");
    }
}

/**
 *  DEPLOYMENT SCRIPT FEATURES:
 *
 * 1. MULTI-NETWORK SUPPORT:
 *    - Mainnet, testnet, and local configurations
 *    - Environment-specific token deployments
 *    - Proper network detection and handling
 *
 * 2. PROFESSIONAL PATTERNS:
 *    - Private key management via environment
 *    - Deployment verification and validation
 *    - JSON output for integration
 *    - Comprehensive logging
 *
 * 3. FOUNDRY INTEGRATION:
 *    - forge script deployment
 *    - Environment variable usage
 *    - Broadcast management
 *    - Chain-specific logic
 *
 * 4. PRODUCTION READY:
 *    - Error handling and validation
 *    - Gas optimization considerations
 *    - Upgrade script capabilities
 *    - Documentation and comments
 *
 *  USAGE EXAMPLES:
 *
 * # Local deployment with Anvil:
 * forge script script/Deploy.s.sol:QuickDeploy --fork-url http://localhost:8545 --broadcast
 *
 * # Sepolia deployment:
 * forge script script/Deploy.s.sol:DeployAMMDEX --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 *
 * # Mainnet deployment (be careful!):
 * forge script script/Deploy.s.sol:DeployAMMDEX --rpc-url $MAINNET_RPC_URL --broadcast --verify --slow
 *
 * # Upgrade existing deployment:
 * AMM_ADDRESS=0x... forge script script/Deploy.s.sol:UpgradeAMM --rpc-url $RPC_URL --broadcast
 */

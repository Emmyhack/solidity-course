import { ethers } from "hardhat";
import { Contract, ContractTransactionResponse } from "ethers";

async function main() {
  console.log("🚀 Starting deployment of DeFi Lending Protocol...\n");

  // Get deployment account
  const [deployer] = await ethers.getSigners();
  console.log("📋 Deploying contracts with account:", deployer.address);
  console.log("💰 Account balance:", ethers.formatEther(await deployer.provider.getBalance(deployer.address)), "ETH\n");

  // Deploy mock tokens for testing (only on testnets/local)
  const network = await ethers.provider.getNetwork();
  const isMainnet = network.chainId === 1n;
  
  let dai: Contract, usdc: Contract, weth: Contract;
  
  if (!isMainnet) {
    console.log("🏗️  Deploying mock tokens for testing...");
    
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    
    // Deploy DAI mock
    console.log("   Deploying Mock DAI...");
    dai = await MockERC20Factory.deploy(
      "Dai Stablecoin",
      "DAI",
      18,
      ethers.parseEther("1000000") // 1M DAI
    );
    await dai.waitForDeployment();
    console.log("   ✅ Mock DAI deployed to:", await dai.getAddress());
    
    // Deploy USDC mock
    console.log("   Deploying Mock USDC...");
    usdc = await MockERC20Factory.deploy(
      "USD Coin",
      "USDC",
      6,
      ethers.parseUnits("1000000", 6) // 1M USDC
    );
    await usdc.waitForDeployment();
    console.log("   ✅ Mock USDC deployed to:", await usdc.getAddress());
    
    // Deploy WETH mock
    console.log("   Deploying Mock WETH...");
    weth = await MockERC20Factory.deploy(
      "Wrapped Ether",
      "WETH",
      18,
      ethers.parseEther("10000") // 10K WETH
    );
    await weth.waitForDeployment();
    console.log("   ✅ Mock WETH deployed to:", await weth.getAddress());
    console.log();
  } else {
    // Use real token addresses on mainnet
    console.log("🌐 Using real token addresses on mainnet...");
    dai = { getAddress: () => "0x6B175474E89094C44Da98b954EedeAC495271d0F" }; // Real DAI
    usdc = { getAddress: () => "0xA0b86a33E6411bF7c8B48a0e8df8C3b73A1E87E6" }; // Real USDC
    weth = { getAddress: () => "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2" }; // Real WETH
    console.log("   Using DAI at:", await dai.getAddress());
    console.log("   Using USDC at:", await usdc.getAddress());
    console.log("   Using WETH at:", await weth.getAddress());
    console.log();
  }

  // Deploy the main lending protocol
  console.log("🏦 Deploying Lending Protocol...");
  const LendingProtocolFactory = await ethers.getContractFactory("LendingProtocol");
  const lendingProtocol = await LendingProtocolFactory.deploy();
  await lendingProtocol.waitForDeployment();
  
  const protocolAddress = await lendingProtocol.getAddress();
  console.log("   ✅ Lending Protocol deployed to:", protocolAddress);
  console.log();

  // Configure supported assets
  console.log("⚙️  Configuring supported assets...");
  
  const assets = [
    {
      name: "DAI",
      address: await dai.getAddress(),
      collateralFactor: 8000, // 80%
      liquidationBonus: 500,  // 5%
      price: ethers.parseEther("1") // 1 ETH = 1 DAI (simplified)
    },
    {
      name: "USDC",
      address: await usdc.getAddress(),
      collateralFactor: 8500, // 85%
      liquidationBonus: 500,  // 5%
      price: ethers.parseEther("1") // 1 ETH = 1 USDC (simplified)
    },
    {
      name: "WETH",
      address: await weth.getAddress(),
      collateralFactor: 7500, // 75%
      liquidationBonus: 1000, // 10%
      price: ethers.parseEther("1") // 1 ETH = 1 WETH
    }
  ];

  for (const asset of assets) {
    console.log(`   Adding ${asset.name} as supported asset...`);
    const tx: ContractTransactionResponse = await lendingProtocol.addAsset(
      asset.address,
      asset.collateralFactor,
      asset.liquidationBonus,
      asset.price
    );
    await tx.wait();
    console.log(`   ✅ ${asset.name} configured with ${asset.collateralFactor / 100}% collateral factor`);
  }
  console.log();

  // Initial setup for testing (only on testnets/local)
  if (!isMainnet) {
    console.log("🎯 Setting up test environment...");
    
    // Mint tokens to deployer for testing
    const mintAmount = ethers.parseEther("10000");
    
    if (dai.mint) {
      await dai.mint(deployer.address, mintAmount);
      console.log("   ✅ Minted 10,000 DAI to deployer");
    }
    
    if (usdc.mint) {
      await usdc.mint(deployer.address, ethers.parseUnits("10000", 6));
      console.log("   ✅ Minted 10,000 USDC to deployer");
    }
    
    if (weth.mint) {
      await weth.mint(deployer.address, mintAmount);
      console.log("   ✅ Minted 10,000 WETH to deployer");
    }
    console.log();
  }

  // Verify deployment
  console.log("🔍 Verifying deployment...");
  const supportedAssets = await lendingProtocol.getSupportedAssets();
  console.log("   ✅ Supported assets count:", supportedAssets.length);
  
  for (let i = 0; i < supportedAssets.length; i++) {
    const assetData = await lendingProtocol.getAssetData(supportedAssets[i]);
    console.log(`   ✅ Asset ${i + 1}: ${supportedAssets[i]} (Active: ${assetData.isActive})`);
  }
  console.log();

  // Display deployment summary
  console.log("📋 DEPLOYMENT SUMMARY");
  console.log("====================");
  console.log("🏦 Lending Protocol:", protocolAddress);
  if (!isMainnet) {
    console.log("🪙 Mock DAI:", await dai.getAddress());
    console.log("🪙 Mock USDC:", await usdc.getAddress());
    console.log("🪙 Mock WETH:", await weth.getAddress());
  }
  console.log("👤 Owner:", deployer.address);
  console.log("🌐 Network:", network.name, `(Chain ID: ${network.chainId})`);
  console.log();

  // Gas usage summary
  console.log("⛽ GAS USAGE SUMMARY");
  console.log("===================");
  const finalBalance = await deployer.provider.getBalance(deployer.address);
  console.log("💰 Final balance:", ethers.formatEther(finalBalance), "ETH");
  console.log();

  // Next steps
  console.log("🎯 NEXT STEPS");
  console.log("=============");
  console.log("1. Verify contracts on Etherscan (if on testnet/mainnet)");
  console.log("2. Set up a proper price oracle (replace mock prices)");
  console.log("3. Configure governance and timelock mechanisms");
  console.log("4. Run comprehensive tests: `npm run test`");
  console.log("5. Set up monitoring and alerting");
  console.log();

  if (!isMainnet) {
    console.log("🧪 TESTING COMMANDS");
    console.log("==================");
    console.log("npm run test              # Run all tests");
    console.log("npm run test:coverage     # Run with coverage");
    console.log("npm run test:gas          # Run with gas reporting");
    console.log();
  }

  console.log("✅ Deployment completed successfully! 🎉");

  return {
    lendingProtocol: protocolAddress,
    tokens: !isMainnet ? {
      dai: await dai.getAddress(),
      usdc: await usdc.getAddress(),
      weth: await weth.getAddress()
    } : undefined
  };
}

// Execute deployment
main()
  .then((addresses) => {
    console.log("\n🔗 Contract addresses saved for verification:");
    console.log(JSON.stringify(addresses, null, 2));
    process.exit(0);
  })
  .catch((error) => {
    console.error("❌ Deployment failed:");
    console.error(error);
    process.exit(1);
  });
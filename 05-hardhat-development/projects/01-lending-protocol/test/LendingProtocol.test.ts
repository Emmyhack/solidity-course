import { ethers } from "hardhat";
import { expect } from "chai";
import { LendingProtocol, MockERC20 } from "../typechain-types";
import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("LendingProtocol", function () {
  let lendingProtocol: LendingProtocol;
  let dai: MockERC20;
  let usdc: MockERC20;
  let weth: MockERC20;
  let owner: SignerWithAddress;
  let user1: SignerWithAddress;
  let user2: SignerWithAddress;
  let liquidator: SignerWithAddress;

  const DAI_PRICE = ethers.parseEther("1"); // 1 ETH = 1 DAI (simplified)
  const USDC_PRICE = ethers.parseEther("1"); // 1 ETH = 1 USDC (simplified)
  const WETH_PRICE = ethers.parseEther("1"); // 1 ETH = 1 WETH

  const INITIAL_MINT = ethers.parseEther("10000"); // 10,000 tokens

  beforeEach(async function () {
    [owner, user1, user2, liquidator] = await ethers.getSigners();

    // Deploy mock tokens
    const MockERC20Factory = await ethers.getContractFactory("MockERC20");
    
    dai = await MockERC20Factory.deploy("Dai Stablecoin", "DAI", 18, INITIAL_MINT);
    usdc = await MockERC20Factory.deploy("USD Coin", "USDC", 6, INITIAL_MINT / BigInt(1e12)); // 6 decimals
    weth = await MockERC20Factory.deploy("Wrapped Ether", "WETH", 18, INITIAL_MINT);

    // Deploy lending protocol
    const LendingProtocolFactory = await ethers.getContractFactory("LendingProtocol");
    lendingProtocol = await LendingProtocolFactory.deploy();

    // Add supported assets
    await lendingProtocol.addAsset(
      await dai.getAddress(),
      8000, // 80% collateral factor
      500,  // 5% liquidation bonus
      DAI_PRICE
    );

    await lendingProtocol.addAsset(
      await usdc.getAddress(),
      8500, // 85% collateral factor
      500,  // 5% liquidation bonus
      USDC_PRICE
    );

    await lendingProtocol.addAsset(
      await weth.getAddress(),
      7500, // 75% collateral factor
      1000, // 10% liquidation bonus
      WETH_PRICE
    );

    // Distribute tokens to users
    await dai.mint(user1.address, ethers.parseEther("1000"));
    await dai.mint(user2.address, ethers.parseEther("1000"));
    await dai.mint(liquidator.address, ethers.parseEther("1000"));

    await usdc.mint(user1.address, ethers.parseUnits("1000", 6));
    await usdc.mint(user2.address, ethers.parseUnits("1000", 6));

    await weth.mint(user1.address, ethers.parseEther("10"));
    await weth.mint(user2.address, ethers.parseEther("10"));
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await lendingProtocol.owner()).to.equal(owner.address);
    });

    it("Should have correct supported assets", async function () {
      const supportedAssets = await lendingProtocol.getSupportedAssets();
      expect(supportedAssets).to.have.length(3);
      expect(supportedAssets).to.include(await dai.getAddress());
      expect(supportedAssets).to.include(await usdc.getAddress());
      expect(supportedAssets).to.include(await weth.getAddress());
    });

    it("Should have correct asset configurations", async function () {
      const daiData = await lendingProtocol.getAssetData(await dai.getAddress());
      expect(daiData.collateralFactor).to.equal(8000);
      expect(daiData.liquidationBonus).to.equal(500);
      expect(daiData.isActive).to.be.true;
    });
  });

  describe("Deposits", function () {
    it("Should allow users to deposit DAI", async function () {
      const depositAmount = ethers.parseEther("100");
      
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), depositAmount);
      
      await expect(lendingProtocol.connect(user1).deposit(await dai.getAddress(), depositAmount))
        .to.emit(lendingProtocol, "Deposit")
        .withArgs(user1.address, await dai.getAddress(), depositAmount, await time.latest() + 1);

      const userBalance = await lendingProtocol.getUserDepositBalance(await dai.getAddress(), user1.address);
      expect(userBalance).to.equal(depositAmount);
    });

    it("Should update total deposits", async function () {
      const depositAmount = ethers.parseEther("100");
      
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), depositAmount);
      await lendingProtocol.connect(user1).deposit(await dai.getAddress(), depositAmount);

      const assetData = await lendingProtocol.getAssetData(await dai.getAddress());
      expect(assetData.totalDeposits).to.equal(depositAmount);
    });

    it("Should revert when depositing unsupported asset", async function () {
      const unsupportedToken = await ethers.getContractFactory("MockERC20");
      const token = await unsupportedToken.deploy("Unsupported", "UNS", 18, INITIAL_MINT);
      
      await expect(
        lendingProtocol.connect(user1).deposit(await token.getAddress(), ethers.parseEther("100"))
      ).to.be.revertedWithCustomError(lendingProtocol, "AssetNotSupported");
    });

    it("Should revert when depositing zero amount", async function () {
      await expect(
        lendingProtocol.connect(user1).deposit(await dai.getAddress(), 0)
      ).to.be.revertedWithCustomError(lendingProtocol, "InvalidAmount");
    });
  });

  describe("Withdrawals", function () {
    beforeEach(async function () {
      // Setup: User1 deposits DAI
      const depositAmount = ethers.parseEther("100");
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), depositAmount);
      await lendingProtocol.connect(user1).deposit(await dai.getAddress(), depositAmount);
    });

    it("Should allow users to withdraw deposited assets", async function () {
      const withdrawAmount = ethers.parseEther("50");
      
      await expect(lendingProtocol.connect(user1).withdraw(await dai.getAddress(), withdrawAmount))
        .to.emit(lendingProtocol, "Withdraw")
        .withArgs(user1.address, await dai.getAddress(), withdrawAmount, await time.latest() + 1);

      const userBalance = await lendingProtocol.getUserDepositBalance(await dai.getAddress(), user1.address);
      expect(userBalance).to.equal(ethers.parseEther("50"));
    });

    it("Should revert when withdrawing more than deposited", async function () {
      const withdrawAmount = ethers.parseEther("200");
      
      await expect(
        lendingProtocol.connect(user1).withdraw(await dai.getAddress(), withdrawAmount)
      ).to.be.revertedWithCustomError(lendingProtocol, "InsufficientBalance");
    });

    it("Should update total deposits after withdrawal", async function () {
      const withdrawAmount = ethers.parseEther("50");
      await lendingProtocol.connect(user1).withdraw(await dai.getAddress(), withdrawAmount);

      const assetData = await lendingProtocol.getAssetData(await dai.getAddress());
      expect(assetData.totalDeposits).to.equal(ethers.parseEther("50"));
    });
  });

  describe("Borrowing", function () {
    beforeEach(async function () {
      // Setup: User1 deposits WETH as collateral
      const collateralAmount = ethers.parseEther("1");
      await weth.connect(user1).approve(await lendingProtocol.getAddress(), collateralAmount);
      await lendingProtocol.connect(user1).deposit(await weth.getAddress(), collateralAmount);

      // User2 deposits DAI to provide liquidity
      const liquidityAmount = ethers.parseEther("1000");
      await dai.connect(user2).approve(await lendingProtocol.getAddress(), liquidityAmount);
      await lendingProtocol.connect(user2).deposit(await dai.getAddress(), liquidityAmount);
    });

    it("Should allow users to borrow against collateral", async function () {
      const borrowAmount = ethers.parseEther("500"); // 50% of collateral value
      
      await expect(lendingProtocol.connect(user1).borrow(await dai.getAddress(), borrowAmount))
        .to.emit(lendingProtocol, "Borrow");

      const userBorrow = await lendingProtocol.getUserBorrowBalance(await dai.getAddress(), user1.address);
      expect(userBorrow).to.equal(borrowAmount);
    });

    it("Should update total borrows", async function () {
      const borrowAmount = ethers.parseEther("500");
      await lendingProtocol.connect(user1).borrow(await dai.getAddress(), borrowAmount);

      const assetData = await lendingProtocol.getAssetData(await dai.getAddress());
      expect(assetData.totalBorrows).to.equal(borrowAmount);
    });

    it("Should revert when borrowing without sufficient collateral", async function () {
      const borrowAmount = ethers.parseEther("900"); // More than allowed by collateral factor
      
      await expect(
        lendingProtocol.connect(user1).borrow(await dai.getAddress(), borrowAmount)
      ).to.be.revertedWith("Insufficient collateral");
    });

    it("Should revert when borrowing more than available liquidity", async function () {
      // Try to borrow more than what's available in the pool
      const borrowAmount = ethers.parseEther("1500");
      
      await expect(
        lendingProtocol.connect(user1).borrow(await dai.getAddress(), borrowAmount)
      ).to.be.revertedWithCustomError(lendingProtocol, "InsufficientBalance");
    });
  });

  describe("Repayment", function () {
    beforeEach(async function () {
      // Setup: User1 deposits WETH and borrows DAI
      const collateralAmount = ethers.parseEther("1");
      await weth.connect(user1).approve(await lendingProtocol.getAddress(), collateralAmount);
      await lendingProtocol.connect(user1).deposit(await weth.getAddress(), collateralAmount);

      const liquidityAmount = ethers.parseEther("1000");
      await dai.connect(user2).approve(await lendingProtocol.getAddress(), liquidityAmount);
      await lendingProtocol.connect(user2).deposit(await dai.getAddress(), liquidityAmount);

      const borrowAmount = ethers.parseEther("500");
      await lendingProtocol.connect(user1).borrow(await dai.getAddress(), borrowAmount);
    });

    it("Should allow users to repay borrowed assets", async function () {
      const repayAmount = ethers.parseEther("250");
      
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), repayAmount);
      
      await expect(lendingProtocol.connect(user1).repay(await dai.getAddress(), repayAmount))
        .to.emit(lendingProtocol, "Repay")
        .withArgs(user1.address, await dai.getAddress(), repayAmount, await time.latest() + 1);

      const userBorrow = await lendingProtocol.getUserBorrowBalance(await dai.getAddress(), user1.address);
      expect(userBorrow).to.equal(ethers.parseEther("250"));
    });

    it("Should allow full repayment", async function () {
      const userBorrowBefore = await lendingProtocol.getUserBorrowBalance(await dai.getAddress(), user1.address);
      
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), userBorrowBefore);
      await lendingProtocol.connect(user1).repay(await dai.getAddress(), userBorrowBefore);

      const userBorrowAfter = await lendingProtocol.getUserBorrowBalance(await dai.getAddress(), user1.address);
      expect(userBorrowAfter).to.equal(0);
    });

    it("Should update total borrows after repayment", async function () {
      const repayAmount = ethers.parseEther("250");
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), repayAmount);
      await lendingProtocol.connect(user1).repay(await dai.getAddress(), repayAmount);

      const assetData = await lendingProtocol.getAssetData(await dai.getAddress());
      expect(assetData.totalBorrows).to.equal(ethers.parseEther("250"));
    });
  });

  describe("Liquidation", function () {
    beforeEach(async function () {
      // Setup complex scenario for liquidation
      const collateralAmount = ethers.parseEther("1");
      await weth.connect(user1).approve(await lendingProtocol.getAddress(), collateralAmount);
      await lendingProtocol.connect(user1).deposit(await weth.getAddress(), collateralAmount);

      const liquidityAmount = ethers.parseEther("1000");
      await dai.connect(user2).approve(await lendingProtocol.getAddress(), liquidityAmount);
      await lendingProtocol.connect(user2).deposit(await dai.getAddress(), liquidityAmount);

      // User1 borrows close to the limit
      const borrowAmount = ethers.parseEther("700"); // Close to 75% of collateral
      await lendingProtocol.connect(user1).borrow(await dai.getAddress(), borrowAmount);
    });

    it("Should revert liquidation of healthy positions", async function () {
      // Position should be healthy initially
      await expect(
        lendingProtocol.connect(liquidator).liquidate(
          user1.address,
          await dai.getAddress(),
          ethers.parseEther("100"),
          await weth.getAddress()
        )
      ).to.be.revertedWithCustomError(lendingProtocol, "HealthyPosition");
    });

    it("Should allow liquidation when health factor drops", async function () {
      // Simulate price drop by updating WETH price
      await lendingProtocol.updatePrice(await weth.getAddress(), ethers.parseEther("0.8"));

      const debtToCover = ethers.parseEther("100");
      await dai.connect(liquidator).approve(await lendingProtocol.getAddress(), debtToCover);

      await expect(
        lendingProtocol.connect(liquidator).liquidate(
          user1.address,
          await dai.getAddress(),
          debtToCover,
          await weth.getAddress()
        )
      ).to.emit(lendingProtocol, "Liquidation");
    });
  });

  describe("Interest Rate Model", function () {
    it("Should calculate correct utilization rate", async function () {
      // Setup: Deposit and borrow to create utilization
      const depositAmount = ethers.parseEther("1000");
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), depositAmount);
      await lendingProtocol.connect(user1).deposit(await dai.getAddress(), depositAmount);

      // Setup collateral for borrowing
      const collateralAmount = ethers.parseEther("10");
      await weth.connect(user2).approve(await lendingProtocol.getAddress(), collateralAmount);
      await lendingProtocol.connect(user2).deposit(await weth.getAddress(), collateralAmount);

      const borrowAmount = ethers.parseEther("500"); // 50% utilization
      await lendingProtocol.connect(user2).borrow(await dai.getAddress(), borrowAmount);

      const utilizationRate = await lendingProtocol.getUtilizationRate(await dai.getAddress());
      expect(utilizationRate).to.equal(5000); // 50% in basis points
    });
  });

  describe("User Account Data", function () {
    beforeEach(async function () {
      // Setup: User1 has collateral and debt
      const collateralAmount = ethers.parseEther("2");
      await weth.connect(user1).approve(await lendingProtocol.getAddress(), collateralAmount);
      await lendingProtocol.connect(user1).deposit(await weth.getAddress(), collateralAmount);

      const liquidityAmount = ethers.parseEther("1000");
      await dai.connect(user2).approve(await lendingProtocol.getAddress(), liquidityAmount);
      await lendingProtocol.connect(user2).deposit(await dai.getAddress(), liquidityAmount);

      const borrowAmount = ethers.parseEther("1000");
      await lendingProtocol.connect(user1).borrow(await dai.getAddress(), borrowAmount);
    });

    it("Should return correct user account data", async function () {
      const userData = await lendingProtocol.getUserAccountData(user1.address);
      
      expect(userData.totalCollateralETH).to.equal(ethers.parseEther("2")); // 2 WETH
      expect(userData.totalDebtETH).to.equal(ethers.parseEther("1000")); // 1000 DAI
      expect(userData.healthFactor).to.be.gt(ethers.parseEther("1")); // Should be > 1 (healthy)
    });
  });

  describe("Admin Functions", function () {
    it("Should allow owner to add new assets", async function () {
      const newToken = await ethers.getContractFactory("MockERC20");
      const token = await newToken.deploy("New Token", "NEW", 18, INITIAL_MINT);
      
      await expect(
        lendingProtocol.addAsset(
          await token.getAddress(),
          9000,
          300,
          ethers.parseEther("1")
        )
      ).to.emit(lendingProtocol, "AssetAdded");

      const supportedAssets = await lendingProtocol.getSupportedAssets();
      expect(supportedAssets).to.include(await token.getAddress());
    });

    it("Should allow owner to update asset prices", async function () {
      const newPrice = ethers.parseEther("2");
      
      await expect(
        lendingProtocol.updatePrice(await dai.getAddress(), newPrice)
      ).to.emit(lendingProtocol, "PriceUpdated")
      .withArgs(await dai.getAddress(), newPrice);
    });

    it("Should revert when non-owner tries admin functions", async function () {
      await expect(
        lendingProtocol.connect(user1).pause()
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("Pausable Functionality", function () {
    it("Should allow owner to pause and unpause", async function () {
      await lendingProtocol.pause();
      
      // Should revert operations when paused
      await expect(
        lendingProtocol.connect(user1).deposit(await dai.getAddress(), ethers.parseEther("100"))
      ).to.be.revertedWith("Pausable: paused");

      await lendingProtocol.unpause();
      
      // Should work again after unpause
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), ethers.parseEther("100"));
      await expect(
        lendingProtocol.connect(user1).deposit(await dai.getAddress(), ethers.parseEther("100"))
      ).to.not.be.reverted;
    });
  });

  describe("Edge Cases and Error Handling", function () {
    it("Should handle zero address correctly", async function () {
      await expect(
        lendingProtocol.addAsset(
          ethers.ZeroAddress,
          8000,
          500,
          ethers.parseEther("1")
        )
      ).to.be.revertedWithCustomError(lendingProtocol, "ZeroAddress");
    });

    it("Should prevent adding duplicate assets", async function () {
      await expect(
        lendingProtocol.addAsset(
          await dai.getAddress(),
          8000,
          500,
          ethers.parseEther("1")
        )
      ).to.be.revertedWith("Asset already supported");
    });

    it("Should handle arithmetic edge cases", async function () {
      // Test with very small amounts
      const smallAmount = 1; // 1 wei
      
      await dai.connect(user1).approve(await lendingProtocol.getAddress(), smallAmount);
      await expect(
        lendingProtocol.connect(user1).deposit(await dai.getAddress(), smallAmount)
      ).to.not.be.reverted;
    });
  });
});
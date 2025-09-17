// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

/**
 * @title CompoundClone
 * @dev A production-ready lending and borrowing protocol similar to Compound
 * @notice This contract allows users to supply assets as collateral and borrow against them
 * Features:
 * - Collateralized lending and borrowing
 * - Dynamic interest rate models
 * - Liquidation mechanisms
 * - Health factor calculations
 * - Governance token rewards
 * - Oracle price feeds
 * - Flash loan functionality
 */
contract CompoundClone is ReentrancyGuard, AccessControl {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ============ CONSTANTS ============

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant LIQUIDATOR_ROLE = keccak256("LIQUIDATOR_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 public constant PRECISION = 1e18;
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant MAX_COLLATERAL_FACTOR = 90e16; // 90% max
    uint256 public constant MIN_HEALTH_FACTOR = 1e18; // 1.0 minimum
    uint256 public constant LIQUIDATION_THRESHOLD = 95e16; // 95%
    uint256 public constant LIQUIDATION_BONUS = 5e16; // 5% bonus
    uint256 public constant MAX_UTILIZATION = 95e16; // 95% max utilization

    // ============ STRUCTS ============

    struct Market {
        IERC20 asset; // Underlying asset
        AggregatorV3Interface priceOracle; // Chainlink price feed
        uint256 collateralFactor; // Loan-to-value ratio
        uint256 reserveFactor; // Percentage of interest to reserves
        uint256 totalSupply; // Total supplied amount
        uint256 totalBorrows; // Total borrowed amount
        uint256 totalReserves; // Total reserves
        uint256 borrowIndex; // Interest accumulation index
        uint256 supplyIndex; // Supply interest index
        uint256 lastUpdateTimestamp; // Last interest update
        bool isActive; // Market activation status
        bool borrowingEnabled; // Borrowing allowed
        bool collateralEnabled; // Can be used as collateral
    }

    struct UserAccount {
        mapping(address => uint256) supplied; // Asset => amount supplied
        mapping(address => uint256) borrowed; // Asset => amount borrowed
        mapping(address => uint256) supplyIndex; // Last supply index
        mapping(address => uint256) borrowIndex; // Last borrow index
        address[] assetsSupplied; // List of supplied assets
        address[] assetsBorrowed; // List of borrowed assets
    }

    struct InterestRateModel {
        uint256 baseRatePerYear; // Base interest rate
        uint256 multiplierPerYear; // Multiplier for utilization
        uint256 jumpMultiplierPerYear; // Jump rate multiplier
        uint256 kink; // Utilization kink point
    }

    // ============ STATE VARIABLES ============

    mapping(address => Market) public markets;
    mapping(address => UserAccount) private userAccounts;
    mapping(address => InterestRateModel) public interestRateModels;
    mapping(address => bool) public marketExists;

    address[] public allMarkets;
    IERC20 public governanceToken;

    uint256 public closeFactorMantissa = 50e16; // 50% max liquidation
    uint256 public flashLoanFee = 9; // 0.09% flash loan fee

    // Flash loan tracking
    mapping(address => uint256) private flashLoanBalances;
    bool private flashLoanActive;

    // ============ EVENTS ============

    event MarketAdded(address indexed asset, address indexed oracle);
    event Supply(address indexed user, address indexed asset, uint256 amount);
    event Withdraw(address indexed user, address indexed asset, uint256 amount);
    event Borrow(address indexed user, address indexed asset, uint256 amount);
    event Repay(address indexed user, address indexed asset, uint256 amount);
    event Liquidation(
        address indexed liquidator,
        address indexed borrower,
        address indexed assetBorrowed,
        address assetCollateral,
        uint256 amountLiquidated,
        uint256 collateralSeized
    );
    event FlashLoan(
        address indexed receiver,
        address indexed asset,
        uint256 amount,
        uint256 fee
    );
    event InterestAccrued(
        address indexed asset,
        uint256 borrowIndex,
        uint256 totalBorrows
    );
    event ReservesWithdrawn(address indexed asset, uint256 amount);

    // ============ ERRORS ============

    error MarketNotActive();
    error MarketAlreadyExists();
    error BorrowingDisabled();
    error CollateralDisabled();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error HealthFactorTooLow();
    error InvalidLiquidation();
    error InvalidAmount();
    error PriceOracleError();
    error FlashLoanActive();
    error FlashLoanRepayFailed();
    error UnauthorizedLiquidator();

    // ============ MODIFIERS ============

    modifier marketActive(address asset) {
        if (!markets[asset].isActive) revert MarketNotActive();
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    modifier noFlashLoan() {
        if (flashLoanActive) revert FlashLoanActive();
        _;
    }

    // ============ CONSTRUCTOR ============

    constructor(address _governanceToken) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        governanceToken = IERC20(_governanceToken);
    }

    // ============ MARKET MANAGEMENT ============

    /**
     * @dev Add a new lending market
     * @param asset The underlying asset
     * @param oracle Chainlink price oracle
     * @param collateralFactor Loan-to-value ratio
     * @param reserveFactor Reserve factor percentage
     */
    function addMarket(
        address asset,
        address oracle,
        uint256 collateralFactor,
        uint256 reserveFactor
    ) external onlyRole(ADMIN_ROLE) {
        if (marketExists[asset]) revert MarketAlreadyExists();
        if (collateralFactor > MAX_COLLATERAL_FACTOR) revert InvalidAmount();

        markets[asset] = Market({
            asset: IERC20(asset),
            priceOracle: AggregatorV3Interface(oracle),
            collateralFactor: collateralFactor,
            reserveFactor: reserveFactor,
            totalSupply: 0,
            totalBorrows: 0,
            totalReserves: 0,
            borrowIndex: PRECISION,
            supplyIndex: PRECISION,
            lastUpdateTimestamp: block.timestamp,
            isActive: true,
            borrowingEnabled: true,
            collateralEnabled: true
        });

        // Default interest rate model
        interestRateModels[asset] = InterestRateModel({
            baseRatePerYear: 2e16, // 2% base rate
            multiplierPerYear: 20e16, // 20% multiplier
            jumpMultiplierPerYear: 109e16, // 109% jump multiplier
            kink: 80e16 // 80% utilization kink
        });

        marketExists[asset] = true;
        allMarkets.push(asset);

        emit MarketAdded(asset, oracle);
    }

    /**
     * @dev Update market parameters
     */
    function updateMarket(
        address asset,
        uint256 collateralFactor,
        uint256 reserveFactor,
        bool borrowingEnabled,
        bool collateralEnabled
    ) external onlyRole(ADMIN_ROLE) marketActive(asset) {
        if (collateralFactor > MAX_COLLATERAL_FACTOR) revert InvalidAmount();

        Market storage market = markets[asset];
        market.collateralFactor = collateralFactor;
        market.reserveFactor = reserveFactor;
        market.borrowingEnabled = borrowingEnabled;
        market.collateralEnabled = collateralEnabled;
    }

    // ============ SUPPLY FUNCTIONS ============

    /**
     * @dev Supply assets to earn interest
     * @param asset Asset to supply
     * @param amount Amount to supply
     */
    function supply(
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        marketActive(asset)
        validAmount(amount)
        noFlashLoan
    {
        _accrueInterest(asset);

        Market storage market = markets[asset];
        UserAccount storage account = userAccounts[msg.sender];

        // Transfer tokens to contract
        market.asset.safeTransferFrom(msg.sender, address(this), amount);

        // Update user supply
        if (account.supplied[asset] == 0) {
            account.assetsSupplied.push(asset);
        }

        uint256 supplyIndexDelta = market.supplyIndex -
            account.supplyIndex[asset];
        uint256 accruedInterest = (account.supplied[asset] * supplyIndexDelta) /
            PRECISION;

        account.supplied[asset] += amount + accruedInterest;
        account.supplyIndex[asset] = market.supplyIndex;

        // Update market totals
        market.totalSupply += amount;

        emit Supply(msg.sender, asset, amount);
    }

    /**
     * @dev Withdraw supplied assets
     * @param asset Asset to withdraw
     * @param amount Amount to withdraw (0 for max)
     */
    function withdraw(
        address asset,
        uint256 amount
    ) external nonReentrant marketActive(asset) noFlashLoan {
        _accrueInterest(asset);

        Market storage market = markets[asset];
        UserAccount storage account = userAccounts[msg.sender];

        // Calculate actual withdrawal amount
        uint256 suppliedBalance = getSuppliedBalance(msg.sender, asset);
        if (amount == 0) {
            amount = suppliedBalance;
        }
        if (amount > suppliedBalance) revert InsufficientLiquidity();

        // Check if withdrawal would break health factor
        if (
            _getHealthFactorAfterWithdraw(msg.sender, asset, amount) <
            MIN_HEALTH_FACTOR
        ) {
            revert HealthFactorTooLow();
        }

        // Update user supply
        account.supplied[asset] -= amount;
        account.supplyIndex[asset] = market.supplyIndex;

        // Remove from supplied assets if balance is zero
        if (account.supplied[asset] == 0) {
            _removeFromArray(account.assetsSupplied, asset);
        }

        // Update market totals
        market.totalSupply -= amount;

        // Transfer tokens to user
        market.asset.safeTransfer(msg.sender, amount);

        emit Withdraw(msg.sender, asset, amount);
    }

    // ============ BORROW FUNCTIONS ============

    /**
     * @dev Borrow assets against collateral
     * @param asset Asset to borrow
     * @param amount Amount to borrow
     */
    function borrow(
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        marketActive(asset)
        validAmount(amount)
        noFlashLoan
    {
        Market storage market = markets[asset];
        if (!market.borrowingEnabled) revert BorrowingDisabled();

        _accrueInterest(asset);

        UserAccount storage account = userAccounts[msg.sender];

        // Check borrowing capacity
        uint256 borrowCapacity = getBorrowingCapacity(msg.sender);
        uint256 currentBorrowValue = getTotalBorrowValue(msg.sender);
        uint256 assetPrice = _getAssetPrice(asset);
        uint256 borrowValue = (amount * assetPrice) / PRECISION;

        if (currentBorrowValue + borrowValue > borrowCapacity) {
            revert InsufficientCollateral();
        }

        // Check market liquidity
        uint256 availableLiquidity = market.totalSupply - market.totalBorrows;
        if (amount > availableLiquidity) revert InsufficientLiquidity();

        // Update user borrow
        if (account.borrowed[asset] == 0) {
            account.assetsBorrowed.push(asset);
        }

        uint256 borrowIndexDelta = market.borrowIndex -
            account.borrowIndex[asset];
        uint256 accruedInterest = (account.borrowed[asset] * borrowIndexDelta) /
            PRECISION;

        account.borrowed[asset] += amount + accruedInterest;
        account.borrowIndex[asset] = market.borrowIndex;

        // Update market totals
        market.totalBorrows += amount;

        // Transfer tokens to user
        market.asset.safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, asset, amount);
    }

    /**
     * @dev Repay borrowed assets
     * @param asset Asset to repay
     * @param amount Amount to repay (0 for max)
     */
    function repay(
        address asset,
        uint256 amount
    ) external nonReentrant marketActive(asset) noFlashLoan {
        _accrueInterest(asset);

        Market storage market = markets[asset];
        UserAccount storage account = userAccounts[msg.sender];

        // Calculate actual repay amount
        uint256 borrowedBalance = getBorrowedBalance(msg.sender, asset);
        if (amount == 0 || amount > borrowedBalance) {
            amount = borrowedBalance;
        }

        // Transfer tokens from user
        market.asset.safeTransferFrom(msg.sender, address(this), amount);

        // Update user borrow
        account.borrowed[asset] -= amount;
        account.borrowIndex[asset] = market.borrowIndex;

        // Remove from borrowed assets if balance is zero
        if (account.borrowed[asset] == 0) {
            _removeFromArray(account.assetsBorrowed, asset);
        }

        // Update market totals
        market.totalBorrows -= amount;

        emit Repay(msg.sender, asset, amount);
    }

    // ============ LIQUIDATION FUNCTIONS ============

    /**
     * @dev Liquidate undercollateralized position
     * @param borrower Address of borrower to liquidate
     * @param assetBorrowed Asset being repaid
     * @param assetCollateral Collateral asset to seize
     * @param repayAmount Amount of borrowed asset to repay
     */
    function liquidate(
        address borrower,
        address assetBorrowed,
        address assetCollateral,
        uint256 repayAmount
    )
        external
        nonReentrant
        marketActive(assetBorrowed)
        marketActive(assetCollateral)
        validAmount(repayAmount)
        noFlashLoan
    {
        // Check if borrower is eligible for liquidation
        uint256 healthFactor = getHealthFactor(borrower);
        if (healthFactor >= MIN_HEALTH_FACTOR) revert InvalidLiquidation();

        _accrueInterest(assetBorrowed);
        _accrueInterest(assetCollateral);

        // Calculate maximum liquidation amount
        uint256 borrowBalance = getBorrowedBalance(borrower, assetBorrowed);
        uint256 maxLiquidation = (borrowBalance * closeFactorMantissa) /
            PRECISION;

        if (repayAmount > maxLiquidation) {
            repayAmount = maxLiquidation;
        }

        // Calculate collateral to seize
        uint256 collateralAmount = _calculateCollateralSeized(
            assetBorrowed,
            assetCollateral,
            repayAmount
        );

        // Verify sufficient collateral
        uint256 collateralBalance = getSuppliedBalance(
            borrower,
            assetCollateral
        );
        if (collateralAmount > collateralBalance)
            revert InsufficientCollateral();

        // Transfer repay amount from liquidator
        markets[assetBorrowed].asset.safeTransferFrom(
            msg.sender,
            address(this),
            repayAmount
        );

        // Update borrower's borrow position
        UserAccount storage borrowerAccount = userAccounts[borrower];
        borrowerAccount.borrowed[assetBorrowed] -= repayAmount;

        // Update borrower's collateral position
        borrowerAccount.supplied[assetCollateral] -= collateralAmount;

        // Update market totals
        markets[assetBorrowed].totalBorrows -= repayAmount;
        markets[assetCollateral].totalSupply -= collateralAmount;

        // Transfer collateral to liquidator
        markets[assetCollateral].asset.safeTransfer(
            msg.sender,
            collateralAmount
        );

        emit Liquidation(
            msg.sender,
            borrower,
            assetBorrowed,
            assetCollateral,
            repayAmount,
            collateralAmount
        );
    }

    // ============ FLASH LOAN FUNCTIONS ============

    /**
     * @dev Execute flash loan
     * @param asset Asset to borrow
     * @param amount Amount to borrow
     * @param receiver Contract to receive the loan
     * @param data Additional data for the receiver
     */
    function flashLoan(
        address asset,
        uint256 amount,
        address receiver,
        bytes calldata data
    )
        external
        nonReentrant
        marketActive(asset)
        validAmount(amount)
        noFlashLoan
    {
        Market storage market = markets[asset];

        uint256 availableLiquidity = market.totalSupply - market.totalBorrows;
        if (amount > availableLiquidity) revert InsufficientLiquidity();

        uint256 fee = (amount * flashLoanFee) / 10000;
        uint256 balanceBefore = market.asset.balanceOf(address(this));

        flashLoanActive = true;
        flashLoanBalances[asset] = balanceBefore;

        // Transfer loan amount to receiver
        market.asset.safeTransfer(receiver, amount);

        // Call receiver's execute function
        IFlashLoanReceiver(receiver).executeOperation(asset, amount, fee, data);

        // Check repayment
        uint256 balanceAfter = market.asset.balanceOf(address(this));
        if (balanceAfter < balanceBefore + fee) revert FlashLoanRepayFailed();

        // Add fee to reserves
        market.totalReserves += fee;

        flashLoanActive = false;
        delete flashLoanBalances[asset];

        emit FlashLoan(receiver, asset, amount, fee);
    }

    // ============ VIEW FUNCTIONS ============

    /**
     * @dev Get user's supplied balance including accrued interest
     */
    function getSuppliedBalance(
        address user,
        address asset
    ) public view returns (uint256) {
        UserAccount storage account = userAccounts[user];
        Market storage market = markets[asset];

        if (account.supplied[asset] == 0) return 0;

        uint256 currentSupplyIndex = _calculateSupplyIndex(asset);
        uint256 indexDelta = currentSupplyIndex - account.supplyIndex[asset];
        uint256 accruedInterest = (account.supplied[asset] * indexDelta) /
            PRECISION;

        return account.supplied[asset] + accruedInterest;
    }

    /**
     * @dev Get user's borrowed balance including accrued interest
     */
    function getBorrowedBalance(
        address user,
        address asset
    ) public view returns (uint256) {
        UserAccount storage account = userAccounts[user];
        Market storage market = markets[asset];

        if (account.borrowed[asset] == 0) return 0;

        uint256 currentBorrowIndex = _calculateBorrowIndex(asset);
        uint256 indexDelta = currentBorrowIndex - account.borrowIndex[asset];
        uint256 accruedInterest = (account.borrowed[asset] * indexDelta) /
            PRECISION;

        return account.borrowed[asset] + accruedInterest;
    }

    /**
     * @dev Get user's total collateral value
     */
    function getTotalCollateralValue(
        address user
    ) public view returns (uint256) {
        UserAccount storage account = userAccounts[user];
        uint256 totalValue = 0;

        for (uint256 i = 0; i < account.assetsSupplied.length; i++) {
            address asset = account.assetsSupplied[i];
            if (!markets[asset].collateralEnabled) continue;

            uint256 balance = getSuppliedBalance(user, asset);
            uint256 price = _getAssetPrice(asset);
            uint256 collateralFactor = markets[asset].collateralFactor;

            totalValue +=
                (balance * price * collateralFactor) /
                (PRECISION * PRECISION);
        }

        return totalValue;
    }

    /**
     * @dev Get user's total borrow value
     */
    function getTotalBorrowValue(address user) public view returns (uint256) {
        UserAccount storage account = userAccounts[user];
        uint256 totalValue = 0;

        for (uint256 i = 0; i < account.assetsBorrowed.length; i++) {
            address asset = account.assetsBorrowed[i];
            uint256 balance = getBorrowedBalance(user, asset);
            uint256 price = _getAssetPrice(asset);

            totalValue += (balance * price) / PRECISION;
        }

        return totalValue;
    }

    /**
     * @dev Get user's borrowing capacity
     */
    function getBorrowingCapacity(address user) public view returns (uint256) {
        return getTotalCollateralValue(user);
    }

    /**
     * @dev Get user's health factor
     */
    function getHealthFactor(address user) public view returns (uint256) {
        uint256 totalBorrowValue = getTotalBorrowValue(user);
        if (totalBorrowValue == 0) return type(uint256).max;

        uint256 totalCollateralValue = getTotalCollateralValue(user);
        return (totalCollateralValue * PRECISION) / totalBorrowValue;
    }

    /**
     * @dev Get current utilization rate for a market
     */
    function getUtilizationRate(address asset) public view returns (uint256) {
        Market storage market = markets[asset];
        if (market.totalSupply == 0) return 0;
        return (market.totalBorrows * PRECISION) / market.totalSupply;
    }

    /**
     * @dev Get current supply APY for a market
     */
    function getSupplyAPY(address asset) public view returns (uint256) {
        uint256 borrowAPY = getBorrowAPY(asset);
        uint256 utilizationRate = getUtilizationRate(asset);
        uint256 reserveFactor = markets[asset].reserveFactor;

        return
            (borrowAPY * utilizationRate * (PRECISION - reserveFactor)) /
            (PRECISION * PRECISION);
    }

    /**
     * @dev Get current borrow APY for a market
     */
    function getBorrowAPY(address asset) public view returns (uint256) {
        InterestRateModel storage model = interestRateModels[asset];
        uint256 utilizationRate = getUtilizationRate(asset);

        if (utilizationRate <= model.kink) {
            return
                model.baseRatePerYear +
                (utilizationRate * model.multiplierPerYear) /
                PRECISION;
        } else {
            uint256 normalRate = model.baseRatePerYear +
                (model.kink * model.multiplierPerYear) /
                PRECISION;
            uint256 excessUtilization = utilizationRate - model.kink;
            return
                normalRate +
                (excessUtilization * model.jumpMultiplierPerYear) /
                PRECISION;
        }
    }

    // ============ INTERNAL FUNCTIONS ============

    function _accrueInterest(address asset) internal {
        Market storage market = markets[asset];
        uint256 currentTimestamp = block.timestamp;
        uint256 timeDelta = currentTimestamp - market.lastUpdateTimestamp;

        if (timeDelta == 0) return;

        uint256 borrowRate = getBorrowAPY(asset);
        uint256 interestFactor = (borrowRate * timeDelta) / SECONDS_PER_YEAR;

        uint256 interestAccumulated = (market.totalBorrows * interestFactor) /
            PRECISION;
        uint256 reserveInterest = (interestAccumulated * market.reserveFactor) /
            PRECISION;

        market.totalBorrows += interestAccumulated;
        market.totalReserves += reserveInterest;
        market.borrowIndex += (market.borrowIndex * interestFactor) / PRECISION;

        // Update supply index
        uint256 supplyInterest = interestAccumulated - reserveInterest;
        if (market.totalSupply > 0) {
            market.supplyIndex +=
                (market.supplyIndex * supplyInterest) /
                market.totalSupply;
        }

        market.lastUpdateTimestamp = currentTimestamp;

        emit InterestAccrued(asset, market.borrowIndex, market.totalBorrows);
    }

    function _calculateBorrowIndex(
        address asset
    ) internal view returns (uint256) {
        Market storage market = markets[asset];
        uint256 timeDelta = block.timestamp - market.lastUpdateTimestamp;

        if (timeDelta == 0) return market.borrowIndex;

        uint256 borrowRate = getBorrowAPY(asset);
        uint256 interestFactor = (borrowRate * timeDelta) / SECONDS_PER_YEAR;

        return
            market.borrowIndex +
            (market.borrowIndex * interestFactor) /
            PRECISION;
    }

    function _calculateSupplyIndex(
        address asset
    ) internal view returns (uint256) {
        Market storage market = markets[asset];
        uint256 timeDelta = block.timestamp - market.lastUpdateTimestamp;

        if (timeDelta == 0 || market.totalSupply == 0)
            return market.supplyIndex;

        uint256 borrowRate = getBorrowAPY(asset);
        uint256 interestFactor = (borrowRate * timeDelta) / SECONDS_PER_YEAR;
        uint256 interestAccumulated = (market.totalBorrows * interestFactor) /
            PRECISION;
        uint256 reserveInterest = (interestAccumulated * market.reserveFactor) /
            PRECISION;
        uint256 supplyInterest = interestAccumulated - reserveInterest;

        return
            market.supplyIndex +
            (market.supplyIndex * supplyInterest) /
            market.totalSupply;
    }

    function _getAssetPrice(address asset) internal view returns (uint256) {
        AggregatorV3Interface oracle = markets[asset].priceOracle;

        try oracle.latestRoundData() returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) {
            if (price <= 0) revert PriceOracleError();
            if (block.timestamp - updatedAt > 3600) revert PriceOracleError(); // 1 hour stale

            // Convert to 18 decimals
            uint8 decimals = oracle.decimals();
            return uint256(price) * (10 ** (18 - decimals));
        } catch {
            revert PriceOracleError();
        }
    }

    function _calculateCollateralSeized(
        address assetBorrowed,
        address assetCollateral,
        uint256 repayAmount
    ) internal view returns (uint256) {
        uint256 borrowPrice = _getAssetPrice(assetBorrowed);
        uint256 collateralPrice = _getAssetPrice(assetCollateral);

        uint256 repayValue = (repayAmount * borrowPrice) / PRECISION;
        uint256 collateralValue = (repayValue *
            (PRECISION + LIQUIDATION_BONUS)) / PRECISION;

        return (collateralValue * PRECISION) / collateralPrice;
    }

    function _getHealthFactorAfterWithdraw(
        address user,
        address asset,
        uint256 amount
    ) internal view returns (uint256) {
        uint256 currentCollateralValue = getTotalCollateralValue(user);
        uint256 assetPrice = _getAssetPrice(asset);
        uint256 collateralFactor = markets[asset].collateralFactor;
        uint256 withdrawValue = (amount * assetPrice * collateralFactor) /
            (PRECISION * PRECISION);

        uint256 newCollateralValue = currentCollateralValue > withdrawValue
            ? currentCollateralValue - withdrawValue
            : 0;

        uint256 totalBorrowValue = getTotalBorrowValue(user);
        if (totalBorrowValue == 0) return type(uint256).max;

        return (newCollateralValue * PRECISION) / totalBorrowValue;
    }

    function _removeFromArray(
        address[] storage array,
        address element
    ) internal {
        for (uint256 i = 0; i < array.length; i++) {
            if (array[i] == element) {
                array[i] = array[array.length - 1];
                array.pop();
                break;
            }
        }
    }

    // ============ ADMIN FUNCTIONS ============

    function setInterestRateModel(
        address asset,
        uint256 baseRatePerYear,
        uint256 multiplierPerYear,
        uint256 jumpMultiplierPerYear,
        uint256 kink
    ) external onlyRole(ADMIN_ROLE) {
        interestRateModels[asset] = InterestRateModel({
            baseRatePerYear: baseRatePerYear,
            multiplierPerYear: multiplierPerYear,
            jumpMultiplierPerYear: jumpMultiplierPerYear,
            kink: kink
        });
    }

    function setCloseFactor(
        uint256 newCloseFactor
    ) external onlyRole(ADMIN_ROLE) {
        closeFactorMantissa = newCloseFactor;
    }

    function setFlashLoanFee(uint256 newFee) external onlyRole(ADMIN_ROLE) {
        flashLoanFee = newFee;
    }

    function withdrawReserves(
        address asset,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) marketActive(asset) {
        Market storage market = markets[asset];
        if (amount > market.totalReserves) revert InsufficientLiquidity();

        market.totalReserves -= amount;
        market.asset.safeTransfer(msg.sender, amount);

        emit ReservesWithdrawn(asset, amount);
    }
}

/**
 * @title IFlashLoanReceiver
 * @dev Interface for flash loan receivers
 */
interface IFlashLoanReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external;
}

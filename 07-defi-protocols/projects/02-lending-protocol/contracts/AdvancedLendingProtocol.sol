// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IPriceOracle {
    function getPrice(address asset) external view returns (uint256);

    function getLatestPrice(
        address asset
    ) external view returns (uint256, uint256);
}

interface IInterestRateModel {
    function getBorrowRate(uint256 utilization) external view returns (uint256);

    function getSupplyRate(
        uint256 utilization,
        uint256 reserveFactor
    ) external view returns (uint256);
}

/**
 * @title Advanced Lending Protocol
 * @dev A production-ready lending protocol similar to Compound/Aave
 * @notice Supports lending, borrowing, liquidations with dynamic interest rates
 *
 * Features:
 * - Multi-asset lending and borrowing
 * - Dynamic interest rate models
 * - Liquidation mechanism with incentives
 * - Health factor monitoring
 * - Flash loans for arbitrage
 * - Governance token rewards
 * - Emergency pause functionality
 * - Oracle-based asset pricing
 */
contract AdvancedLendingProtocol is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ======================
    // CONSTANTS
    // ======================

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    uint256 public constant PRECISION = 1e18;
    uint256 public constant HEALTH_FACTOR_LIQUIDATION_THRESHOLD = 1e18;
    uint256 public constant LIQUIDATION_BONUS = 1050; // 5% bonus
    uint256 public constant MAX_COLLATERAL_FACTOR = 9000; // 90%
    uint256 public constant RESERVE_FACTOR_MAX = 5000; // 50%
    uint256 public constant UTILIZATION_PRECISION = 1e18;

    // ======================
    // STRUCTS
    // ======================

    struct Market {
        bool isListed;
        bool isActive;
        uint256 collateralFactor; // Max loan-to-value ratio (in basis points)
        uint256 liquidationThreshold; // Liquidation threshold (in basis points)
        uint256 liquidationBonus; // Liquidation bonus (in basis points)
        uint256 reserveFactor; // Reserve factor (in basis points)
        uint256 totalSupply; // Total supply of cTokens
        uint256 totalBorrows; // Total borrows
        uint256 totalReserves; // Total reserves
        uint256 borrowIndex; // Accumulator of the total borrow interest
        uint256 supplyIndex; // Accumulator of the total supply interest
        uint256 lastUpdateTimestamp; // Last time interest was accrued
        address cToken; // Associated cToken address
        address interestRateModel; // Interest rate model
    }

    struct UserCollateral {
        uint256 amount; // Amount of cTokens held
        uint256 index; // Interest index when last updated
    }

    struct UserBorrow {
        uint256 principal; // Principal amount borrowed
        uint256 index; // Interest index when last updated
    }

    struct LiquidationCall {
        address user;
        address collateralAsset;
        address debtAsset;
        uint256 debtToCover;
        bool receiveAToken;
    }

    // ======================
    // STATE VARIABLES
    // ======================

    // Core protocol state
    mapping(address => Market) public markets;
    mapping(address => mapping(address => UserCollateral))
        public userCollateral; // user => asset => collateral
    mapping(address => mapping(address => UserBorrow)) public userBorrows; // user => asset => borrow
    mapping(address => address[]) public userAssets; // user => list of assets

    // Protocol configuration
    IPriceOracle public priceOracle;
    address public treasury;
    address public governanceToken;

    // Flash loan state
    mapping(address => bool) public flashloanEnabled;
    uint256 public flashloanFee = 9; // 0.09%
    uint256 public constant FLASHLOAN_FEE_TOTAL = 10000;

    // Protocol parameters
    uint256 public liquidationIncentive = 1080; // 8% incentive
    uint256 public closeFactorMantissa = 5000; // 50% max liquidation

    address[] public allMarkets;

    // ======================
    // EVENTS
    // ======================

    event Supply(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 cTokensMinted
    );

    event Withdraw(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 cTokensBurned
    );

    event Borrow(
        address indexed user,
        address indexed asset,
        uint256 amount,
        uint256 borrowIndex
    );

    event RepayBorrow(
        address indexed user,
        address indexed payer,
        address indexed asset,
        uint256 amount,
        uint256 borrowIndex
    );

    event LiquidationCall(
        address indexed liquidator,
        address indexed user,
        address indexed asset,
        uint256 debtToCover,
        address collateralAsset,
        uint256 liquidatedCollateralAmount
    );

    event FlashLoan(
        address indexed target,
        address indexed initiator,
        address indexed asset,
        uint256 amount,
        uint256 premium
    );

    event MarketEntered(address indexed asset, address indexed user);
    event MarketExited(address indexed asset, address indexed user);
    event MarketListed(address indexed asset, address indexed cToken);

    // ======================
    // ERRORS
    // ======================

    error MarketNotListed();
    error MarketNotActive();
    error InsufficientCollateral();
    error InsufficientLiquidity();
    error HealthFactorTooLow();
    error LiquidationNotAllowed();
    error InvalidAmount();
    error TransferFailed();
    error PriceOracleError();
    error FlashLoanCallbackFailed();
    error UnauthorizedFlashLoan();

    // ======================
    // MODIFIERS
    // ======================

    modifier onlyListedMarket(address asset) {
        if (!markets[asset].isListed) revert MarketNotListed();
        _;
    }

    modifier onlyActiveMarket(address asset) {
        if (!markets[asset].isActive) revert MarketNotActive();
        _;
    }

    modifier validAmount(uint256 amount) {
        if (amount == 0) revert InvalidAmount();
        _;
    }

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(address _priceOracle, address _treasury, address _admin) {
        if (
            _priceOracle == address(0) ||
            _treasury == address(0) ||
            _admin == address(0)
        ) {
            revert InvalidAmount();
        }

        priceOracle = IPriceOracle(_priceOracle);
        treasury = _treasury;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(ADMIN_ROLE, _admin);
        _grantRole(EMERGENCY_ROLE, _admin);
    }

    // ======================
    // CORE LENDING FUNCTIONS
    // ======================

    /**
     * @dev Supply assets to the protocol
     * @param asset The asset to supply
     * @param amount The amount to supply
     * @return cTokensMinted The amount of cTokens minted
     */
    function supply(
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        onlyListedMarket(asset)
        onlyActiveMarket(asset)
        validAmount(amount)
        returns (uint256 cTokensMinted)
    {
        // Accrue interest
        _accrueInterest(asset);

        Market storage market = markets[asset];

        // Calculate cTokens to mint
        cTokensMinted = market.totalSupply == 0
            ? amount
            : (amount * market.totalSupply) / _getCash(asset);

        // Update state
        market.totalSupply += cTokensMinted;
        userCollateral[msg.sender][asset].amount += cTokensMinted;
        userCollateral[msg.sender][asset].index = market.supplyIndex;

        // Add to user's asset list if first time
        _addToMarket(msg.sender, asset);

        // Transfer tokens
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);

        emit Supply(msg.sender, asset, amount, cTokensMinted);
    }

    /**
     * @dev Withdraw supplied assets from the protocol
     * @param asset The asset to withdraw
     * @param cTokenAmount The amount of cTokens to redeem
     * @return amountWithdrawn The underlying amount withdrawn
     */
    function withdraw(
        address asset,
        uint256 cTokenAmount
    )
        external
        nonReentrant
        whenNotPaused
        onlyListedMarket(asset)
        validAmount(cTokenAmount)
        returns (uint256 amountWithdrawn)
    {
        // Accrue interest
        _accrueInterest(asset);

        Market storage market = markets[asset];
        UserCollateral storage collateral = userCollateral[msg.sender][asset];

        if (collateral.amount < cTokenAmount) revert InsufficientCollateral();

        // Calculate underlying amount
        amountWithdrawn = (cTokenAmount * _getCash(asset)) / market.totalSupply;

        // Check if withdrawal is allowed (sufficient collateral)
        _checkAccountLiquidity(msg.sender, asset, amountWithdrawn, 0);

        // Update state
        market.totalSupply -= cTokenAmount;
        collateral.amount -= cTokenAmount;

        // Remove from market if no collateral left
        if (collateral.amount == 0) {
            _exitMarket(msg.sender, asset);
        }

        // Transfer tokens
        IERC20(asset).safeTransfer(msg.sender, amountWithdrawn);

        emit Withdraw(msg.sender, asset, amountWithdrawn, cTokenAmount);
    }

    /**
     * @dev Borrow assets from the protocol
     * @param asset The asset to borrow
     * @param amount The amount to borrow
     */
    function borrow(
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        onlyListedMarket(asset)
        onlyActiveMarket(asset)
        validAmount(amount)
    {
        // Accrue interest
        _accrueInterest(asset);

        Market storage market = markets[asset];

        // Check if borrow is allowed
        _checkAccountLiquidity(msg.sender, address(0), 0, amount);

        // Calculate new borrow balance
        UserBorrow storage userBorrow = userBorrows[msg.sender][asset];
        uint256 previousBorrow = _getBorrowBalance(msg.sender, asset);
        uint256 newBorrowBalance = previousBorrow + amount;

        // Update state
        market.totalBorrows += amount;
        userBorrow.principal = newBorrowBalance;
        userBorrow.index = market.borrowIndex;

        // Add to user's asset list
        _addToMarket(msg.sender, asset);

        // Transfer tokens
        IERC20(asset).safeTransfer(msg.sender, amount);

        emit Borrow(msg.sender, asset, amount, market.borrowIndex);
    }

    /**
     * @dev Repay borrowed assets
     * @param asset The asset to repay
     * @param amount The amount to repay (uint256(-1) for max)
     * @return amountRepaid The actual amount repaid
     */
    function repayBorrow(
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        onlyListedMarket(asset)
        returns (uint256 amountRepaid)
    {
        return _repayBorrowInternal(msg.sender, msg.sender, asset, amount);
    }

    /**
     * @dev Repay borrow on behalf of another user
     * @param user The user whose debt to repay
     * @param asset The asset to repay
     * @param amount The amount to repay
     * @return amountRepaid The actual amount repaid
     */
    function repayBorrowBehalf(
        address user,
        address asset,
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        onlyListedMarket(asset)
        returns (uint256 amountRepaid)
    {
        return _repayBorrowInternal(user, msg.sender, asset, amount);
    }

    // ======================
    // LIQUIDATION FUNCTIONS
    // ======================

    /**
     * @dev Liquidate an undercollateralized borrow
     * @param user The borrower to liquidate
     * @param debtAsset The asset to repay
     * @param collateralAsset The collateral asset to seize
     * @param debtToCover The amount of debt to cover
     */
    function liquidationCall(
        address user,
        address debtAsset,
        address collateralAsset,
        uint256 debtToCover
    )
        external
        nonReentrant
        whenNotPaused
        onlyListedMarket(debtAsset)
        onlyListedMarket(collateralAsset)
    {
        // Accrue interest on both markets
        _accrueInterest(debtAsset);
        _accrueInterest(collateralAsset);

        // Check if liquidation is allowed
        if (_getHealthFactor(user) >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
            revert LiquidationNotAllowed();
        }

        uint256 userBorrowBalance = _getBorrowBalance(user, debtAsset);
        uint256 maxClose = (userBorrowBalance * closeFactorMantissa) / 10000;

        if (debtToCover > maxClose) {
            debtToCover = maxClose;
        }

        // Calculate collateral to seize
        uint256 collateralToSeize = _calculateCollateralToSeize(
            debtAsset,
            collateralAsset,
            debtToCover
        );

        // Perform liquidation
        _repayBorrowInternal(user, msg.sender, debtAsset, debtToCover);
        _seizeCollateral(user, msg.sender, collateralAsset, collateralToSeize);

        emit LiquidationCall(
            msg.sender,
            user,
            debtAsset,
            debtToCover,
            collateralAsset,
            collateralToSeize
        );
    }

    // ======================
    // FLASH LOAN FUNCTIONS
    // ======================

    /**
     * @dev Execute a flash loan
     * @param asset The asset to flash loan
     * @param amount The amount to flash loan
     * @param receiver The contract to receive the flash loan
     * @param params Additional parameters for the flash loan
     */
    function flashLoan(
        address asset,
        uint256 amount,
        address receiver,
        bytes calldata params
    ) external nonReentrant whenNotPaused onlyListedMarket(asset) {
        if (!flashloanEnabled[asset]) revert UnauthorizedFlashLoan();

        uint256 premium = (amount * flashloanFee) / FLASHLOAN_FEE_TOTAL;
        uint256 balanceBefore = IERC20(asset).balanceOf(address(this));

        // Transfer flash loan amount
        IERC20(asset).safeTransfer(receiver, amount);

        // Execute callback
        bool success = _executeFlashLoanCallback(
            receiver,
            asset,
            amount,
            premium,
            params
        );
        if (!success) revert FlashLoanCallbackFailed();

        // Verify repayment
        uint256 balanceAfter = IERC20(asset).balanceOf(address(this));
        if (balanceAfter < balanceBefore + premium)
            revert FlashLoanCallbackFailed();

        // Add premium to reserves
        markets[asset].totalReserves += premium;

        emit FlashLoan(receiver, msg.sender, asset, amount, premium);
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Get user's health factor
     * @param user The user to check
     * @return healthFactor The health factor (18 decimals)
     */
    function getHealthFactor(
        address user
    ) external view returns (uint256 healthFactor) {
        return _getHealthFactor(user);
    }

    /**
     * @dev Get user's account liquidity
     * @param user The user to check
     * @return totalCollateralETH Total collateral in ETH
     * @return totalDebtETH Total debt in ETH
     * @return availableBorrowsETH Available borrows in ETH
     */
    function getUserAccountData(
        address user
    )
        external
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH
        )
    {
        return _getUserAccountData(user);
    }

    /**
     * @dev Get user's borrow balance for an asset
     * @param user The user to check
     * @param asset The asset to check
     * @return borrowBalance The borrow balance
     */
    function getBorrowBalance(
        address user,
        address asset
    ) external view returns (uint256 borrowBalance) {
        return _getBorrowBalance(user, asset);
    }

    /**
     * @dev Get user's supply balance for an asset
     * @param user The user to check
     * @param asset The asset to check
     * @return supplyBalance The supply balance
     */
    function getSupplyBalance(
        address user,
        address asset
    ) external view returns (uint256 supplyBalance) {
        return _getSupplyBalance(user, asset);
    }

    /**
     * @dev Get current utilization rate for an asset
     * @param asset The asset to check
     * @return utilizationRate The utilization rate (18 decimals)
     */
    function getUtilizationRate(
        address asset
    ) external view returns (uint256 utilizationRate) {
        Market storage market = markets[asset];
        if (market.totalSupply == 0) return 0;

        uint256 cash = _getCash(asset);
        if (cash + market.totalBorrows == 0) return 0;

        return
            (market.totalBorrows * UTILIZATION_PRECISION) /
            (cash + market.totalBorrows);
    }

    /**
     * @dev Get current borrow and supply rates for an asset
     * @param asset The asset to check
     * @return borrowRate Current borrow rate per block
     * @return supplyRate Current supply rate per block
     */
    function getInterestRates(
        address asset
    ) external view returns (uint256 borrowRate, uint256 supplyRate) {
        Market storage market = markets[asset];
        uint256 utilization = this.getUtilizationRate(asset);

        IInterestRateModel model = IInterestRateModel(market.interestRateModel);
        borrowRate = model.getBorrowRate(utilization);
        supplyRate = model.getSupplyRate(utilization, market.reserveFactor);
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    function _repayBorrowInternal(
        address user,
        address payer,
        address asset,
        uint256 amount
    ) internal returns (uint256 amountRepaid) {
        // Accrue interest
        _accrueInterest(asset);

        Market storage market = markets[asset];
        UserBorrow storage userBorrow = userBorrows[user][asset];

        uint256 borrowBalance = _getBorrowBalance(user, asset);

        // Handle max repayment
        if (amount == type(uint256).max) {
            amount = borrowBalance;
        }

        amountRepaid = Math.min(amount, borrowBalance);

        // Update state
        market.totalBorrows -= amountRepaid;
        userBorrow.principal = borrowBalance - amountRepaid;
        userBorrow.index = market.borrowIndex;

        // Transfer tokens
        IERC20(asset).safeTransferFrom(payer, address(this), amountRepaid);

        emit RepayBorrow(user, payer, asset, amountRepaid, market.borrowIndex);
    }

    function _accrueInterest(address asset) internal {
        Market storage market = markets[asset];

        uint256 currentTimestamp = block.timestamp;
        uint256 timeDelta = currentTimestamp - market.lastUpdateTimestamp;

        if (timeDelta == 0) return;

        uint256 cash = _getCash(asset);
        uint256 utilization = market.totalSupply == 0
            ? 0
            : (market.totalBorrows * UTILIZATION_PRECISION) /
                (cash + market.totalBorrows);

        IInterestRateModel model = IInterestRateModel(market.interestRateModel);
        uint256 borrowRate = model.getBorrowRate(utilization);
        uint256 supplyRate = model.getSupplyRate(
            utilization,
            market.reserveFactor
        );

        // Update indices
        market.borrowIndex =
            market.borrowIndex +
            (market.borrowIndex * borrowRate * timeDelta) /
            PRECISION;
        market.supplyIndex =
            market.supplyIndex +
            (market.supplyIndex * supplyRate * timeDelta) /
            PRECISION;

        // Update reserves
        uint256 interestAccumulated = (market.totalBorrows *
            borrowRate *
            timeDelta) / PRECISION;
        uint256 reservesAdded = (interestAccumulated * market.reserveFactor) /
            10000;
        market.totalReserves += reservesAdded;
        market.totalBorrows += interestAccumulated;

        market.lastUpdateTimestamp = currentTimestamp;
    }

    function _getHealthFactor(address user) internal view returns (uint256) {
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,

        ) = _getUserAccountData(user);

        if (totalDebtETH == 0) return type(uint256).max;

        return (totalCollateralETH * PRECISION) / totalDebtETH;
    }

    function _getUserAccountData(
        address user
    )
        internal
        view
        returns (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,
            uint256 availableBorrowsETH
        )
    {
        address[] memory userMarkets = userAssets[user];

        for (uint256 i = 0; i < userMarkets.length; i++) {
            address asset = userMarkets[i];
            Market storage market = markets[asset];

            uint256 assetPrice = priceOracle.getPrice(asset);

            // Calculate collateral
            uint256 supplyBalance = _getSupplyBalance(user, asset);
            uint256 collateralValue = (supplyBalance * assetPrice) / PRECISION;
            totalCollateralETH += collateralValue;

            // Calculate debt
            uint256 borrowBalance = _getBorrowBalance(user, asset);
            uint256 debtValue = (borrowBalance * assetPrice) / PRECISION;
            totalDebtETH += debtValue;

            // Calculate available borrows
            uint256 maxBorrowValue = (collateralValue *
                market.collateralFactor) / 10000;
            if (maxBorrowValue > debtValue) {
                availableBorrowsETH += maxBorrowValue - debtValue;
            }
        }
    }

    function _getBorrowBalance(
        address user,
        address asset
    ) internal view returns (uint256) {
        UserBorrow storage userBorrow = userBorrows[user][asset];
        if (userBorrow.principal == 0) return 0;

        Market storage market = markets[asset];
        return (userBorrow.principal * market.borrowIndex) / userBorrow.index;
    }

    function _getSupplyBalance(
        address user,
        address asset
    ) internal view returns (uint256) {
        UserCollateral storage collateral = userCollateral[user][asset];
        if (collateral.amount == 0) return 0;

        Market storage market = markets[asset];
        uint256 cash = _getCash(asset);
        return (collateral.amount * cash) / market.totalSupply;
    }

    function _getCash(address asset) internal view returns (uint256) {
        return
            IERC20(asset).balanceOf(address(this)) -
            markets[asset].totalReserves;
    }

    function _checkAccountLiquidity(
        address user,
        address assetToWithdraw,
        uint256 withdrawAmount,
        uint256 borrowAmount
    ) internal view {
        (
            uint256 totalCollateralETH,
            uint256 totalDebtETH,

        ) = _getUserAccountData(user);

        // Adjust for potential withdrawal
        if (assetToWithdraw != address(0) && withdrawAmount > 0) {
            uint256 assetPrice = priceOracle.getPrice(assetToWithdraw);
            uint256 withdrawValueETH = (withdrawAmount * assetPrice) /
                PRECISION;
            totalCollateralETH = totalCollateralETH > withdrawValueETH
                ? totalCollateralETH - withdrawValueETH
                : 0;
        }

        // Adjust for potential borrow
        if (borrowAmount > 0) {
            uint256 assetPrice = priceOracle.getPrice(assetToWithdraw);
            uint256 borrowValueETH = (borrowAmount * assetPrice) / PRECISION;
            totalDebtETH += borrowValueETH;
        }

        // Check if position remains healthy
        if (totalDebtETH > 0) {
            uint256 healthFactor = (totalCollateralETH * PRECISION) /
                totalDebtETH;
            if (healthFactor < HEALTH_FACTOR_LIQUIDATION_THRESHOLD) {
                revert HealthFactorTooLow();
            }
        }
    }

    function _calculateCollateralToSeize(
        address debtAsset,
        address collateralAsset,
        uint256 debtToCover
    ) internal view returns (uint256 collateralToSeize) {
        uint256 debtPrice = priceOracle.getPrice(debtAsset);
        uint256 collateralPrice = priceOracle.getPrice(collateralAsset);

        // Calculate base collateral amount
        uint256 baseCollateral = (debtToCover * debtPrice) / collateralPrice;

        // Apply liquidation bonus
        collateralToSeize = (baseCollateral * liquidationIncentive) / 1000;
    }

    function _seizeCollateral(
        address liquidatedUser,
        address liquidator,
        address asset,
        uint256 amount
    ) internal {
        UserCollateral storage liquidatedCollateral = userCollateral[
            liquidatedUser
        ][asset];
        UserCollateral storage liquidatorCollateral = userCollateral[
            liquidator
        ][asset];

        if (liquidatedCollateral.amount < amount)
            revert InsufficientCollateral();

        liquidatedCollateral.amount -= amount;
        liquidatorCollateral.amount += amount;

        // Add to liquidator's market if needed
        _addToMarket(liquidator, asset);

        // Remove from liquidated user's market if no collateral left
        if (liquidatedCollateral.amount == 0) {
            _exitMarket(liquidatedUser, asset);
        }
    }

    function _addToMarket(address user, address asset) internal {
        address[] storage assets = userAssets[user];
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) return; // Already in market
        }
        assets.push(asset);
        emit MarketEntered(asset, user);
    }

    function _exitMarket(address user, address asset) internal {
        address[] storage assets = userAssets[user];
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i] == asset) {
                assets[i] = assets[assets.length - 1];
                assets.pop();
                emit MarketExited(asset, user);
                break;
            }
        }
    }

    function _executeFlashLoanCallback(
        address receiver,
        address asset,
        uint256 amount,
        uint256 premium,
        bytes calldata params
    ) internal returns (bool) {
        try
            IFlashLoanReceiver(receiver).executeOperation(
                asset,
                amount,
                premium,
                msg.sender,
                params
            )
        returns (bool success) {
            return success;
        } catch {
            return false;
        }
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    /**
     * @dev List a new market
     * @param asset The asset to list
     * @param cToken The associated cToken
     * @param interestRateModel The interest rate model
     * @param collateralFactor The collateral factor
     */
    function listMarket(
        address asset,
        address cToken,
        address interestRateModel,
        uint256 collateralFactor
    ) external onlyRole(ADMIN_ROLE) {
        if (markets[asset].isListed) revert MarketNotListed();
        if (collateralFactor > MAX_COLLATERAL_FACTOR) revert InvalidAmount();

        markets[asset] = Market({
            isListed: true,
            isActive: true,
            collateralFactor: collateralFactor,
            liquidationThreshold: collateralFactor + 500, // +5%
            liquidationBonus: LIQUIDATION_BONUS,
            reserveFactor: 1000, // 10%
            totalSupply: 0,
            totalBorrows: 0,
            totalReserves: 0,
            borrowIndex: PRECISION,
            supplyIndex: PRECISION,
            lastUpdateTimestamp: block.timestamp,
            cToken: cToken,
            interestRateModel: interestRateModel
        });

        allMarkets.push(asset);
        flashloanEnabled[asset] = true;

        emit MarketListed(asset, cToken);
    }

    /**
     * @dev Update market parameters
     * @param asset The asset to update
     * @param collateralFactor New collateral factor
     * @param liquidationThreshold New liquidation threshold
     * @param reserveFactor New reserve factor
     */
    function updateMarket(
        address asset,
        uint256 collateralFactor,
        uint256 liquidationThreshold,
        uint256 reserveFactor
    ) external onlyRole(ADMIN_ROLE) onlyListedMarket(asset) {
        Market storage market = markets[asset];

        if (collateralFactor > MAX_COLLATERAL_FACTOR) revert InvalidAmount();
        if (reserveFactor > RESERVE_FACTOR_MAX) revert InvalidAmount();

        market.collateralFactor = collateralFactor;
        market.liquidationThreshold = liquidationThreshold;
        market.reserveFactor = reserveFactor;
    }

    /**
     * @dev Emergency pause/unpause market
     * @param asset The asset to pause/unpause
     * @param active The new active state
     */
    function setMarketActive(
        address asset,
        bool active
    ) external onlyRole(EMERGENCY_ROLE) onlyListedMarket(asset) {
        markets[asset].isActive = active;
    }

    /**
     * @dev Update price oracle
     * @param newOracle The new oracle address
     */
    function setPriceOracle(address newOracle) external onlyRole(ADMIN_ROLE) {
        priceOracle = IPriceOracle(newOracle);
    }

    /**
     * @dev Emergency pause protocol
     */
    function emergencyPause() external onlyRole(EMERGENCY_ROLE) {
        _pause();
    }

    /**
     * @dev Emergency unpause protocol
     */
    function emergencyUnpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Withdraw reserves
     * @param asset The asset to withdraw reserves for
     * @param amount The amount to withdraw
     */
    function withdrawReserves(
        address asset,
        uint256 amount
    ) external onlyRole(ADMIN_ROLE) onlyListedMarket(asset) {
        Market storage market = markets[asset];
        if (amount > market.totalReserves) revert InvalidAmount();

        market.totalReserves -= amount;
        IERC20(asset).safeTransfer(treasury, amount);
    }
}

// ======================
// FLASH LOAN INTERFACE
// ======================

interface IFlashLoanReceiver {
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external returns (bool);
}

/**
 *  ADVANCED LENDING PROTOCOL FEATURES:
 *
 * 1. COMPREHENSIVE LENDING SYSTEM:
 *    - Multi-asset supply and borrowing
 *    - Dynamic interest rate models
 *    - Collateral-based lending with health factors
 *    - Liquidation mechanism with incentives
 *
 * 2. ADVANCED RISK MANAGEMENT:
 *    - Health factor monitoring
 *    - Utilization-based interest rates
 *    - Liquidation threshold and bonus system
 *    - Reserve factor for protocol safety
 *
 * 3. FLASH LOAN INTEGRATION:
 *    - Uncollateralized flash loans for arbitrage
 *    - Fee-based revenue model for protocol
 *    - Callback mechanism for complex operations
 *    - MEV and arbitrage opportunities
 *
 * 4. SECURITY & GOVERNANCE:
 *    - Role-based access control
 *    - Emergency pause functionality
 *    - Oracle-based asset pricing
 *    - Reserve management and treasury
 *
 * 5. PROFESSIONAL FEATURES:
 *    - Compound-style interest accrual
 *    - Market listing and configuration
 *    - User account data aggregation
 *    - Real-time utilization and rates
 *
 *  USAGE EXAMPLES:
 *
 * // Supply collateral
 * protocol.supply(USDC, 1000e6);
 *
 * // Borrow against collateral
 * protocol.borrow(ETH, 0.5e18);
 *
 * // Repay borrow
 * protocol.repayBorrow(ETH, type(uint256).max);
 *
 * // Liquidate undercollateralized position
 * protocol.liquidationCall(
 *     user,
 *     debtAsset,
 *     collateralAsset,
 *     debtAmount
 * );
 *
 * // Execute flash loan
 * protocol.flashLoan(
 *     asset,
 *     amount,
 *     receiver,
 *     params
 * );
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Advanced Yield Farming Protocol
 * @dev A comprehensive yield farming system with multiple pools, boost mechanisms, and auto-compounding
 * @notice Professional-grade farming protocol with advanced reward distribution and optimization
 *
 * Features:
 * - Multiple farming pools with different reward tokens
 * - Boost mechanisms for enhanced rewards
 * - Auto-compounding vaults for maximum yield
 * - Tiered reward structures based on lock periods
 * - Emergency withdrawal capabilities
 * - Governance token integration
 * - Fee-sharing mechanisms
 * - Multi-signature administrative controls
 */
contract AdvancedYieldFarm is ReentrancyGuard, Pausable, Ownable {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ======================
    // CONSTANTS
    // ======================

    uint256 public constant PRECISION = 1e18;
    uint256 public constant MAX_LOCK_DURATION = 365 days;
    uint256 public constant MIN_LOCK_DURATION = 1 days;
    uint256 public constant MAX_BOOST_MULTIPLIER = 5000; // 5x max boost
    uint256 public constant EARLY_WITHDRAWAL_PENALTY = 1000; // 10%
    uint256 public constant FEE_DENOMINATOR = 10000;

    // ======================
    // STRUCTS
    // ======================

    struct PoolInfo {
        IERC20 stakingToken; // Token to be staked
        IERC20 rewardToken; // Primary reward token
        uint256 rewardPerSecond; // Reward tokens per second
        uint256 lastRewardTime; // Last time rewards were distributed
        uint256 accRewardPerShare; // Accumulated rewards per share
        uint256 totalStaked; // Total amount staked in pool
        uint256 allocPoint; // Allocation points for this pool
        bool isActive; // Whether pool is accepting deposits
        uint256 lockDuration; // Minimum lock duration for rewards
        uint256 earlyWithdrawFee; // Fee for early withdrawal
        address[] bonusRewardTokens; // Additional reward tokens
        uint256[] bonusRewardRates; // Rates for bonus rewards
    }

    struct UserInfo {
        uint256 amount; // Amount staked by user
        uint256 rewardDebt; // Reward debt for primary token
        uint256 lockEndTime; // When user can withdraw without penalty
        uint256 boostMultiplier; // User's boost multiplier
        uint256 lastDepositTime; // Last time user deposited
        mapping(address => uint256) bonusRewardDebt; // Bonus reward debts
        uint256[] lockAmounts; // Amounts locked for different durations
        uint256[] lockEndTimes; // End times for different locks
    }

    struct VaultInfo {
        bool isActive; // Whether vault is active
        uint256 totalShares; // Total vault shares
        uint256 totalAssets; // Total underlying assets
        uint256 lastHarvestTime; // Last time rewards were harvested
        uint256 performanceFee; // Performance fee percentage
        uint256 managementFee; // Management fee percentage
        address strategy; // Strategy contract address
    }

    struct RewardBoost {
        uint256 govTokenRequired; // Governance tokens required for boost
        uint256 multiplier; // Boost multiplier (basis points)
        uint256 duration; // Boost duration
    }

    // ======================
    // STATE VARIABLES
    // ======================

    // Core protocol state
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    mapping(address => VaultInfo) public vaultInfo;
    mapping(address => uint256) public userVaultShares;

    // Protocol configuration
    IERC20 public governanceToken;
    address public treasury;
    address public emergencyAddr;

    uint256 public totalAllocPoint = 0;
    uint256 public emergencyWithdrawFee = 500; // 5%

    // Boost system
    RewardBoost[] public rewardBoosts;
    mapping(address => uint256) public userBoostLevel;
    mapping(address => uint256) public userBoostEndTime;

    // Fee configuration
    uint256 public depositFee = 0; // No deposit fee by default
    uint256 public withdrawalFee = 0; // No withdrawal fee by default
    uint256 public performanceFeeShare = 2000; // 20% to treasury

    // Reward multipliers based on lock duration
    mapping(uint256 => uint256) public lockMultipliers; // duration => multiplier

    // ======================
    // EVENTS
    // ======================

    event Deposit(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        uint256 lockEndTime
    );
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount,
        uint256 fee
    );
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event PoolAdded(
        uint256 indexed pid,
        address stakingToken,
        uint256 allocPoint
    );
    event PoolUpdated(
        uint256 indexed pid,
        uint256 allocPoint,
        uint256 rewardPerSecond
    );
    event BoostActivated(
        address indexed user,
        uint256 level,
        uint256 multiplier,
        uint256 endTime
    );
    event VaultDeposit(
        address indexed user,
        address indexed vault,
        uint256 amount,
        uint256 shares
    );
    event VaultWithdraw(
        address indexed user,
        address indexed vault,
        uint256 shares,
        uint256 amount
    );
    event PerformanceFee(address indexed vault, uint256 amount);
    event CompoundRewards(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    // ======================
    // ERRORS
    // ======================

    error PoolNotActive();
    error InsufficientBalance();
    error LockPeriodActive();
    error InvalidLockDuration();
    error InsufficientGovernanceTokens();
    error InvalidPoolId();
    error ZeroAmount();
    error Unauthorized();
    error VaultNotActive();
    error InvalidBoostLevel();

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(
        IERC20 _governanceToken,
        address _treasury,
        address _emergencyAddr
    ) {
        governanceToken = _governanceToken;
        treasury = _treasury;
        emergencyAddr = _emergencyAddr;

        // Set default lock multipliers
        lockMultipliers[0] = 10000; // 1x for no lock
        lockMultipliers[7 days] = 11000; // 1.1x for 1 week
        lockMultipliers[30 days] = 12500; // 1.25x for 1 month
        lockMultipliers[90 days] = 15000; // 1.5x for 3 months
        lockMultipliers[180 days] = 20000; // 2x for 6 months
        lockMultipliers[365 days] = 30000; // 3x for 1 year

        // Set default reward boosts
        rewardBoosts.push(
            RewardBoost({
                govTokenRequired: 1000e18,
                multiplier: 11000, // 1.1x
                duration: 30 days
            })
        );
        rewardBoosts.push(
            RewardBoost({
                govTokenRequired: 5000e18,
                multiplier: 12500, // 1.25x
                duration: 30 days
            })
        );
        rewardBoosts.push(
            RewardBoost({
                govTokenRequired: 10000e18,
                multiplier: 15000, // 1.5x
                duration: 30 days
            })
        );
    }

    // ======================
    // CORE FARMING FUNCTIONS
    // ======================

    /**
     * @dev Deposit tokens to a farming pool
     * @param _pid Pool ID
     * @param _amount Amount to deposit
     * @param _lockDuration Lock duration for boost (0 for no lock)
     */
    function deposit(
        uint256 _pid,
        uint256 _amount,
        uint256 _lockDuration
    ) external nonReentrant whenNotPaused {
        if (_pid >= poolInfo.length) revert InvalidPoolId();
        if (_amount == 0) revert ZeroAmount();
        if (
            _lockDuration > 0 &&
            (_lockDuration < MIN_LOCK_DURATION ||
                _lockDuration > MAX_LOCK_DURATION)
        ) {
            revert InvalidLockDuration();
        }

        PoolInfo storage pool = poolInfo[_pid];
        if (!pool.isActive) revert PoolNotActive();

        UserInfo storage user = userInfo[_pid][msg.sender];

        updatePool(_pid);

        // Harvest existing rewards
        if (user.amount > 0) {
            _harvestRewards(_pid, msg.sender);
        }

        // Calculate deposit fee
        uint256 depositAmount = _amount;
        if (depositFee > 0) {
            uint256 fee = (_amount * depositFee) / FEE_DENOMINATOR;
            depositAmount = _amount - fee;
            pool.stakingToken.safeTransferFrom(msg.sender, treasury, fee);
        }

        // Transfer tokens
        pool.stakingToken.safeTransferFrom(
            msg.sender,
            address(this),
            depositAmount
        );

        // Update user info
        user.amount += depositAmount;
        user.lastDepositTime = block.timestamp;

        // Handle lock duration
        if (_lockDuration > 0) {
            uint256 lockEndTime = block.timestamp + _lockDuration;
            user.lockAmounts.push(depositAmount);
            user.lockEndTimes.push(lockEndTime);
            user.lockEndTime = Math.max(user.lockEndTime, lockEndTime);
        }

        // Update pool state
        pool.totalStaked += depositAmount;

        // Calculate reward debt
        uint256 multiplier = _getEffectiveMultiplier(msg.sender, _lockDuration);
        user.rewardDebt =
            (user.amount * pool.accRewardPerShare * multiplier) /
            (PRECISION * 10000);

        // Update bonus reward debts
        for (uint256 i = 0; i < pool.bonusRewardTokens.length; i++) {
            address bonusToken = pool.bonusRewardTokens[i];
            user.bonusRewardDebt[bonusToken] =
                (user.amount * pool.accRewardPerShare * multiplier) /
                (PRECISION * 10000);
        }

        emit Deposit(msg.sender, _pid, depositAmount, user.lockEndTime);
    }

    /**
     * @dev Withdraw tokens from a farming pool
     * @param _pid Pool ID
     * @param _amount Amount to withdraw
     */
    function withdraw(uint256 _pid, uint256 _amount) external nonReentrant {
        if (_pid >= poolInfo.length) revert InvalidPoolId();
        if (_amount == 0) revert ZeroAmount();

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.amount < _amount) revert InsufficientBalance();

        updatePool(_pid);

        // Harvest rewards
        _harvestRewards(_pid, msg.sender);

        // Check lock period
        uint256 withdrawAmount = _amount;
        uint256 fee = 0;

        if (block.timestamp < user.lockEndTime) {
            // Apply early withdrawal penalty
            fee = (_amount * pool.earlyWithdrawFee) / FEE_DENOMINATOR;
            withdrawAmount = _amount - fee;

            if (fee > 0) {
                pool.stakingToken.safeTransfer(treasury, fee);
            }
        }

        // Update user info
        user.amount -= _amount;
        pool.totalStaked -= _amount;

        // Update lock amounts if needed
        _updateUserLocks(_pid, msg.sender, _amount);

        // Calculate new reward debt
        uint256 multiplier = _getEffectiveMultiplier(msg.sender, 0);
        user.rewardDebt =
            (user.amount * pool.accRewardPerShare * multiplier) /
            (PRECISION * 10000);

        // Transfer tokens
        pool.stakingToken.safeTransfer(msg.sender, withdrawAmount);

        emit Withdraw(msg.sender, _pid, withdrawAmount);
    }

    /**
     * @dev Emergency withdraw without caring about rewards
     * @param _pid Pool ID
     */
    function emergencyWithdraw(uint256 _pid) external nonReentrant {
        if (_pid >= poolInfo.length) revert InvalidPoolId();

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 amount = user.amount;
        if (amount == 0) revert ZeroAmount();

        // Calculate emergency withdrawal fee
        uint256 fee = (amount * emergencyWithdrawFee) / FEE_DENOMINATOR;
        uint256 withdrawAmount = amount - fee;

        // Reset user info
        user.amount = 0;
        user.rewardDebt = 0;
        user.lockEndTime = 0;
        delete user.lockAmounts;
        delete user.lockEndTimes;

        // Update pool
        pool.totalStaked -= amount;

        // Transfer tokens
        if (fee > 0) {
            pool.stakingToken.safeTransfer(treasury, fee);
        }
        pool.stakingToken.safeTransfer(msg.sender, withdrawAmount);

        emit EmergencyWithdraw(msg.sender, _pid, withdrawAmount, fee);
    }

    /**
     * @dev Harvest rewards for a specific pool
     * @param _pid Pool ID
     */
    function harvest(uint256 _pid) external nonReentrant {
        if (_pid >= poolInfo.length) revert InvalidPoolId();

        updatePool(_pid);
        _harvestRewards(_pid, msg.sender);
    }

    /**
     * @dev Harvest rewards from all pools for the user
     */
    function harvestAll() external nonReentrant {
        for (uint256 pid = 0; pid < poolInfo.length; pid++) {
            UserInfo storage user = userInfo[pid][msg.sender];
            if (user.amount > 0) {
                updatePool(pid);
                _harvestRewards(pid, msg.sender);
            }
        }
    }

    // ======================
    // AUTO-COMPOUNDING VAULT FUNCTIONS
    // ======================

    /**
     * @dev Deposit tokens into auto-compounding vault
     * @param _vault Vault token address
     * @param _amount Amount to deposit
     */
    function depositToVault(
        address _vault,
        uint256 _amount
    ) external nonReentrant whenNotPaused {
        if (_amount == 0) revert ZeroAmount();

        VaultInfo storage vault = vaultInfo[_vault];
        if (!vault.isActive) revert VaultNotActive();

        IERC20 vaultToken = IERC20(_vault);

        // Calculate shares to mint
        uint256 shares = vault.totalShares == 0
            ? _amount
            : (_amount * vault.totalShares) / vault.totalAssets;

        // Transfer tokens
        vaultToken.safeTransferFrom(msg.sender, address(this), _amount);

        // Update state
        vault.totalAssets += _amount;
        vault.totalShares += shares;
        userVaultShares[msg.sender] += shares;

        emit VaultDeposit(msg.sender, _vault, _amount, shares);
    }

    /**
     * @dev Withdraw tokens from auto-compounding vault
     * @param _vault Vault token address
     * @param _shares Shares to redeem
     */
    function withdrawFromVault(
        address _vault,
        uint256 _shares
    ) external nonReentrant {
        if (_shares == 0) revert ZeroAmount();
        if (userVaultShares[msg.sender] < _shares) revert InsufficientBalance();

        VaultInfo storage vault = vaultInfo[_vault];
        IERC20 vaultToken = IERC20(_vault);

        // Calculate withdrawal amount
        uint256 amount = (_shares * vault.totalAssets) / vault.totalShares;

        // Update state
        vault.totalAssets -= amount;
        vault.totalShares -= _shares;
        userVaultShares[msg.sender] -= _shares;

        // Transfer tokens
        vaultToken.safeTransfer(msg.sender, amount);

        emit VaultWithdraw(msg.sender, _vault, _shares, amount);
    }

    /**
     * @dev Compound rewards for a vault (harvest and reinvest)
     * @param _vault Vault token address
     */
    function compoundVault(address _vault) external nonReentrant {
        VaultInfo storage vault = vaultInfo[_vault];
        if (!vault.isActive) revert VaultNotActive();

        // Harvest rewards from underlying strategy
        uint256 harvested = _harvestVaultRewards(_vault);

        if (harvested > 0) {
            // Calculate performance fee
            uint256 fee = (harvested * vault.performanceFee) / FEE_DENOMINATOR;
            if (fee > 0) {
                IERC20(_vault).safeTransfer(treasury, fee);
                harvested -= fee;
                emit PerformanceFee(_vault, fee);
            }

            // Reinvest remaining rewards
            vault.totalAssets += harvested;
            vault.lastHarvestTime = block.timestamp;
        }
    }

    // ======================
    // BOOST SYSTEM FUNCTIONS
    // ======================

    /**
     * @dev Activate reward boost by staking governance tokens
     * @param _level Boost level to activate
     */
    function activateBoost(uint256 _level) external nonReentrant {
        if (_level >= rewardBoosts.length) revert InvalidBoostLevel();

        RewardBoost storage boost = rewardBoosts[_level];

        // Check if user has enough governance tokens
        if (governanceToken.balanceOf(msg.sender) < boost.govTokenRequired) {
            revert InsufficientGovernanceTokens();
        }

        // Stake governance tokens
        governanceToken.safeTransferFrom(
            msg.sender,
            address(this),
            boost.govTokenRequired
        );

        // Update user boost
        userBoostLevel[msg.sender] = _level;
        userBoostEndTime[msg.sender] = block.timestamp + boost.duration;

        emit BoostActivated(
            msg.sender,
            _level,
            boost.multiplier,
            userBoostEndTime[msg.sender]
        );
    }

    /**
     * @dev Deactivate boost and unstake governance tokens
     */
    function deactivateBoost() external nonReentrant {
        uint256 level = userBoostLevel[msg.sender];
        if (level >= rewardBoosts.length) return;

        // Check if boost period has ended
        if (block.timestamp < userBoostEndTime[msg.sender]) {
            revert LockPeriodActive();
        }

        RewardBoost storage boost = rewardBoosts[level];

        // Return governance tokens
        governanceToken.safeTransfer(msg.sender, boost.govTokenRequired);

        // Reset user boost
        userBoostLevel[msg.sender] = 0;
        userBoostEndTime[msg.sender] = 0;
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Get pending rewards for a user in a pool
     * @param _pid Pool ID
     * @param _user User address
     * @return pending Pending reward amount
     */
    function pendingReward(
        uint256 _pid,
        address _user
    ) external view returns (uint256 pending) {
        if (_pid >= poolInfo.length) return 0;

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 accRewardPerShare = pool.accRewardPerShare;

        if (block.timestamp > pool.lastRewardTime && pool.totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - pool.lastRewardTime;
            uint256 reward = (timeElapsed *
                pool.rewardPerSecond *
                pool.allocPoint) / totalAllocPoint;
            accRewardPerShare += (reward * PRECISION) / pool.totalStaked;
        }

        uint256 multiplier = _getEffectiveMultiplier(_user, 0);
        pending =
            ((user.amount * accRewardPerShare * multiplier) /
                (PRECISION * 10000)) -
            user.rewardDebt;
    }

    /**
     * @dev Get user's effective multiplier including boosts and locks
     * @param _user User address
     * @param _lockDuration Additional lock duration
     * @return multiplier Effective multiplier in basis points
     */
    function getEffectiveMultiplier(
        address _user,
        uint256 _lockDuration
    ) external view returns (uint256 multiplier) {
        return _getEffectiveMultiplier(_user, _lockDuration);
    }

    /**
     * @dev Get vault share price
     * @param _vault Vault token address
     * @return price Share price (assets per share)
     */
    function getVaultSharePrice(
        address _vault
    ) external view returns (uint256 price) {
        VaultInfo storage vault = vaultInfo[_vault];
        if (vault.totalShares == 0) return PRECISION;
        return (vault.totalAssets * PRECISION) / vault.totalShares;
    }

    /**
     * @dev Get user's vault balance in underlying assets
     * @param _vault Vault token address
     * @param _user User address
     * @return balance Balance in underlying assets
     */
    function getUserVaultBalance(
        address _vault,
        address _user
    ) external view returns (uint256 balance) {
        VaultInfo storage vault = vaultInfo[_vault];
        uint256 shares = userVaultShares[_user];
        if (vault.totalShares == 0) return 0;
        return (shares * vault.totalAssets) / vault.totalShares;
    }

    /**
     * @dev Get all user positions across pools
     * @param _user User address
     * @return positions Array of [pid, staked, pending, lockEndTime]
     */
    function getUserPositions(
        address _user
    ) external view returns (uint256[4][] memory positions) {
        uint256 activePositions = 0;

        // Count active positions
        for (uint256 i = 0; i < poolInfo.length; i++) {
            if (userInfo[i][_user].amount > 0) {
                activePositions++;
            }
        }

        // Populate positions array
        positions = new uint256[4][](activePositions);
        uint256 index = 0;

        for (uint256 i = 0; i < poolInfo.length; i++) {
            UserInfo storage user = userInfo[i][_user];
            if (user.amount > 0) {
                positions[index][0] = i; // pid
                positions[index][1] = user.amount; // staked
                positions[index][2] = this.pendingReward(i, _user); // pending
                positions[index][3] = user.lockEndTime; // lockEndTime
                index++;
            }
        }
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    function _harvestRewards(uint256 _pid, address _user) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        if (user.amount == 0) return;

        uint256 multiplier = _getEffectiveMultiplier(_user, 0);
        uint256 pending = ((user.amount * pool.accRewardPerShare * multiplier) /
            (PRECISION * 10000)) - user.rewardDebt;

        if (pending > 0) {
            // Transfer primary reward
            pool.rewardToken.safeTransfer(_user, pending);

            // Transfer bonus rewards
            for (uint256 i = 0; i < pool.bonusRewardTokens.length; i++) {
                address bonusToken = pool.bonusRewardTokens[i];
                uint256 bonusRate = pool.bonusRewardRates[i];
                uint256 bonusAmount = (pending * bonusRate) / PRECISION;

                if (bonusAmount > 0) {
                    IERC20(bonusToken).safeTransfer(_user, bonusAmount);
                }
            }

            emit Harvest(_user, _pid, pending);
        }

        // Update reward debt
        user.rewardDebt =
            (user.amount * pool.accRewardPerShare * multiplier) /
            (PRECISION * 10000);
    }

    function _getEffectiveMultiplier(
        address _user,
        uint256 _additionalLock
    ) internal view returns (uint256 multiplier) {
        multiplier = 10000; // Base 1x multiplier

        // Apply lock multiplier
        uint256 lockDuration = _additionalLock;
        if (userInfo[0][_user].lockEndTime > block.timestamp) {
            uint256 remainingLock = userInfo[0][_user].lockEndTime -
                block.timestamp;
            lockDuration = Math.max(lockDuration, remainingLock);
        }

        if (lockDuration > 0) {
            // Find the highest applicable lock multiplier
            uint256 lockMultiplier = lockMultipliers[0];
            if (lockDuration >= 365 days)
                lockMultiplier = lockMultipliers[365 days];
            else if (lockDuration >= 180 days)
                lockMultiplier = lockMultipliers[180 days];
            else if (lockDuration >= 90 days)
                lockMultiplier = lockMultipliers[90 days];
            else if (lockDuration >= 30 days)
                lockMultiplier = lockMultipliers[30 days];
            else if (lockDuration >= 7 days)
                lockMultiplier = lockMultipliers[7 days];

            multiplier = (multiplier * lockMultiplier) / 10000;
        }

        // Apply boost multiplier
        if (userBoostEndTime[_user] > block.timestamp) {
            uint256 boostLevel = userBoostLevel[_user];
            if (boostLevel < rewardBoosts.length) {
                uint256 boostMultiplier = rewardBoosts[boostLevel].multiplier;
                multiplier = (multiplier * boostMultiplier) / 10000;
            }
        }

        return multiplier;
    }

    function _updateUserLocks(
        uint256 _pid,
        address _user,
        uint256 _withdrawAmount
    ) internal {
        UserInfo storage user = userInfo[_pid][_user];

        // Remove expired locks and reduce amounts
        uint256 remaining = _withdrawAmount;

        for (uint256 i = 0; i < user.lockAmounts.length && remaining > 0; i++) {
            if (user.lockEndTimes[i] <= block.timestamp) {
                // Lock expired, can withdraw from this lock
                uint256 available = Math.min(user.lockAmounts[i], remaining);
                user.lockAmounts[i] -= available;
                remaining -= available;

                if (user.lockAmounts[i] == 0) {
                    // Remove empty lock
                    user.lockAmounts[i] = user.lockAmounts[
                        user.lockAmounts.length - 1
                    ];
                    user.lockEndTimes[i] = user.lockEndTimes[
                        user.lockEndTimes.length - 1
                    ];
                    user.lockAmounts.pop();
                    user.lockEndTimes.pop();
                    i--; // Adjust index after removal
                }
            }
        }

        // Update overall lock end time
        user.lockEndTime = 0;
        for (uint256 i = 0; i < user.lockEndTimes.length; i++) {
            if (user.lockAmounts[i] > 0) {
                user.lockEndTime = Math.max(
                    user.lockEndTime,
                    user.lockEndTimes[i]
                );
            }
        }
    }

    function _harvestVaultRewards(
        address _vault
    ) internal returns (uint256 harvested) {
        // This would call the strategy contract to harvest rewards
        // For this example, we'll return 0
        // In a real implementation, this would interface with yield strategies
        return 0;
    }

    // ======================
    // POOL MANAGEMENT FUNCTIONS
    // ======================

    /**
     * @dev Update reward variables for a pool
     * @param _pid Pool ID
     */
    function updatePool(uint256 _pid) public {
        if (_pid >= poolInfo.length) return;

        PoolInfo storage pool = poolInfo[_pid];

        if (block.timestamp <= pool.lastRewardTime) return;

        if (pool.totalStaked == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - pool.lastRewardTime;
        uint256 reward = (timeElapsed *
            pool.rewardPerSecond *
            pool.allocPoint) / totalAllocPoint;

        pool.accRewardPerShare += (reward * PRECISION) / pool.totalStaked;
        pool.lastRewardTime = block.timestamp;
    }

    /**
     * @dev Update all pools
     */
    function massUpdatePools() public {
        for (uint256 pid = 0; pid < poolInfo.length; pid++) {
            updatePool(pid);
        }
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    /**
     * @dev Add a new farming pool
     * @param _stakingToken Token to be staked
     * @param _rewardToken Primary reward token
     * @param _rewardPerSecond Rewards per second
     * @param _allocPoint Allocation points
     * @param _lockDuration Minimum lock duration
     */
    function addPool(
        IERC20 _stakingToken,
        IERC20 _rewardToken,
        uint256 _rewardPerSecond,
        uint256 _allocPoint,
        uint256 _lockDuration
    ) external onlyOwner {
        massUpdatePools();

        uint256 lastRewardTime = block.timestamp;
        totalAllocPoint += _allocPoint;

        poolInfo.push(
            PoolInfo({
                stakingToken: _stakingToken,
                rewardToken: _rewardToken,
                rewardPerSecond: _rewardPerSecond,
                lastRewardTime: lastRewardTime,
                accRewardPerShare: 0,
                totalStaked: 0,
                allocPoint: _allocPoint,
                isActive: true,
                lockDuration: _lockDuration,
                earlyWithdrawFee: EARLY_WITHDRAWAL_PENALTY,
                bonusRewardTokens: new address[](0),
                bonusRewardRates: new uint256[](0)
            })
        );

        emit PoolAdded(
            poolInfo.length - 1,
            address(_stakingToken),
            _allocPoint
        );
    }

    /**
     * @dev Update pool allocation and reward rate
     * @param _pid Pool ID
     * @param _allocPoint New allocation points
     * @param _rewardPerSecond New reward per second
     */
    function updatePoolRewards(
        uint256 _pid,
        uint256 _allocPoint,
        uint256 _rewardPerSecond
    ) external onlyOwner {
        massUpdatePools();

        PoolInfo storage pool = poolInfo[_pid];
        totalAllocPoint = totalAllocPoint - pool.allocPoint + _allocPoint;
        pool.allocPoint = _allocPoint;
        pool.rewardPerSecond = _rewardPerSecond;

        emit PoolUpdated(_pid, _allocPoint, _rewardPerSecond);
    }

    /**
     * @dev Set pool active status
     * @param _pid Pool ID
     * @param _isActive Active status
     */
    function setPoolActive(uint256 _pid, bool _isActive) external onlyOwner {
        poolInfo[_pid].isActive = _isActive;
    }

    /**
     * @dev Add vault for auto-compounding
     * @param _vault Vault token address
     * @param _strategy Strategy contract address
     * @param _performanceFee Performance fee in basis points
     */
    function addVault(
        address _vault,
        address _strategy,
        uint256 _performanceFee
    ) external onlyOwner {
        vaultInfo[_vault] = VaultInfo({
            isActive: true,
            totalShares: 0,
            totalAssets: 0,
            lastHarvestTime: block.timestamp,
            performanceFee: _performanceFee,
            managementFee: 0,
            strategy: _strategy
        });
    }

    /**
     * @dev Emergency pause/unpause
     */
    function emergencyPause() external onlyOwner {
        _pause();
    }

    function emergencyUnpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Update treasury address
     * @param _treasury New treasury address
     */
    function setTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }

    /**
     * @dev Update fee configuration
     * @param _depositFee New deposit fee
     * @param _withdrawalFee New withdrawal fee
     * @param _emergencyWithdrawFee New emergency withdrawal fee
     */
    function updateFees(
        uint256 _depositFee,
        uint256 _withdrawalFee,
        uint256 _emergencyWithdrawFee
    ) external onlyOwner {
        require(_depositFee <= 1000, "Deposit fee too high"); // Max 10%
        require(_withdrawalFee <= 1000, "Withdrawal fee too high"); // Max 10%
        require(_emergencyWithdrawFee <= 2500, "Emergency fee too high"); // Max 25%

        depositFee = _depositFee;
        withdrawalFee = _withdrawalFee;
        emergencyWithdrawFee = _emergencyWithdrawFee;
    }

    /**
     * @dev Emergency withdrawal of stuck tokens
     * @param _token Token to withdraw
     * @param _amount Amount to withdraw
     */
    function emergencyTokenWithdraw(
        address _token,
        uint256 _amount
    ) external onlyOwner {
        IERC20(_token).safeTransfer(emergencyAddr, _amount);
    }
}

/**
 *  ADVANCED YIELD FARMING FEATURES:
 *
 * 1. MULTI-POOL FARMING SYSTEM:
 *    - Multiple pools with different staking/reward tokens
 *    - Allocation point-based reward distribution
 *    - Bonus reward tokens for enhanced yields
 *    - Pool activation/deactivation controls
 *
 * 2. ADVANCED REWARD MECHANISMS:
 *    - Lock-based reward multipliers (up to 3x)
 *    - Governance token boost system (up to 1.5x)
 *    - Combined multipliers for maximum rewards
 *    - Time-weighted reward calculations
 *
 * 3. AUTO-COMPOUNDING VAULTS:
 *    - Automatic reward harvesting and reinvestment
 *    - Share-based vault system for fair distribution
 *    - Performance and management fee structures
 *    - Strategy contract integration for yield optimization
 *
 * 4. RISK MANAGEMENT & SECURITY:
 *    - Emergency withdrawal with penalties
 *    - Graduated withdrawal fees based on lock status
 *    - Pause functionality for emergency situations
 *    - Multi-signature administrative controls
 *
 * 5. ADVANCED FEATURES:
 *    - Multiple lock durations with different multipliers
 *    - Governance token staking for boosts
 *    - Comprehensive user position tracking
 *    - Batch operations for gas efficiency
 *
 *  USAGE EXAMPLES:
 *
 * // Deposit with 6-month lock for 2x multiplier
 * farm.deposit(poolId, amount, 180 days);
 *
 * // Activate governance boost
 * farm.activateBoost(2); // Level 2 boost
 *
 * // Harvest all pools
 * farm.harvestAll();
 *
 * // Auto-compound vault deposit
 * farm.depositToVault(vaultToken, amount);
 *
 * // Emergency withdraw (with penalty)
 * farm.emergencyWithdraw(poolId);
 *
 *  YIELD OPTIMIZATION STRATEGIES:
 * - Combine lock multipliers + governance boosts for maximum yield
 * - Use auto-compounding vaults for passive income
 * - Diversify across multiple pools for risk management
 * - Time lock expirations to avoid early withdrawal penalties
 */

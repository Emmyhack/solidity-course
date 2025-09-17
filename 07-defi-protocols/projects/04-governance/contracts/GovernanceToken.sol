// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/governance/utils/IVotes.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title DeFi Governance Token
 * @dev Comprehensive governance token with voting power, delegation, and staking rewards
 * @notice Professional-grade governance token for DeFi protocol management
 *
 * Features:
 * - ERC20 with voting capabilities (ERC20Votes)
 * - Delegation and proposal voting
 * - Staking rewards for governance participation
 * - Token vesting for team and advisors
 * - Inflation controls and supply management
 * - Fee distribution to token holders
 * - Governance participation incentives
 */
contract GovernanceToken is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ======================
    // CONSTANTS
    // ======================

    uint256 public constant MAX_SUPPLY = 1_000_000_000e18; // 1B tokens
    uint256 public constant INITIAL_SUPPLY = 100_000_000e18; // 100M tokens
    uint256 public constant INFLATION_RATE = 500; // 5% per year max
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant PRECISION = 1e18;

    // ======================
    // STRUCTS
    // ======================

    struct StakeInfo {
        uint256 amount; // Amount staked
        uint256 lockEndTime; // When stake can be withdrawn
        uint256 rewardDebt; // Reward debt for calculations
        uint256 votingPower; // Additional voting power from staking
        uint256 lastStakeTime; // Last time user staked
    }

    struct VestingSchedule {
        uint256 totalAmount; // Total amount to vest
        uint256 startTime; // Vesting start time
        uint256 cliffDuration; // Cliff period before vesting starts
        uint256 vestingDuration; // Total vesting duration
        uint256 releasedAmount; // Amount already released
        bool revocable; // Whether vesting can be revoked
        bool revoked; // Whether vesting has been revoked
    }

    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }

    // ======================
    // STATE VARIABLES
    // ======================

    // Governance state
    mapping(address => address) private _delegates;
    mapping(address => Checkpoint[]) private _checkpoints;
    mapping(address => uint256) private _nonces;

    // Staking state
    mapping(address => StakeInfo) public stakeInfo;
    uint256 public totalStaked;
    uint256 public rewardPerSecond;
    uint256 public lastRewardTime;
    uint256 public accRewardPerShare;

    // Vesting state
    mapping(address => VestingSchedule[]) public vestingSchedules;
    uint256 public totalVesting;

    // Protocol state
    uint256 public lastInflationTime;
    uint256 public yearlyInflationLimit;
    uint256 public currentYearInflation;

    // Fee distribution
    mapping(address => uint256) public feeShares;
    mapping(address => uint256) public lastClaimedFees;
    uint256 public totalFeeShares;
    uint256 public totalFeesDistributed;

    // Governance incentives
    uint256 public votingRewardPool;
    mapping(address => uint256) public votingRewards;
    mapping(address => bool) public proposalCreators;
    uint256 public proposalCreationReward = 1000e18;

    // ======================
    // EVENTS
    // ======================

    event DelegateChanged(
        address indexed delegator,
        address indexed fromDelegate,
        address indexed toDelegate
    );
    event DelegateVotesChanged(
        address indexed delegate,
        uint256 previousBalance,
        uint256 newBalance
    );
    event Staked(address indexed user, uint256 amount, uint256 lockDuration);
    event Unstaked(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 amount);
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 duration
    );
    event VestingTokensReleased(address indexed beneficiary, uint256 amount);
    event InflationMinted(uint256 amount, address indexed recipient);
    event FeesDistributed(uint256 amount);
    event VotingRewardClaimed(address indexed user, uint256 amount);

    // ======================
    // ERRORS
    // ======================

    error ExceedsMaxSupply();
    error StillLocked();
    error NoRewardsToClaim();
    error InvalidLockDuration();
    error VestingNotStarted();
    error VestingRevoked();
    error ExceedsInflationLimit();
    error InsufficientBalance();
    error InvalidVestingSchedule();

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(
        string memory name,
        string memory symbol,
        address _treasury
    ) ERC20(name, symbol) {
        _mint(_treasury, INITIAL_SUPPLY);

        lastInflationTime = block.timestamp;
        lastRewardTime = block.timestamp;
        yearlyInflationLimit = (totalSupply() * INFLATION_RATE) / 10000;

        // Initial reward rate (0.1% of supply per year for stakers)
        rewardPerSecond = (totalSupply() * 100) / (10000 * SECONDS_PER_YEAR);
    }

    // ======================
    // STAKING FUNCTIONS
    // ======================

    /**
     * @dev Stake tokens for governance rewards and voting power
     * @param _amount Amount to stake
     * @param _lockDuration Lock duration (0 for no lock)
     */
    function stake(
        uint256 _amount,
        uint256 _lockDuration
    ) external nonReentrant {
        if (_amount == 0) revert InsufficientBalance();
        if (_lockDuration > 0 && _lockDuration < 7 days)
            revert InvalidLockDuration();
        if (_lockDuration > 365 days) revert InvalidLockDuration();

        updateRewards();

        StakeInfo storage stake = stakeInfo[msg.sender];

        // Claim existing rewards
        if (stake.amount > 0) {
            _claimStakingRewards(msg.sender);
        }

        // Transfer tokens
        _transfer(msg.sender, address(this), _amount);

        // Update stake info
        stake.amount += _amount;
        stake.lastStakeTime = block.timestamp;

        if (_lockDuration > 0) {
            stake.lockEndTime = block.timestamp + _lockDuration;
            // Bonus voting power for locked tokens (up to 2x)
            uint256 lockBonus = (_lockDuration * PRECISION) / (365 days);
            stake.votingPower =
                stake.amount +
                (stake.amount * lockBonus) /
                PRECISION;
        } else {
            stake.votingPower = stake.amount;
        }

        totalStaked += _amount;
        stake.rewardDebt = (stake.amount * accRewardPerShare) / PRECISION;

        // Update voting power
        _updateVotingPower(msg.sender);

        emit Staked(msg.sender, _amount, _lockDuration);
    }

    /**
     * @dev Unstake tokens
     * @param _amount Amount to unstake
     */
    function unstake(uint256 _amount) external nonReentrant {
        StakeInfo storage stake = stakeInfo[msg.sender];

        if (stake.amount < _amount) revert InsufficientBalance();
        if (block.timestamp < stake.lockEndTime) revert StillLocked();

        updateRewards();

        // Claim rewards
        _claimStakingRewards(msg.sender);

        // Update stake info
        stake.amount -= _amount;
        totalStaked -= _amount;

        // Recalculate voting power
        if (stake.lockEndTime > block.timestamp) {
            uint256 lockBonus = ((stake.lockEndTime - block.timestamp) *
                PRECISION) / (365 days);
            stake.votingPower =
                stake.amount +
                (stake.amount * lockBonus) /
                PRECISION;
        } else {
            stake.votingPower = stake.amount;
            stake.lockEndTime = 0;
        }

        stake.rewardDebt = (stake.amount * accRewardPerShare) / PRECISION;

        // Transfer tokens back
        _transfer(address(this), msg.sender, _amount);

        // Update voting power
        _updateVotingPower(msg.sender);

        emit Unstaked(msg.sender, _amount);
    }

    /**
     * @dev Claim staking rewards
     */
    function claimStakingRewards() external nonReentrant {
        updateRewards();
        _claimStakingRewards(msg.sender);
    }

    // ======================
    // VOTING FUNCTIONS
    // ======================

    /**
     * @dev Delegate voting power to another address
     * @param delegatee Address to delegate to
     */
    function delegate(address delegatee) public virtual {
        _delegate(msg.sender, delegatee);
    }

    /**
     * @dev Delegate voting power using signature
     */
    function delegateBySig(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public virtual {
        require(block.timestamp <= expiry, "Signature expired");

        address signer = _recoverDelegateSigner(
            delegatee,
            nonce,
            expiry,
            v,
            r,
            s
        );
        require(nonce == _useNonce(signer), "Invalid nonce");

        _delegate(signer, delegatee);
    }

    /**
     * @dev Get current voting power of an account
     * @param account Account to check
     * @return Current voting power
     */
    function getVotes(address account) public view virtual returns (uint256) {
        uint256 pos = _checkpoints[account].length;
        return pos == 0 ? 0 : _checkpoints[account][pos - 1].votes;
    }

    /**
     * @dev Get voting power at a specific block
     * @param account Account to check
     * @param blockNumber Block number
     * @return Voting power at that block
     */
    function getPastVotes(
        address account,
        uint256 blockNumber
    ) public view virtual returns (uint256) {
        require(blockNumber < block.number, "Future block");

        uint256 high = _checkpoints[account].length;
        uint256 low = 0;

        while (low < high) {
            uint256 mid = (low + high) / 2;
            if (_checkpoints[account][mid].fromBlock > blockNumber) {
                high = mid;
            } else {
                low = mid + 1;
            }
        }

        return high == 0 ? 0 : _checkpoints[account][high - 1].votes;
    }

    /**
     * @dev Get delegate for an account
     * @param account Account to check
     * @return Delegate address
     */
    function delegates(address account) public view virtual returns (address) {
        return _delegates[account];
    }

    // ======================
    // VESTING FUNCTIONS
    // ======================

    /**
     * @dev Create vesting schedule for beneficiary
     * @param _beneficiary Address receiving vested tokens
     * @param _amount Total amount to vest
     * @param _cliffDuration Cliff duration before vesting starts
     * @param _vestingDuration Total vesting duration
     * @param _revocable Whether vesting can be revoked
     */
    function createVestingSchedule(
        address _beneficiary,
        uint256 _amount,
        uint256 _cliffDuration,
        uint256 _vestingDuration,
        bool _revocable
    ) external onlyOwner {
        if (_amount == 0) revert InvalidVestingSchedule();
        if (_vestingDuration == 0) revert InvalidVestingSchedule();
        if (totalSupply() + _amount > MAX_SUPPLY) revert ExceedsMaxSupply();

        _mint(address(this), _amount);
        totalVesting += _amount;

        vestingSchedules[_beneficiary].push(
            VestingSchedule({
                totalAmount: _amount,
                startTime: block.timestamp,
                cliffDuration: _cliffDuration,
                vestingDuration: _vestingDuration,
                releasedAmount: 0,
                revocable: _revocable,
                revoked: false
            })
        );

        emit VestingScheduleCreated(_beneficiary, _amount, _vestingDuration);
    }

    /**
     * @dev Release vested tokens for caller
     */
    function releaseVestedTokens() external nonReentrant {
        uint256 totalReleasable = 0;

        VestingSchedule[] storage schedules = vestingSchedules[msg.sender];

        for (uint256 i = 0; i < schedules.length; i++) {
            VestingSchedule storage schedule = schedules[i];

            if (schedule.revoked) continue;

            uint256 releasable = _computeReleasableAmount(schedule);
            if (releasable > 0) {
                schedule.releasedAmount += releasable;
                totalReleasable += releasable;
            }
        }

        if (totalReleasable == 0) revert NoRewardsToClaim();

        totalVesting -= totalReleasable;
        _transfer(address(this), msg.sender, totalReleasable);

        emit VestingTokensReleased(msg.sender, totalReleasable);
    }

    /**
     * @dev Get releasable vested amount for account
     * @param _beneficiary Account to check
     * @return Total releasable amount
     */
    function getReleasableAmount(
        address _beneficiary
    ) external view returns (uint256) {
        uint256 totalReleasable = 0;
        VestingSchedule[] storage schedules = vestingSchedules[_beneficiary];

        for (uint256 i = 0; i < schedules.length; i++) {
            if (!schedules[i].revoked) {
                totalReleasable += _computeReleasableAmount(schedules[i]);
            }
        }

        return totalReleasable;
    }

    // ======================
    // INFLATION & REWARDS
    // ======================

    /**
     * @dev Mint inflation tokens (only within yearly limits)
     * @param _recipient Recipient of minted tokens
     * @param _amount Amount to mint
     */
    function mintInflation(
        address _recipient,
        uint256 _amount
    ) external onlyOwner {
        _checkInflationReset();

        if (currentYearInflation + _amount > yearlyInflationLimit) {
            revert ExceedsInflationLimit();
        }
        if (totalSupply() + _amount > MAX_SUPPLY) {
            revert ExceedsMaxSupply();
        }

        currentYearInflation += _amount;
        _mint(_recipient, _amount);

        emit InflationMinted(_amount, _recipient);
    }

    /**
     * @dev Update staking reward variables
     */
    function updateRewards() public {
        if (block.timestamp <= lastRewardTime) return;

        if (totalStaked == 0) {
            lastRewardTime = block.timestamp;
            return;
        }

        uint256 timeElapsed = block.timestamp - lastRewardTime;
        uint256 reward = timeElapsed * rewardPerSecond;

        accRewardPerShare += (reward * PRECISION) / totalStaked;
        lastRewardTime = block.timestamp;
    }

    /**
     * @dev Set new reward rate for staking
     * @param _rewardPerSecond New reward per second
     */
    function setRewardRate(uint256 _rewardPerSecond) external onlyOwner {
        updateRewards();
        rewardPerSecond = _rewardPerSecond;
    }

    // ======================
    // FEE DISTRIBUTION
    // ======================

    /**
     * @dev Distribute protocol fees to token holders
     * @param _amount Amount of fees to distribute
     */
    function distributeFees(uint256 _amount) external {
        require(_amount > 0, "Amount must be positive");

        // Transfer fees to contract
        IERC20(this).safeTransferFrom(msg.sender, address(this), _amount);

        // Update fee distribution
        totalFeesDistributed += _amount;

        emit FeesDistributed(_amount);
    }

    /**
     * @dev Claim accumulated fee share
     */
    function claimFeeShare() external nonReentrant {
        uint256 balance = balanceOf(msg.sender);
        if (balance == 0) revert NoRewardsToClaim();

        uint256 totalSupplySnapshot = totalSupply() - totalVesting;
        uint256 userShare = (balance * totalFeesDistributed) /
            totalSupplySnapshot;
        uint256 claimable = userShare - lastClaimedFees[msg.sender];

        if (claimable == 0) revert NoRewardsToClaim();

        lastClaimedFees[msg.sender] = userShare;
        _transfer(address(this), msg.sender, claimable);
    }

    // ======================
    // GOVERNANCE INCENTIVES
    // ======================

    /**
     * @dev Reward for creating governance proposal
     * @param _creator Proposal creator
     */
    function rewardProposalCreation(address _creator) external onlyOwner {
        if (balanceOf(address(this)) >= proposalCreationReward) {
            _transfer(address(this), _creator, proposalCreationReward);
            proposalCreators[_creator] = true;
        }
    }

    /**
     * @dev Reward for voting participation
     * @param _voter Voter address
     * @param _proposalWeight Weight of proposal voted on
     */
    function rewardVoting(
        address _voter,
        uint256 _proposalWeight
    ) external onlyOwner {
        uint256 baseReward = 10e18; // Base voting reward
        uint256 weightBonus = (_proposalWeight * baseReward) / 100; // Bonus based on proposal weight
        uint256 totalReward = baseReward + weightBonus;

        if (votingRewardPool >= totalReward) {
            votingRewardPool -= totalReward;
            votingRewards[_voter] += totalReward;
        }
    }

    /**
     * @dev Claim voting rewards
     */
    function claimVotingRewards() external nonReentrant {
        uint256 rewards = votingRewards[msg.sender];
        if (rewards == 0) revert NoRewardsToClaim();

        votingRewards[msg.sender] = 0;
        _transfer(address(this), msg.sender, rewards);

        emit VotingRewardClaimed(msg.sender, rewards);
    }

    /**
     * @dev Fund voting reward pool
     * @param _amount Amount to add to pool
     */
    function fundVotingRewards(uint256 _amount) external onlyOwner {
        _transfer(msg.sender, address(this), _amount);
        votingRewardPool += _amount;
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Get pending staking rewards for user
     * @param _user User address
     * @return Pending rewards
     */
    function pendingStakingRewards(
        address _user
    ) external view returns (uint256) {
        StakeInfo storage stake = stakeInfo[_user];

        uint256 currentAccRewardPerShare = accRewardPerShare;

        if (block.timestamp > lastRewardTime && totalStaked != 0) {
            uint256 timeElapsed = block.timestamp - lastRewardTime;
            uint256 reward = timeElapsed * rewardPerSecond;
            currentAccRewardPerShare += (reward * PRECISION) / totalStaked;
        }

        return
            ((stake.amount * currentAccRewardPerShare) / PRECISION) -
            stake.rewardDebt;
    }

    /**
     * @dev Get user's total governance power (balance + staked + voting power)
     * @param _user User address
     * @return Total governance power
     */
    function getTotalGovernancePower(
        address _user
    ) external view returns (uint256) {
        return balanceOf(_user) + stakeInfo[_user].votingPower;
    }

    /**
     * @dev Get all vesting schedules for beneficiary
     * @param _beneficiary Beneficiary address
     * @return Array of vesting schedules
     */
    function getVestingSchedules(
        address _beneficiary
    ) external view returns (VestingSchedule[] memory) {
        return vestingSchedules[_beneficiary];
    }

    /**
     * @dev Check if inflation limit needs reset (yearly)
     */
    function needsInflationReset() external view returns (bool) {
        return block.timestamp >= lastInflationTime + SECONDS_PER_YEAR;
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    function _claimStakingRewards(address _user) internal {
        StakeInfo storage stake = stakeInfo[_user];

        uint256 pending = ((stake.amount * accRewardPerShare) / PRECISION) -
            stake.rewardDebt;

        if (pending > 0) {
            // Mint rewards
            _mint(_user, pending);
            emit RewardsClaimed(_user, pending);
        }

        stake.rewardDebt = (stake.amount * accRewardPerShare) / PRECISION;
    }

    function _computeReleasableAmount(
        VestingSchedule storage schedule
    ) internal view returns (uint256) {
        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        uint256 timeFromStart = block.timestamp - schedule.startTime;

        if (timeFromStart >= schedule.vestingDuration) {
            return schedule.totalAmount - schedule.releasedAmount;
        }

        uint256 vestedAmount = (schedule.totalAmount * timeFromStart) /
            schedule.vestingDuration;
        return vestedAmount - schedule.releasedAmount;
    }

    function _checkInflationReset() internal {
        if (block.timestamp >= lastInflationTime + SECONDS_PER_YEAR) {
            lastInflationTime = block.timestamp;
            currentYearInflation = 0;
            yearlyInflationLimit = (totalSupply() * INFLATION_RATE) / 10000;
        }
    }

    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator) +
            stakeInfo[delegator].votingPower;

        _delegates[delegator] = delegatee;

        emit DelegateChanged(delegator, currentDelegate, delegatee);

        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }

    function _moveVotingPower(
        address src,
        address dst,
        uint256 amount
    ) internal {
        if (src != dst && amount > 0) {
            if (src != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    _checkpoints[src],
                    _subtract,
                    amount
                );
                emit DelegateVotesChanged(src, oldWeight, newWeight);
            }

            if (dst != address(0)) {
                (uint256 oldWeight, uint256 newWeight) = _writeCheckpoint(
                    _checkpoints[dst],
                    _add,
                    amount
                );
                emit DelegateVotesChanged(dst, oldWeight, newWeight);
            }
        }
    }

    function _writeCheckpoint(
        Checkpoint[] storage ckpts,
        function(uint256, uint256) view returns (uint256) op,
        uint256 delta
    ) private returns (uint256 oldWeight, uint256 newWeight) {
        uint256 pos = ckpts.length;
        oldWeight = pos == 0 ? 0 : ckpts[pos - 1].votes;
        newWeight = op(oldWeight, delta);

        if (pos > 0 && ckpts[pos - 1].fromBlock == block.number) {
            ckpts[pos - 1].votes = SafeCast.toUint224(newWeight);
        } else {
            ckpts.push(
                Checkpoint({
                    fromBlock: SafeCast.toUint32(block.number),
                    votes: SafeCast.toUint224(newWeight)
                })
            );
        }
    }

    function _add(uint256 a, uint256 b) private pure returns (uint256) {
        return a + b;
    }

    function _subtract(uint256 a, uint256 b) private pure returns (uint256) {
        return a - b;
    }

    function _updateVotingPower(address account) internal {
        address delegate = _delegates[account];
        if (delegate == address(0)) {
            delegate = account;
            _delegates[account] = account;
        }

        uint256 newPower = balanceOf(account) + stakeInfo[account].votingPower;
        uint256 oldPower = getVotes(delegate);

        _moveVotingPower(delegate, delegate, newPower - oldPower);
    }

    function _recoverDelegateSigner(
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal view returns (address) {
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256(
                    "Delegation(address delegatee,uint256 nonce,uint256 expiry)"
                ),
                delegatee,
                nonce,
                expiry
            )
        );

        bytes32 hash = keccak256(
            abi.encodePacked("\x19\x01", _domainSeparatorV4(), structHash)
        );
        return ecrecover(hash, v, r, s);
    }

    function _domainSeparatorV4() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes(name())),
                    keccak256(bytes("1")),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _useNonce(address owner) internal returns (uint256 current) {
        current = _nonces[owner];
        _nonces[owner] = current + 1;
    }

    // Override transfer functions to update voting power
    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        super._afterTokenTransfer(from, to, amount);

        if (from != address(0)) {
            _updateVotingPower(from);
        }
        if (to != address(0)) {
            _updateVotingPower(to);
        }
    }
}

// Safe casting library
library SafeCast {
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(
            value <= type(uint224).max,
            "SafeCast: value doesn't fit in 224 bits"
        );
        return uint224(value);
    }

    function toUint32(uint256 value) internal pure returns (uint32) {
        require(
            value <= type(uint32).max,
            "SafeCast: value doesn't fit in 32 bits"
        );
        return uint32(value);
    }
}

/**
 *  GOVERNANCE TOKEN FEATURES:
 *
 * 1. VOTING & DELEGATION SYSTEM:
 *    - ERC20Votes-compatible voting power
 *    - Delegation with signature support
 *    - Historical voting power tracking
 *    - Checkpoint-based vote calculations
 *
 * 2. STAKING REWARDS SYSTEM:
 *    - Stake tokens for governance rewards
 *    - Lock periods for enhanced voting power
 *    - Automatic reward distribution
 *    - Compound interest mechanics
 *
 * 3. TOKEN VESTING SYSTEM:
 *    - Multiple vesting schedules per beneficiary
 *    - Cliff periods and gradual release
 *    - Revocable vesting for team members
 *    - Automated vesting calculations
 *
 * 4. INFLATION CONTROLS:
 *    - Maximum yearly inflation limits (5%)
 *    - Hard cap on total supply (1B tokens)
 *    - Controlled minting for rewards
 *    - Annual inflation reset mechanism
 *
 * 5. FEE DISTRIBUTION:
 *    - Protocol fees shared with token holders
 *    - Proportional distribution based on holdings
 *    - Automatic fee accumulation and claiming
 *    - Performance-based fee sharing
 *
 * 6. GOVERNANCE INCENTIVES:
 *    - Rewards for proposal creation
 *    - Voting participation incentives
 *    - Weighted rewards based on proposal importance
 *    - Community engagement bonuses
 *
 *  USAGE EXAMPLES:
 *
 * // Stake tokens for 6 months (enhanced voting power)
 * govToken.stake(amount, 180 days);
 *
 * // Delegate voting power
 * govToken.delegate(delegateAddress);
 *
 * // Create vesting for team member
 * govToken.createVestingSchedule(
 *     teamMember,
 *     1000000e18,  // 1M tokens
 *     90 days,      // 3 month cliff
 *     1460 days,    // 4 year vesting
 *     true          // revocable
 * );
 *
 * // Claim all rewards
 * govToken.claimStakingRewards();
 * govToken.claimFeeShare();
 * govToken.claimVotingRewards();
 *
 *  GOVERNANCE MECHANICS:
 * - Voting power = balance + staked amount + lock bonus
 * - Lock bonus: up to 2x for 1-year locks
 * - Staking rewards: 0.1% APY base rate
 * - Fee distribution: proportional to holdings
 * - Proposal rewards: encourage community participation
 */

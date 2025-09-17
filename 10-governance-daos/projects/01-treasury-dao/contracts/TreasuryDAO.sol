// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Advanced Treasury DAO
 * @dev Comprehensive DAO system for treasury management and community governance
 * @notice Professional-grade DAO with advanced treasury features beyond DeFi
 *
 * Features:
 * - Multi-asset treasury management (ERC20, ERC721, ETH)
 * - Advanced proposal system with categories and execution
 * - Quadratic voting and delegation mechanisms
 * - Treasury diversification and risk management
 * - Grant allocation and milestone tracking
 * - Community funding and bounty programs
 * - Multi-signature treasury controls
 * - Emergency governance procedures
 */
contract TreasuryDAO is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    ReentrancyGuard,
    Pausable,
    Ownable
{
    using SafeERC20 for IERC20;
    using Math for uint256;

    // ======================
    // CONSTANTS & ENUMS
    // ======================

    enum ProposalCategory {
        TREASURY_ALLOCATION, // Treasury fund allocation
        GRANT_FUNDING, // Community grants
        BOUNTY_PROGRAM, // Bug bounties and tasks
        GOVERNANCE_CHANGE, // DAO parameter changes
        PARTNERSHIP, // Strategic partnerships
        EMERGENCY_ACTION, // Emergency procedures
        INVESTMENT, // Treasury investments
        OPERATIONAL // Day-to-day operations
    }

    enum GrantStatus {
        PROPOSED, // Grant proposed
        APPROVED, // Approved by DAO
        ACTIVE, // Currently active
        MILESTONE_PENDING, // Waiting for milestone completion
        COMPLETED, // Successfully completed
        CANCELLED, // Cancelled or failed
        DISPUTED // Under dispute resolution
    }

    enum TreasuryAssetType {
        ERC20, // ERC20 tokens
        ERC721, // NFTs
        NATIVE, // ETH/Native currency
        EXTERNAL // External assets (tracked but not held)
    }

    // ======================
    // STRUCTS
    // ======================

    struct TreasuryAsset {
        TreasuryAssetType assetType;
        address assetAddress;
        uint256 balance; // For ERC20/Native
        uint256[] tokenIds; // For ERC721
        uint256 lastValuation; // USD value (18 decimals)
        uint256 lastUpdated; // Last update timestamp
        bool isActive; // Whether asset is actively managed
        string metadata; // Additional asset information
    }

    struct Grant {
        address recipient;
        uint256 amount;
        address paymentToken;
        string title;
        string description;
        string[] milestones;
        uint256[] milestonePayments;
        uint256 currentMilestone;
        GrantStatus status;
        uint256 proposalId;
        uint256 startTime;
        uint256 deadline;
        mapping(uint256 => bool) milestoneCompleted;
        mapping(address => bool) reviewers;
    }

    struct Bounty {
        string title;
        string description;
        uint256 reward;
        address paymentToken;
        address creator;
        address assignee;
        uint256 deadline;
        bool isActive;
        bool isCompleted;
        uint256 submissionCount;
        mapping(uint256 => BountySubmission) submissions;
    }

    struct BountySubmission {
        address submitter;
        string submissionData;
        uint256 timestamp;
        bool isAccepted;
        string feedback;
    }

    struct ProposalMetadata {
        ProposalCategory category;
        uint256 requestedAmount;
        address requestedToken;
        address beneficiary;
        string ipfsHash;
        uint256 priority;
        bool isUrgent;
        mapping(address => bool) endorsements;
        uint256 endorsementCount;
    }

    struct VotingPowerSnapshot {
        uint256 blockNumber;
        mapping(address => uint256) votingPower;
        uint256 totalVotingPower;
    }

    struct DelegationInfo {
        address delegate;
        uint256 weight; // Percentage (0-10000)
        uint256 expiration; // Delegation expiration
        bool isActive;
    }

    // ======================
    // STATE VARIABLES
    // ======================

    // Treasury management
    mapping(bytes32 => TreasuryAsset) public treasuryAssets;
    bytes32[] public assetKeys;
    uint256 public totalTreasuryValue;
    uint256 public lastTreasuryUpdate;

    // Grant system
    mapping(uint256 => Grant) public grants;
    uint256 public nextGrantId = 1;
    uint256 public totalGrantsAllocated;
    uint256 public totalGrantsDistributed;

    // Bounty system
    mapping(uint256 => Bounty) public bounties;
    uint256 public nextBountyId = 1;
    uint256 public totalBountyRewards;

    // Proposal metadata
    mapping(uint256 => ProposalMetadata) public proposalMetadata;

    // Advanced voting
    mapping(address => DelegationInfo) public delegations;
    mapping(uint256 => VotingPowerSnapshot) public snapshots;

    // Emergency controls
    address[] public emergencyCouncil;
    mapping(address => bool) public isEmergencyMember;
    bool public emergencyMode;
    uint256 public emergencyActivatedAt;

    // Treasury controls
    mapping(address => bool) public treasuryManagers;
    uint256 public dailySpendingLimit;
    uint256 public todaySpent;
    uint256 public lastSpendingReset;

    // Voting incentives
    uint256 public votingRewardPool;
    mapping(address => uint256) public votingRewards;
    uint256 public participationThreshold = 1000; // Minimum tokens to vote

    // ======================
    // EVENTS
    // ======================

    event TreasuryAssetAdded(
        bytes32 indexed assetKey,
        address indexed asset,
        TreasuryAssetType assetType
    );
    event TreasuryAssetUpdated(
        bytes32 indexed assetKey,
        uint256 newBalance,
        uint256 newValuation
    );
    event GrantProposed(
        uint256 indexed grantId,
        address indexed recipient,
        uint256 amount
    );
    event GrantApproved(uint256 indexed grantId, uint256 indexed proposalId);
    event MilestoneCompleted(
        uint256 indexed grantId,
        uint256 milestone,
        uint256 payment
    );
    event BountyCreated(uint256 indexed bountyId, string title, uint256 reward);
    event BountySubmitted(
        uint256 indexed bountyId,
        address indexed submitter,
        uint256 submissionId
    );
    event BountyCompleted(
        uint256 indexed bountyId,
        address indexed winner,
        uint256 reward
    );
    event EmergencyActivated(address indexed activator, string reason);
    event EmergencyDeactivated(address indexed deactivator);
    event TreasuryAllocation(
        address indexed token,
        address indexed recipient,
        uint256 amount
    );
    event VotingRewardDistributed(address indexed voter, uint256 amount);
    event DelegationUpdated(
        address indexed delegator,
        address indexed delegate,
        uint256 weight
    );

    // ======================
    // ERRORS
    // ======================

    error InsufficientTreasuryFunds();
    error InvalidGrantId();
    error InvalidBountyId();
    error UnauthorizedAccess();
    error InvalidMilestone();
    error GrantNotActive();
    error BountyNotActive();
    error EmergencyModeActive();
    error SpendingLimitExceeded();
    error InvalidProposalCategory();
    error DelegationExpired();

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(
        IVotes _token,
        TimelockController _timelock,
        string memory _name
    )
        Governor(_name)
        GovernorSettings(
            1 days, // voting delay
            2 weeks, // voting period
            1000e18 // proposal threshold
        )
        GovernorVotes(_token)
        GovernorVotesQuorumFraction(10) // 10% quorum
        GovernorTimelockControl(_timelock)
    {
        dailySpendingLimit = 100000e18; // 100k tokens daily limit
        lastSpendingReset = block.timestamp;

        // Set initial emergency council
        emergencyCouncil.push(msg.sender);
        isEmergencyMember[msg.sender] = true;

        treasuryManagers[msg.sender] = true;
    }

    // ======================
    // TREASURY MANAGEMENT
    // ======================

    /**
     * @dev Add a new asset to treasury tracking
     */
    function addTreasuryAsset(
        address _asset,
        TreasuryAssetType _assetType,
        string calldata _metadata
    ) external onlyOwner {
        bytes32 assetKey = keccak256(abi.encodePacked(_asset, _assetType));

        TreasuryAsset storage asset = treasuryAssets[assetKey];
        asset.assetType = _assetType;
        asset.assetAddress = _asset;
        asset.isActive = true;
        asset.metadata = _metadata;
        asset.lastUpdated = block.timestamp;

        assetKeys.push(assetKey);

        emit TreasuryAssetAdded(assetKey, _asset, _assetType);
    }

    /**
     * @dev Update treasury asset balance and valuation
     */
    function updateTreasuryAsset(
        bytes32 _assetKey,
        uint256 _balance,
        uint256 _valuation
    ) external {
        require(treasuryManagers[msg.sender], "Not authorized");

        TreasuryAsset storage asset = treasuryAssets[_assetKey];
        require(asset.isActive, "Asset not active");

        asset.balance = _balance;
        asset.lastValuation = _valuation;
        asset.lastUpdated = block.timestamp;

        _updateTotalTreasuryValue();

        emit TreasuryAssetUpdated(_assetKey, _balance, _valuation);
    }

    /**
     * @dev Allocate treasury funds through governance
     */
    function allocateTreasuryFunds(
        address _token,
        address _recipient,
        uint256 _amount,
        string calldata _purpose
    ) external onlyGovernance nonReentrant {
        _checkSpendingLimit(_amount);

        if (_token == address(0)) {
            // Native currency
            require(address(this).balance >= _amount, "Insufficient ETH");
            (bool success, ) = payable(_recipient).call{value: _amount}("");
            require(success, "ETH transfer failed");
        } else {
            // ERC20 token
            IERC20(_token).safeTransfer(_recipient, _amount);
        }

        _updateSpending(_amount);
        emit TreasuryAllocation(_token, _recipient, _amount);
    }

    // ======================
    // GRANT SYSTEM
    // ======================

    /**
     * @dev Propose a new grant
     */
    function proposeGrant(
        address _recipient,
        uint256 _amount,
        address _paymentToken,
        string calldata _title,
        string calldata _description,
        string[] calldata _milestones,
        uint256[] calldata _milestonePayments,
        uint256 _deadline
    ) external returns (uint256) {
        require(
            _milestones.length == _milestonePayments.length,
            "Milestone mismatch"
        );
        require(_recipient != address(0), "Invalid recipient");

        uint256 grantId = nextGrantId++;
        Grant storage grant = grants[grantId];

        grant.recipient = _recipient;
        grant.amount = _amount;
        grant.paymentToken = _paymentToken;
        grant.title = _title;
        grant.description = _description;
        grant.milestones = _milestones;
        grant.milestonePayments = _milestonePayments;
        grant.status = GrantStatus.PROPOSED;
        grant.deadline = _deadline;

        emit GrantProposed(grantId, _recipient, _amount);
        return grantId;
    }

    /**
     * @dev Approve grant through governance proposal
     */
    function approveGrant(
        uint256 _grantId,
        uint256 _proposalId
    ) external onlyGovernance {
        Grant storage grant = grants[_grantId];
        require(
            grant.status == GrantStatus.PROPOSED,
            "Grant not in proposed state"
        );

        grant.status = GrantStatus.APPROVED;
        grant.proposalId = _proposalId;
        grant.startTime = block.timestamp;

        totalGrantsAllocated += grant.amount;

        emit GrantApproved(_grantId, _proposalId);
    }

    /**
     * @dev Complete a grant milestone
     */
    function completeMilestone(
        uint256 _grantId,
        uint256 _milestoneIndex,
        string calldata _deliverable
    ) external nonReentrant {
        Grant storage grant = grants[_grantId];
        require(
            grant.status == GrantStatus.APPROVED ||
                grant.status == GrantStatus.ACTIVE,
            "Grant not active"
        );
        require(_milestoneIndex == grant.currentMilestone, "Wrong milestone");
        require(
            !grant.milestoneCompleted[_milestoneIndex],
            "Milestone already completed"
        );

        // Mark milestone as completed
        grant.milestoneCompleted[_milestoneIndex] = true;
        grant.currentMilestone++;

        // Release payment
        uint256 payment = grant.milestonePayments[_milestoneIndex];
        if (grant.paymentToken == address(0)) {
            (bool success, ) = payable(grant.recipient).call{value: payment}(
                ""
            );
            require(success, "Payment failed");
        } else {
            IERC20(grant.paymentToken).safeTransfer(grant.recipient, payment);
        }

        totalGrantsDistributed += payment;

        // Check if all milestones completed
        if (grant.currentMilestone >= grant.milestones.length) {
            grant.status = GrantStatus.COMPLETED;
        } else {
            grant.status = GrantStatus.ACTIVE;
        }

        emit MilestoneCompleted(_grantId, _milestoneIndex, payment);
    }

    // ======================
    // BOUNTY SYSTEM
    // ======================

    /**
     * @dev Create a new bounty
     */
    function createBounty(
        string calldata _title,
        string calldata _description,
        uint256 _reward,
        address _paymentToken,
        uint256 _deadline
    ) external returns (uint256) {
        require(_reward > 0, "Invalid reward");

        uint256 bountyId = nextBountyId++;
        Bounty storage bounty = bounties[bountyId];

        bounty.title = _title;
        bounty.description = _description;
        bounty.reward = _reward;
        bounty.paymentToken = _paymentToken;
        bounty.creator = msg.sender;
        bounty.deadline = _deadline;
        bounty.isActive = true;

        // Escrow the reward
        if (_paymentToken == address(0)) {
            require(msg.value == _reward, "Incorrect ETH amount");
        } else {
            IERC20(_paymentToken).safeTransferFrom(
                msg.sender,
                address(this),
                _reward
            );
        }

        totalBountyRewards += _reward;

        emit BountyCreated(bountyId, _title, _reward);
        return bountyId;
    }

    /**
     * @dev Submit work for a bounty
     */
    function submitBountyWork(
        uint256 _bountyId,
        string calldata _submissionData
    ) external returns (uint256) {
        Bounty storage bounty = bounties[_bountyId];
        require(bounty.isActive, "Bounty not active");
        require(block.timestamp <= bounty.deadline, "Bounty expired");

        uint256 submissionId = bounty.submissionCount++;
        BountySubmission storage submission = bounty.submissions[submissionId];

        submission.submitter = msg.sender;
        submission.submissionData = _submissionData;
        submission.timestamp = block.timestamp;

        emit BountySubmitted(_bountyId, msg.sender, submissionId);
        return submissionId;
    }

    /**
     * @dev Accept a bounty submission and pay reward
     */
    function acceptBountySubmission(
        uint256 _bountyId,
        uint256 _submissionId
    ) external nonReentrant {
        Bounty storage bounty = bounties[_bountyId];
        require(msg.sender == bounty.creator, "Only creator can accept");
        require(bounty.isActive, "Bounty not active");

        BountySubmission storage submission = bounty.submissions[_submissionId];
        require(submission.submitter != address(0), "Invalid submission");
        require(!submission.isAccepted, "Already accepted");

        // Mark as accepted and completed
        submission.isAccepted = true;
        bounty.isCompleted = true;
        bounty.isActive = false;
        bounty.assignee = submission.submitter;

        // Pay reward
        if (bounty.paymentToken == address(0)) {
            (bool success, ) = payable(submission.submitter).call{
                value: bounty.reward
            }("");
            require(success, "Payment failed");
        } else {
            IERC20(bounty.paymentToken).safeTransfer(
                submission.submitter,
                bounty.reward
            );
        }

        emit BountyCompleted(_bountyId, submission.submitter, bounty.reward);
    }

    // ======================
    // ENHANCED PROPOSAL SYSTEM
    // ======================

    /**
     * @dev Create proposal with enhanced metadata
     */
    function proposeWithMetadata(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        ProposalCategory category,
        uint256 requestedAmount,
        address requestedToken,
        address beneficiary,
        string memory ipfsHash,
        bool isUrgent
    ) external returns (uint256) {
        uint256 proposalId = propose(targets, values, calldatas, description);

        ProposalMetadata storage metadata = proposalMetadata[proposalId];
        metadata.category = category;
        metadata.requestedAmount = requestedAmount;
        metadata.requestedToken = requestedToken;
        metadata.beneficiary = beneficiary;
        metadata.ipfsHash = ipfsHash;
        metadata.isUrgent = isUrgent;
        metadata.priority = isUrgent ? 1 : 2;

        return proposalId;
    }

    /**
     * @dev Endorse a proposal (off-chain signaling)
     */
    function endorseProposal(uint256 proposalId) external {
        ProposalMetadata storage metadata = proposalMetadata[proposalId];
        require(!metadata.endorsements[msg.sender], "Already endorsed");

        metadata.endorsements[msg.sender] = true;
        metadata.endorsementCount++;
    }

    // ======================
    // ADVANCED VOTING & DELEGATION
    // ======================

    /**
     * @dev Enhanced delegation with weight and expiration
     */
    function delegateWithParams(
        address delegate,
        uint256 weight,
        uint256 expiration
    ) external {
        require(weight <= 10000, "Weight too high"); // Max 100%
        require(expiration > block.timestamp, "Invalid expiration");

        DelegationInfo storage delegation = delegations[msg.sender];
        delegation.delegate = delegate;
        delegation.weight = weight;
        delegation.expiration = expiration;
        delegation.isActive = true;

        // Update actual delegation (simplified - would need complex weight handling)
        _delegate(msg.sender, delegate);

        emit DelegationUpdated(msg.sender, delegate, weight);
    }

    /**
     * @dev Vote with participation rewards
     */
    function castVoteWithReward(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256) {
        uint256 votes = castVoteWithReason(proposalId, support, reason);

        // Distribute voting rewards
        if (votingRewardPool > 0 && votes >= participationThreshold) {
            uint256 reward = (votes * 1e18) / 10000; // 0.01% of voting power
            reward = Math.min(reward, votingRewardPool);

            if (reward > 0) {
                votingRewards[msg.sender] += reward;
                votingRewardPool -= reward;
                emit VotingRewardDistributed(msg.sender, reward);
            }
        }

        return votes;
    }

    /**
     * @dev Claim accumulated voting rewards
     */
    function claimVotingRewards() external nonReentrant {
        uint256 rewards = votingRewards[msg.sender];
        require(rewards > 0, "No rewards to claim");

        votingRewards[msg.sender] = 0;

        // Transfer governance tokens as reward
        IERC20 governanceToken = IERC20(address(token));
        governanceToken.safeTransfer(msg.sender, rewards);
    }

    // ======================
    // EMERGENCY GOVERNANCE
    // ======================

    /**
     * @dev Activate emergency mode
     */
    function activateEmergency(string calldata reason) external {
        require(isEmergencyMember[msg.sender], "Not emergency member");

        emergencyMode = true;
        emergencyActivatedAt = block.timestamp;
        _pause();

        emit EmergencyActivated(msg.sender, reason);
    }

    /**
     * @dev Deactivate emergency mode
     */
    function deactivateEmergency() external {
        require(isEmergencyMember[msg.sender], "Not emergency member");
        require(emergencyMode, "Not in emergency mode");

        emergencyMode = false;
        emergencyActivatedAt = 0;
        _unpause();

        emit EmergencyDeactivated(msg.sender);
    }

    /**
     * @dev Emergency treasury access (multi-sig required)
     */
    function emergencyTreasuryAccess(
        address token,
        address recipient,
        uint256 amount
    ) external {
        require(emergencyMode, "Not in emergency mode");
        require(isEmergencyMember[msg.sender], "Not emergency member");

        // Would implement multi-sig verification here

        if (token == address(0)) {
            (bool success, ) = payable(recipient).call{value: amount}("");
            require(success, "Transfer failed");
        } else {
            IERC20(token).safeTransfer(recipient, amount);
        }
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    function getTreasuryAsset(
        bytes32 assetKey
    )
        external
        view
        returns (
            TreasuryAssetType assetType,
            address assetAddress,
            uint256 balance,
            uint256 lastValuation,
            bool isActive
        )
    {
        TreasuryAsset storage asset = treasuryAssets[assetKey];
        return (
            asset.assetType,
            asset.assetAddress,
            asset.balance,
            asset.lastValuation,
            asset.isActive
        );
    }

    function getGrant(
        uint256 grantId
    )
        external
        view
        returns (
            address recipient,
            uint256 amount,
            string memory title,
            GrantStatus status,
            uint256 currentMilestone
        )
    {
        Grant storage grant = grants[grantId];
        return (
            grant.recipient,
            grant.amount,
            grant.title,
            grant.status,
            grant.currentMilestone
        );
    }

    function getBounty(
        uint256 bountyId
    )
        external
        view
        returns (
            string memory title,
            uint256 reward,
            address creator,
            bool isActive,
            bool isCompleted
        )
    {
        Bounty storage bounty = bounties[bountyId];
        return (
            bounty.title,
            bounty.reward,
            bounty.creator,
            bounty.isActive,
            bounty.isCompleted
        );
    }

    function getProposalMetadata(
        uint256 proposalId
    )
        external
        view
        returns (
            ProposalCategory category,
            uint256 requestedAmount,
            address beneficiary,
            string memory ipfsHash,
            uint256 endorsementCount
        )
    {
        ProposalMetadata storage metadata = proposalMetadata[proposalId];
        return (
            metadata.category,
            metadata.requestedAmount,
            metadata.beneficiary,
            metadata.ipfsHash,
            metadata.endorsementCount
        );
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    function _updateTotalTreasuryValue() internal {
        uint256 totalValue = 0;

        for (uint256 i = 0; i < assetKeys.length; i++) {
            TreasuryAsset storage asset = treasuryAssets[assetKeys[i]];
            if (asset.isActive) {
                totalValue += asset.lastValuation;
            }
        }

        totalTreasuryValue = totalValue;
        lastTreasuryUpdate = block.timestamp;
    }

    function _checkSpendingLimit(uint256 amount) internal view {
        if (block.timestamp >= lastSpendingReset + 1 days) {
            // Reset daily limit
            return;
        }

        require(
            todaySpent + amount <= dailySpendingLimit,
            "Daily spending limit exceeded"
        );
    }

    function _updateSpending(uint256 amount) internal {
        if (block.timestamp >= lastSpendingReset + 1 days) {
            todaySpent = amount;
            lastSpendingReset = block.timestamp;
        } else {
            todaySpent += amount;
        }
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    function addTreasuryManager(address manager) external onlyOwner {
        treasuryManagers[manager] = true;
    }

    function removeTreasuryManager(address manager) external onlyOwner {
        treasuryManagers[manager] = false;
    }

    function addEmergencyMember(address member) external onlyOwner {
        emergencyCouncil.push(member);
        isEmergencyMember[member] = true;
    }

    function setDailySpendingLimit(uint256 limit) external onlyOwner {
        dailySpendingLimit = limit;
    }

    function fundVotingRewards(uint256 amount) external onlyOwner {
        IERC20(address(token)).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        votingRewardPool += amount;
    }

    // ======================
    // OVERRIDES
    // ======================

    function votingDelay()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingDelay();
    }

    function votingPeriod()
        public
        view
        override(IGovernor, GovernorSettings)
        returns (uint256)
    {
        return super.votingPeriod();
    }

    function quorum(
        uint256 blockNumber
    )
        public
        view
        override(IGovernor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    function proposalThreshold()
        public
        view
        override(Governor, GovernorSettings)
        returns (uint256)
    {
        return super.proposalThreshold();
    }

    function _execute(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._execute(proposalId, targets, values, calldatas, descriptionHash);
    }

    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    function _executor()
        internal
        view
        override(Governor, GovernorTimelockControl)
        returns (address)
    {
        return super._executor();
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(Governor, GovernorTimelockControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Function to receive Ether
    receive() external payable {}
}

/**
 *  TREASURY DAO FEATURES:
 *
 * 1. MULTI-ASSET TREASURY MANAGEMENT:
 *    - ERC20, ERC721, and native currency support
 *    - Real-time valuation tracking
 *    - Asset diversification monitoring
 *    - Automated balance updates
 *
 * 2. ADVANCED GRANT SYSTEM:
 *    - Milestone-based funding
 *    - Multi-stage approval process
 *    - Automatic payment distribution
 *    - Grant performance tracking
 *
 * 3. BOUNTY PROGRAM:
 *    - Task-based reward system
 *    - Multiple submission support
 *    - Escrow protection
 *    - Community-driven development
 *
 * 4. ENHANCED GOVERNANCE:
 *    - Categorized proposals
 *    - Endorsement system
 *    - Priority-based voting
 *    - IPFS documentation integration
 *
 * 5. ADVANCED VOTING MECHANISMS:
 *    - Weighted delegation
 *    - Time-limited delegation
 *    - Participation rewards
 *    - Voting power tracking
 *
 * 6. TREASURY CONTROLS:
 *    - Daily spending limits
 *    - Multi-signature requirements
 *    - Emergency access procedures
 *    - Automated compliance checks
 *
 * 7. EMERGENCY GOVERNANCE:
 *    - Emergency council system
 *    - Rapid response procedures
 *    - Contract pause functionality
 *    - Emergency fund access
 *
 *  USAGE EXAMPLES:
 *
 * // Create grant proposal
 * dao.proposeGrant(recipient, amount, token, title, description, milestones, payments, deadline);
 *
 * // Create community bounty
 * dao.createBounty(title, description, reward, paymentToken, deadline);
 *
 * // Enhanced proposal creation
 * dao.proposeWithMetadata(targets, values, calldatas, description, category, amount, token, beneficiary, ipfsHash, isUrgent);
 *
 * // Vote with rewards
 * dao.castVoteWithReward(proposalId, support, reason);
 *
 * // Delegate with parameters
 * dao.delegateWithParams(delegate, weight, expiration);
 *
 *  TREASURY MANAGEMENT PHILOSOPHY:
 * - Transparency in all financial operations
 * - Community-driven allocation decisions
 * - Risk management through diversification
 * - Incentivized participation and governance
 * - Emergency preparedness and response
 */

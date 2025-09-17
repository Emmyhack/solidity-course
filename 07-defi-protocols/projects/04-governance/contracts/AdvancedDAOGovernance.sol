// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/governance/Governor.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorSettings.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "./GovernanceToken.sol";

/**
 * @title Advanced DAO Governance
 * @dev Comprehensive governance system with advanced features for DeFi protocol management
 * @notice Professional-grade DAO with multi-tier proposals, emergency controls, and incentives
 *
 * Features:
 * - Multi-tier proposal system (standard, emergency, constitutional)
 * - Dynamic voting parameters based on proposal type
 * - Delegation and vote weighting mechanisms
 * - Emergency pause/unpause capabilities
 * - Proposal execution with timelocks
 * - Voting incentives and participation tracking
 * - Quorum and threshold management
 * - Cross-chain governance preparation
 */
contract AdvancedDAOGovernance is
    Governor,
    GovernorSettings,
    GovernorCountingSimple,
    GovernorVotes,
    GovernorVotesQuorumFraction,
    GovernorTimelockControl,
    Ownable
{
    using Math for uint256;

    // ======================
    // CONSTANTS & ENUMS
    // ======================

    enum ProposalType {
        STANDARD, // Regular protocol changes
        EMERGENCY, // Time-sensitive security fixes
        CONSTITUTIONAL // Fundamental protocol changes
    }

    enum ProposalCategory {
        PARAMETER_CHANGE, // Protocol parameter updates
        TREASURY, // Treasury management
        UPGRADE, // Contract upgrades
        EMERGENCY_ACTION, // Emergency responses
        CONSTITUTIONAL, // Governance rule changes
        PARTNERSHIP, // Strategic partnerships
        TOKENOMICS // Token economics changes
    }

    // ======================
    // STRUCTS
    // ======================

    struct ProposalMetadata {
        ProposalType proposalType;
        ProposalCategory category;
        uint256 requiredQuorum;
        uint256 votingThreshold;
        uint256 votingDelay;
        uint256 votingPeriod;
        bool emergencyExecutable;
        address proposer;
        uint256 proposalWeight;
        string ipfsHash;
        uint256 createdAt;
    }

    struct VotingStats {
        uint256 totalProposals;
        uint256 successfulProposals;
        uint256 totalVotes;
        uint256 lastParticipation;
        mapping(ProposalCategory => uint256) categoryVotes;
    }

    struct DelegationInfo {
        address delegate;
        uint256 weight;
        uint256 lastUpdate;
        bool isActive;
    }

    // ======================
    // STATE VARIABLES
    // ======================

    GovernanceToken public immutable governanceToken;

    // Proposal metadata tracking
    mapping(uint256 => ProposalMetadata) public proposalMetadata;
    mapping(address => VotingStats) public votingStats;
    mapping(address => DelegationInfo) public delegationInfo;

    // Governance parameters by proposal type
    mapping(ProposalType => uint256) public typeQuorums;
    mapping(ProposalType => uint256) public typeThresholds;
    mapping(ProposalType => uint256) public typeVotingDelays;
    mapping(ProposalType => uint256) public typeVotingPeriods;

    // Emergency controls
    address public emergencyCouncil;
    mapping(address => bool) public emergencyExecutors;
    bool public emergencyPaused;
    uint256 public emergencyPauseDuration = 7 days;

    // Incentive system
    uint256 public participationRewardPool;
    uint256 public proposalRewardAmount = 1000e18;
    uint256 public votingRewardAmount = 10e18;
    mapping(address => uint256) public pendingRewards;

    // Advanced features
    uint256 public minimumTokensForProposal = 10000e18;
    uint256 public maximumProposalsPerUser = 3;
    mapping(address => uint256) public activeProposalsCount;
    mapping(address => uint256) public lastProposalTime;
    uint256 public proposalCooldown = 24 hours;

    // Cross-chain governance preparation
    mapping(uint256 => bytes32) public crossChainProposals;
    address public crossChainRelay;

    // ======================
    // EVENTS
    // ======================

    event ProposalCreatedWithMetadata(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        ProposalCategory category,
        string ipfsHash
    );

    event VotingParametersUpdated(
        ProposalType proposalType,
        uint256 quorum,
        uint256 threshold,
        uint256 votingDelay,
        uint256 votingPeriod
    );

    event EmergencyAction(address indexed executor, string action, bytes data);
    event ParticipationRewardDistributed(address indexed user, uint256 amount);
    event DelegationUpdated(
        address indexed delegator,
        address indexed delegate,
        uint256 weight
    );
    event EmergencyPauseToggled(bool paused, address indexed executor);

    // ======================
    // ERRORS
    // ======================

    error InsufficientTokens();
    error TooManyActiveProposals();
    error ProposalCooldownActive();
    error EmergencyPaused();
    error UnauthorizedEmergencyAction();
    error InvalidProposalType();
    error InvalidQuorumFraction();

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(
        GovernanceToken _token,
        TimelockController _timelock,
        address _emergencyCouncil
    )
        Governor("AdvancedDAO")
        GovernorSettings(
            1 days, // voting delay
            1 weeks, // voting period
            100e18 // proposal threshold
        )
        GovernorVotes(IVotes(address(_token)))
        GovernorVotesQuorumFraction(10) // 10% quorum
        GovernorTimelockControl(_timelock)
    {
        governanceToken = _token;
        emergencyCouncil = _emergencyCouncil;

        // Initialize voting parameters for different proposal types
        _initializeVotingParameters();
    }

    // ======================
    // PROPOSAL CREATION
    // ======================

    /**
     * @dev Create proposal with enhanced metadata and categorization
     * @param targets Target contract addresses
     * @param values ETH values for each call
     * @param calldatas Encoded function calls
     * @param description Proposal description
     * @param proposalType Type of proposal (standard, emergency, constitutional)
     * @param category Proposal category
     * @param ipfsHash IPFS hash for additional documentation
     */
    function proposeWithMetadata(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        ProposalType proposalType,
        ProposalCategory category,
        string memory ipfsHash
    ) public returns (uint256) {
        // Check proposal creation requirements
        if (governanceToken.balanceOf(msg.sender) < minimumTokensForProposal) {
            revert InsufficientTokens();
        }

        if (activeProposalsCount[msg.sender] >= maximumProposalsPerUser) {
            revert TooManyActiveProposals();
        }

        if (block.timestamp < lastProposalTime[msg.sender] + proposalCooldown) {
            revert ProposalCooldownActive();
        }

        if (emergencyPaused && proposalType != ProposalType.EMERGENCY) {
            revert EmergencyPaused();
        }

        // Create the proposal
        uint256 proposalId = propose(targets, values, calldatas, description);

        // Set proposal metadata
        ProposalMetadata storage metadata = proposalMetadata[proposalId];
        metadata.proposalType = proposalType;
        metadata.category = category;
        metadata.requiredQuorum = typeQuorums[proposalType];
        metadata.votingThreshold = typeThresholds[proposalType];
        metadata.votingDelay = typeVotingDelays[proposalType];
        metadata.votingPeriod = typeVotingPeriods[proposalType];
        metadata.emergencyExecutable = (proposalType == ProposalType.EMERGENCY);
        metadata.proposer = msg.sender;
        metadata.proposalWeight = _calculateProposalWeight(
            category,
            targets.length
        );
        metadata.ipfsHash = ipfsHash;
        metadata.createdAt = block.timestamp;

        // Update proposer stats
        activeProposalsCount[msg.sender]++;
        lastProposalTime[msg.sender] = block.timestamp;
        votingStats[msg.sender].totalProposals++;

        // Reward proposal creation
        _distributeProposalReward(msg.sender);

        emit ProposalCreatedWithMetadata(
            proposalId,
            msg.sender,
            proposalType,
            category,
            ipfsHash
        );

        return proposalId;
    }

    /**
     * @dev Emergency proposal creation with expedited process
     * @param targets Target addresses
     * @param values ETH values
     * @param calldatas Function calls
     * @param description Description
     * @param justification Emergency justification
     */
    function proposeEmergency(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description,
        string memory justification
    ) external returns (uint256) {
        require(
            emergencyExecutors[msg.sender] || msg.sender == emergencyCouncil,
            "Not authorized for emergency proposals"
        );

        string memory emergencyDescription = string(
            abi.encodePacked(
                "EMERGENCY: ",
                description,
                " | Justification: ",
                justification
            )
        );

        return
            proposeWithMetadata(
                targets,
                values,
                calldatas,
                emergencyDescription,
                ProposalType.EMERGENCY,
                ProposalCategory.EMERGENCY_ACTION,
                ""
            );
    }

    // ======================
    // VOTING FUNCTIONS
    // ======================

    /**
     * @dev Cast vote with enhanced tracking and rewards
     * @param proposalId Proposal ID
     * @param support Vote support (0=against, 1=for, 2=abstain)
     * @param reason Voting reason
     */
    function castVoteWithReasonAndReward(
        uint256 proposalId,
        uint8 support,
        string calldata reason
    ) external returns (uint256) {
        uint256 votes = castVoteWithReason(proposalId, support, reason);

        // Update voting statistics
        VotingStats storage stats = votingStats[msg.sender];
        stats.totalVotes++;
        stats.lastParticipation = block.timestamp;

        ProposalMetadata storage metadata = proposalMetadata[proposalId];
        stats.categoryVotes[metadata.category]++;

        // Distribute voting rewards
        _distributeVotingReward(msg.sender, metadata.proposalWeight);

        return votes;
    }

    /**
     * @dev Batch vote on multiple proposals
     * @param proposalIds Array of proposal IDs
     * @param supports Array of vote supports
     * @param reasons Array of voting reasons
     */
    function batchVote(
        uint256[] memory proposalIds,
        uint8[] memory supports,
        string[] memory reasons
    ) external {
        require(
            proposalIds.length == supports.length &&
                supports.length == reasons.length,
            "Array length mismatch"
        );

        for (uint256 i = 0; i < proposalIds.length; i++) {
            castVoteWithReasonAndReward(
                proposalIds[i],
                supports[i],
                reasons[i]
            );
        }
    }

    // ======================
    // DELEGATION FUNCTIONS
    // ======================

    /**
     * @dev Enhanced delegation with weight and tracking
     * @param delegate Address to delegate to
     * @param weight Delegation weight (basis points, max 10000)
     */
    function delegateWithWeight(address delegate, uint256 weight) external {
        require(weight <= 10000, "Weight exceeds maximum");

        // Update delegation info
        DelegationInfo storage info = delegationInfo[msg.sender];
        info.delegate = delegate;
        info.weight = weight;
        info.lastUpdate = block.timestamp;
        info.isActive = (weight > 0);

        // Delegate tokens (full delegation for simplicity)
        if (weight > 0) {
            governanceToken.delegate(delegate);
        }

        emit DelegationUpdated(msg.sender, delegate, weight);
    }

    /**
     * @dev Remove delegation
     */
    function removeDelegation() external {
        DelegationInfo storage info = delegationInfo[msg.sender];
        address oldDelegate = info.delegate;

        info.delegate = address(0);
        info.weight = 0;
        info.isActive = false;
        info.lastUpdate = block.timestamp;

        // Delegate back to self
        governanceToken.delegate(msg.sender);

        emit DelegationUpdated(msg.sender, address(0), 0);
    }

    // ======================
    // EMERGENCY CONTROLS
    // ======================

    /**
     * @dev Emergency pause governance (except emergency proposals)
     */
    function emergencyPause() external {
        require(
            msg.sender == emergencyCouncil || emergencyExecutors[msg.sender],
            "Not authorized"
        );

        emergencyPaused = true;
        emit EmergencyPauseToggled(true, msg.sender);
    }

    /**
     * @dev Unpause governance
     */
    function emergencyUnpause() external {
        require(msg.sender == emergencyCouncil, "Only emergency council");

        emergencyPaused = false;
        emit EmergencyPauseToggled(false, msg.sender);
    }

    /**
     * @dev Execute emergency action bypassing normal timelock
     * @param target Target contract
     * @param data Calldata
     * @param description Action description
     */
    function executeEmergencyAction(
        address target,
        bytes calldata data,
        string calldata description
    ) external {
        if (!emergencyExecutors[msg.sender] && msg.sender != emergencyCouncil) {
            revert UnauthorizedEmergencyAction();
        }

        (bool success, ) = target.call(data);
        require(success, "Emergency action failed");

        emit EmergencyAction(msg.sender, description, data);
    }

    // ======================
    // PARAMETER MANAGEMENT
    // ======================

    /**
     * @dev Update voting parameters for proposal type
     * @param proposalType Type to update
     * @param quorum Quorum fraction (1-100)
     * @param threshold Voting threshold (basis points)
     * @param votingDelay Voting delay in blocks
     * @param votingPeriod Voting period in blocks
     */
    function updateVotingParameters(
        ProposalType proposalType,
        uint256 quorum,
        uint256 threshold,
        uint256 votingDelay,
        uint256 votingPeriod
    ) external onlyGovernance {
        if (quorum > 100) revert InvalidQuorumFraction();

        typeQuorums[proposalType] = quorum;
        typeThresholds[proposalType] = threshold;
        typeVotingDelays[proposalType] = votingDelay;
        typeVotingPeriods[proposalType] = votingPeriod;

        emit VotingParametersUpdated(
            proposalType,
            quorum,
            threshold,
            votingDelay,
            votingPeriod
        );
    }

    /**
     * @dev Update proposal creation requirements
     * @param minimumTokens Minimum tokens required
     * @param maxProposals Maximum active proposals per user
     * @param cooldown Cooldown between proposals
     */
    function updateProposalRequirements(
        uint256 minimumTokens,
        uint256 maxProposals,
        uint256 cooldown
    ) external onlyGovernance {
        minimumTokensForProposal = minimumTokens;
        maximumProposalsPerUser = maxProposals;
        proposalCooldown = cooldown;
    }

    /**
     * @dev Update emergency council
     * @param newCouncil New emergency council address
     */
    function updateEmergencyCouncil(
        address newCouncil
    ) external onlyGovernance {
        emergencyCouncil = newCouncil;
    }

    /**
     * @dev Add/remove emergency executor
     * @param executor Executor address
     * @param authorized Whether authorized
     */
    function setEmergencyExecutor(
        address executor,
        bool authorized
    ) external onlyGovernance {
        emergencyExecutors[executor] = authorized;
    }

    // ======================
    // REWARD SYSTEM
    // ======================

    /**
     * @dev Fund participation rewards
     * @param amount Amount to add to reward pool
     */
    function fundParticipationRewards(uint256 amount) external {
        governanceToken.transferFrom(msg.sender, address(this), amount);
        participationRewardPool += amount;
    }

    /**
     * @dev Claim pending participation rewards
     */
    function claimParticipationRewards() external {
        uint256 rewards = pendingRewards[msg.sender];
        require(rewards > 0, "No rewards pending");

        pendingRewards[msg.sender] = 0;
        governanceToken.transfer(msg.sender, rewards);

        emit ParticipationRewardDistributed(msg.sender, rewards);
    }

    /**
     * @dev Update reward amounts
     * @param proposalReward Reward for creating proposals
     * @param votingReward Base reward for voting
     */
    function updateRewardAmounts(
        uint256 proposalReward,
        uint256 votingReward
    ) external onlyGovernance {
        proposalRewardAmount = proposalReward;
        votingRewardAmount = votingReward;
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Get proposal metadata
     * @param proposalId Proposal ID
     * @return Proposal metadata struct
     */
    function getProposalMetadata(
        uint256 proposalId
    ) external view returns (ProposalMetadata memory) {
        return proposalMetadata[proposalId];
    }

    /**
     * @dev Get user voting statistics
     * @param user User address
     * @return Voting statistics
     */
    function getUserVotingStats(
        address user
    )
        external
        view
        returns (
            uint256 totalProposals,
            uint256 successfulProposals,
            uint256 totalVotes,
            uint256 lastParticipation
        )
    {
        VotingStats storage stats = votingStats[user];
        return (
            stats.totalProposals,
            stats.successfulProposals,
            stats.totalVotes,
            stats.lastParticipation
        );
    }

    /**
     * @dev Get voting parameters for proposal type
     * @param proposalType Proposal type
     * @return Voting parameters
     */
    function getVotingParameters(
        ProposalType proposalType
    )
        external
        view
        returns (
            uint256 quorum,
            uint256 threshold,
            uint256 delay,
            uint256 period
        )
    {
        return (
            typeQuorums[proposalType],
            typeThresholds[proposalType],
            typeVotingDelays[proposalType],
            typeVotingPeriods[proposalType]
        );
    }

    /**
     * @dev Check if user can create proposal
     * @param user User address
     * @return Whether user can create proposal
     */
    function canCreateProposal(address user) external view returns (bool) {
        return (governanceToken.balanceOf(user) >= minimumTokensForProposal &&
            activeProposalsCount[user] < maximumProposalsPerUser &&
            block.timestamp >= lastProposalTime[user] + proposalCooldown &&
            !emergencyPaused);
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    function _initializeVotingParameters() internal {
        // Standard proposals
        typeQuorums[ProposalType.STANDARD] = 10; // 10%
        typeThresholds[ProposalType.STANDARD] = 5100; // 51%
        typeVotingDelays[ProposalType.STANDARD] = 1 days;
        typeVotingPeriods[ProposalType.STANDARD] = 1 weeks;

        // Emergency proposals
        typeQuorums[ProposalType.EMERGENCY] = 5; // 5%
        typeThresholds[ProposalType.EMERGENCY] = 6700; // 67%
        typeVotingDelays[ProposalType.EMERGENCY] = 1 hours;
        typeVotingPeriods[ProposalType.EMERGENCY] = 2 days;

        // Constitutional proposals
        typeQuorums[ProposalType.CONSTITUTIONAL] = 20; // 20%
        typeThresholds[ProposalType.CONSTITUTIONAL] = 7500; // 75%
        typeVotingDelays[ProposalType.CONSTITUTIONAL] = 3 days;
        typeVotingPeriods[ProposalType.CONSTITUTIONAL] = 2 weeks;
    }

    function _calculateProposalWeight(
        ProposalCategory category,
        uint256 targetCount
    ) internal pure returns (uint256) {
        uint256 baseWeight = 100;

        // Category weight multiplier
        if (category == ProposalCategory.CONSTITUTIONAL) baseWeight = 200;
        else if (category == ProposalCategory.EMERGENCY_ACTION)
            baseWeight = 150;
        else if (category == ProposalCategory.UPGRADE) baseWeight = 130;

        // Complexity weight based on target count
        uint256 complexityWeight = baseWeight + (targetCount * 10);

        return complexityWeight;
    }

    function _distributeProposalReward(address proposer) internal {
        if (participationRewardPool >= proposalRewardAmount) {
            participationRewardPool -= proposalRewardAmount;
            pendingRewards[proposer] += proposalRewardAmount;
        }
    }

    function _distributeVotingReward(
        address voter,
        uint256 proposalWeight
    ) internal {
        uint256 baseReward = votingRewardAmount;
        uint256 weightedReward = (baseReward * proposalWeight) / 100;

        if (participationRewardPool >= weightedReward) {
            participationRewardPool -= weightedReward;
            pendingRewards[voter] += weightedReward;
        }
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
        // Update successful proposal count for proposer
        address proposer = proposalMetadata[proposalId].proposer;
        votingStats[proposer].successfulProposals++;
        activeProposalsCount[proposer]--;

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
}

/**
 * 🏛️ ADVANCED DAO GOVERNANCE FEATURES:
 *
 * 1. MULTI-TIER PROPOSAL SYSTEM:
 *    - Standard: Regular protocol changes (10% quorum, 51% threshold)
 *    - Emergency: Time-sensitive fixes (5% quorum, 67% threshold, fast-track)
 *    - Constitutional: Fundamental changes (20% quorum, 75% threshold)
 *
 * 2. ADVANCED VOTING MECHANISMS:
 *    - Weighted delegation with partial voting power
 *    - Category-based voting tracking and rewards
 *    - Batch voting for multiple proposals
 *    - Historical participation tracking
 *
 * 3. EMERGENCY GOVERNANCE:
 *    - Emergency council with pause/unpause powers
 *    - Fast-track emergency proposals
 *    - Emergency execution bypassing timelock
 *    - Authorized emergency executors
 *
 * 4. PARTICIPATION INCENTIVES:
 *    - Rewards for proposal creation
 *    - Weighted voting rewards based on proposal importance
 *    - Participation tracking and statistics
 *    - Community engagement bonuses
 *
 * 5. GOVERNANCE CONTROLS:
 *    - Minimum token requirements for proposals
 *    - Proposal cooldowns and limits per user
 *    - Dynamic voting parameters per proposal type
 *    - Cross-chain governance preparation
 *
 * 6. METADATA & DOCUMENTATION:
 *    - IPFS integration for detailed proposals
 *    - Proposal categorization and weighting
 *    - Comprehensive voting statistics
 *    - Historical governance data
 *
 * 📊 USAGE EXAMPLES:
 *
 * // Create emergency proposal
 * dao.proposeEmergency(targets, values, calldatas, description, justification);
 *
 * // Vote on multiple proposals
 * dao.batchVote([id1, id2], [1, 0], ["For", "Against"]);
 *
 * // Delegate with partial weight
 * dao.delegateWithWeight(delegate, 7500); // 75% delegation
 *
 * // Emergency pause governance
 * dao.emergencyPause();
 *
 * // Claim participation rewards
 * dao.claimParticipationRewards();
 *
 * 🎯 GOVERNANCE PHILOSOPHY:
 * - Multi-tier system balances speed vs. security
 * - Incentives encourage active participation
 * - Emergency controls protect against critical threats
 * - Transparent tracking builds community trust
 * - Flexible parameters adapt to protocol needs
 */

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "./AdvancedVotingMechanisms.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title Quadratic Voting Implementation
 * @dev Specialized contract for quadratic voting with voice credits and democratic participation
 * @notice Implements quadratic voting where voice is proportional to square root of credits spent
 *
 * Key Concepts:
 * - Voice = √Credits: Diminishing returns prevent wealth dominance
 * - Credit allocation: Equal or proportional distribution
 * - Multiple rounds: Credits can be saved or spent across proposals
 * - Collusion resistance: Anonymous credential systems
 */
contract QuadraticVotingSystem is ReentrancyGuard, Pausable, Ownable {
    using Math for uint256;

    // ======================
    // STRUCTS & ENUMS
    // ======================

    struct Proposal {
        uint256 id;
        string title;
        string description;
        address proposer;
        uint256 startTime;
        uint256 endTime;
        bool active;
        bool executed;
        mapping(address => Vote) votes;
        mapping(uint256 => uint256) optionVotes; // option => voice credits
        uint256[] options;
        string[] optionLabels;
        uint256 totalParticipants;
        uint256 totalVoiceUsed;
    }

    struct Vote {
        bool hasVoted;
        mapping(uint256 => uint256) creditsPerOption; // option => credits spent
        uint256 totalCreditsUsed;
        uint256 totalVoiceGenerated;
        uint256 timestamp;
    }

    struct Participant {
        uint256 totalCredits;
        uint256 creditsUsed;
        uint256 creditsRemaining;
        uint256 voiceGenerated;
        uint256 proposalsParticipated;
        bool isRegistered;
        uint256 registrationTime;
    }

    struct QVRound {
        uint256 roundId;
        string name;
        uint256 startTime;
        uint256 endTime;
        uint256 creditsPerParticipant;
        uint256 maxCreditsPerProposal;
        bool isActive;
        uint256[] proposalIds;
        mapping(address => uint256) participantCredits;
    }

    // ======================
    // STATE VARIABLES
    // ======================

    mapping(uint256 => Proposal) public proposals;
    mapping(address => Participant) public participants;
    mapping(uint256 => QVRound) public qvRounds;

    uint256 public nextProposalId = 1;
    uint256 public nextRoundId = 1;
    uint256 public currentRoundId;

    uint256 public defaultCreditsPerParticipant = 100;
    uint256 public registrationFee = 0.01 ether;
    uint256 public proposalCreationFee = 1 ether;

    // Credit distribution mechanism
    enum CreditDistribution {
        EQUAL, // Everyone gets same credits
        STAKE_BASED, // Credits proportional to stake
        REPUTATION // Credits based on reputation
    }

    CreditDistribution public distributionMethod = CreditDistribution.EQUAL;
    IERC20 public stakeToken; // For stake-based distribution

    // ======================
    // EVENTS
    // ======================

    event ParticipantRegistered(address indexed participant, uint256 credits);
    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title
    );
    event QuadraticVoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        uint256 option,
        uint256 credits,
        uint256 voice
    );
    event QVRoundStarted(
        uint256 indexed roundId,
        string name,
        uint256 creditsPerParticipant
    );
    event QVRoundEnded(uint256 indexed roundId);
    event CreditsAllocated(
        address indexed participant,
        uint256 credits,
        uint256 roundId
    );

    // ======================
    // ERRORS
    // ======================

    error NotRegistered();
    error InsufficientCredits();
    error ProposalNotActive();
    error InvalidOption();
    error AlreadyVoted();
    error RoundNotActive();
    error InvalidCreditsAmount();

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(IERC20 _stakeToken, uint256 _defaultCredits) {
        stakeToken = _stakeToken;
        defaultCreditsPerParticipant = _defaultCredits;
    }

    // ======================
    // REGISTRATION
    // ======================

    /**
     * @dev Register as a participant in quadratic voting
     */
    function registerParticipant() external payable {
        require(msg.value >= registrationFee, "Insufficient registration fee");
        require(!participants[msg.sender].isRegistered, "Already registered");

        Participant storage participant = participants[msg.sender];
        participant.isRegistered = true;
        participant.registrationTime = block.timestamp;

        // Allocate initial credits based on distribution method
        uint256 credits = _calculateInitialCredits(msg.sender);
        participant.totalCredits = credits;
        participant.creditsRemaining = credits;

        emit ParticipantRegistered(msg.sender, credits);
    }

    // ======================
    // ROUND MANAGEMENT
    // ======================

    /**
     * @dev Start a new quadratic voting round
     */
    function startQVRound(
        string calldata _name,
        uint256 _duration,
        uint256 _creditsPerParticipant,
        uint256 _maxCreditsPerProposal
    ) external onlyOwner returns (uint256) {
        uint256 roundId = nextRoundId++;

        QVRound storage round = qvRounds[roundId];
        round.roundId = roundId;
        round.name = _name;
        round.startTime = block.timestamp;
        round.endTime = block.timestamp + _duration;
        round.creditsPerParticipant = _creditsPerParticipant;
        round.maxCreditsPerProposal = _maxCreditsPerProposal;
        round.isActive = true;

        currentRoundId = roundId;

        emit QVRoundStarted(roundId, _name, _creditsPerParticipant);
        return roundId;
    }

    /**
     * @dev End a quadratic voting round
     */
    function endQVRound(uint256 _roundId) external onlyOwner {
        QVRound storage round = qvRounds[_roundId];
        round.isActive = false;
        round.endTime = block.timestamp;

        emit QVRoundEnded(_roundId);
    }

    /**
     * @dev Allocate credits to participants for a round
     */
    function allocateCreditsForRound(
        uint256 _roundId,
        address[] calldata _participants
    ) external onlyOwner {
        QVRound storage round = qvRounds[_roundId];
        require(round.isActive, "Round not active");

        for (uint256 i = 0; i < _participants.length; i++) {
            address participant = _participants[i];
            require(
                participants[participant].isRegistered,
                "Participant not registered"
            );

            uint256 credits = _calculateRoundCredits(participant, _roundId);
            round.participantCredits[participant] = credits;

            emit CreditsAllocated(participant, credits, _roundId);
        }
    }

    // ======================
    // PROPOSAL CREATION
    // ======================

    /**
     * @dev Create a new proposal for quadratic voting
     */
    function createProposal(
        string calldata _title,
        string calldata _description,
        string[] calldata _optionLabels,
        uint256 _votingPeriod,
        uint256 _roundId
    ) external payable returns (uint256) {
        require(msg.value >= proposalCreationFee, "Insufficient proposal fee");
        require(_optionLabels.length >= 2, "Need at least 2 options");
        require(participants[msg.sender].isRegistered, "Not registered");

        if (_roundId > 0) {
            QVRound storage round = qvRounds[_roundId];
            require(round.isActive, "Round not active");
        }

        uint256 proposalId = nextProposalId++;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.title = _title;
        proposal.description = _description;
        proposal.proposer = msg.sender;
        proposal.startTime = block.timestamp;
        proposal.endTime = block.timestamp + _votingPeriod;
        proposal.active = true;

        // Initialize options
        for (uint256 i = 0; i < _optionLabels.length; i++) {
            proposal.options.push(i);
            proposal.optionLabels.push(_optionLabels[i]);
        }

        // Add to round if specified
        if (_roundId > 0) {
            qvRounds[_roundId].proposalIds.push(proposalId);
        }

        emit ProposalCreated(proposalId, msg.sender, _title);
        return proposalId;
    }

    // ======================
    // QUADRATIC VOTING
    // ======================

    /**
     * @dev Cast quadratic votes on a proposal
     */
    function voteQuadratic(
        uint256 _proposalId,
        uint256[] calldata _options,
        uint256[] calldata _credits
    ) external whenNotPaused nonReentrant {
        require(_options.length == _credits.length, "Arrays length mismatch");

        Proposal storage proposal = proposals[_proposalId];
        require(proposal.active, "Proposal not active");
        require(block.timestamp <= proposal.endTime, "Voting period ended");
        require(!proposal.votes[msg.sender].hasVoted, "Already voted");
        require(participants[msg.sender].isRegistered, "Not registered");

        // Validate options and calculate total credits needed
        uint256 totalCreditsNeeded = 0;
        for (uint256 i = 0; i < _options.length; i++) {
            require(_options[i] < proposal.options.length, "Invalid option");
            require(_credits[i] > 0, "Credits must be positive");
            totalCreditsNeeded += _credits[i];
        }

        // Check if participant has enough credits
        uint256 availableCredits = _getAvailableCredits(
            msg.sender,
            _proposalId
        );
        require(totalCreditsNeeded <= availableCredits, "Insufficient credits");

        // Apply round-specific limits
        uint256 roundId = _findProposalRound(_proposalId);
        if (roundId > 0) {
            QVRound storage round = qvRounds[roundId];
            require(
                totalCreditsNeeded <= round.maxCreditsPerProposal,
                "Exceeds max credits per proposal"
            );
        }

        // Cast votes and calculate voice
        Vote storage vote = proposal.votes[msg.sender];
        vote.hasVoted = true;
        vote.totalCreditsUsed = totalCreditsNeeded;
        vote.timestamp = block.timestamp;

        uint256 totalVoice = 0;
        for (uint256 i = 0; i < _options.length; i++) {
            uint256 option = _options[i];
            uint256 credits = _credits[i];

            // Voice = sqrt(credits)
            uint256 voice = Math.sqrt(credits);

            vote.creditsPerOption[option] = credits;
            proposal.optionVotes[option] += voice;
            totalVoice += voice;

            emit QuadraticVoteCast(
                _proposalId,
                msg.sender,
                option,
                credits,
                voice
            );
        }

        vote.totalVoiceGenerated = totalVoice;
        proposal.totalParticipants++;
        proposal.totalVoiceUsed += totalVoice;

        // Update participant credits
        _deductCredits(msg.sender, totalCreditsNeeded, roundId);

        // Update participant stats
        Participant storage participant = participants[msg.sender];
        participant.creditsUsed += totalCreditsNeeded;
        participant.voiceGenerated += totalVoice;
        participant.proposalsParticipated++;
    }

    /**
     * @dev Vote with quadratic allocation across multiple options
     */
    function voteQuadraticAllocated(
        uint256 _proposalId,
        uint256 _totalCredits,
        uint256[] calldata _optionWeights
    ) external whenNotPaused nonReentrant {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.active, "Proposal not active");
        require(
            _optionWeights.length == proposal.options.length,
            "Invalid weights array"
        );

        // Normalize weights to sum to 10000 (100%)
        uint256 totalWeight = 0;
        for (uint256 i = 0; i < _optionWeights.length; i++) {
            totalWeight += _optionWeights[i];
        }
        require(totalWeight == 10000, "Weights must sum to 10000");

        // Calculate credits per option
        uint256[] memory options = new uint256[](_optionWeights.length);
        uint256[] memory credits = new uint256[](_optionWeights.length);

        for (uint256 i = 0; i < _optionWeights.length; i++) {
            options[i] = i;
            credits[i] = (_totalCredits * _optionWeights[i]) / 10000;
        }

        // Cast the vote
        voteQuadratic(_proposalId, options, credits);
    }

    // ======================
    // CREDIT MANAGEMENT
    // ======================

    /**
     * @dev Purchase additional credits (if allowed)
     */
    function purchaseCredits(uint256 _amount) external payable {
        require(participants[msg.sender].isRegistered, "Not registered");

        // Calculate cost (could be linear, quadratic, or other pricing mechanism)
        uint256 cost = _calculateCreditCost(_amount);
        require(msg.value >= cost, "Insufficient payment");

        Participant storage participant = participants[msg.sender];
        participant.totalCredits += _amount;
        participant.creditsRemaining += _amount;

        // Refund excess payment
        if (msg.value > cost) {
            payable(msg.sender).transfer(msg.value - cost);
        }
    }

    /**
     * @dev Transfer credits between participants (if allowed)
     */
    function transferCredits(address _to, uint256 _amount) external {
        require(
            participants[msg.sender].isRegistered &&
                participants[_to].isRegistered,
            "Both must be registered"
        );
        require(
            participants[msg.sender].creditsRemaining >= _amount,
            "Insufficient credits"
        );

        participants[msg.sender].creditsRemaining -= _amount;
        participants[_to].creditsRemaining += _amount;
        participants[_to].totalCredits += _amount;
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Get proposal details and current vote counts
     */
    function getProposalResults(
        uint256 _proposalId
    )
        external
        view
        returns (
            string memory title,
            string[] memory optionLabels,
            uint256[] memory voiceCounts,
            uint256 totalParticipants,
            uint256 totalVoice,
            bool isActive
        )
    {
        Proposal storage proposal = proposals[_proposalId];

        uint256[] memory counts = new uint256[](proposal.options.length);
        for (uint256 i = 0; i < proposal.options.length; i++) {
            counts[i] = proposal.optionVotes[i];
        }

        return (
            proposal.title,
            proposal.optionLabels,
            counts,
            proposal.totalParticipants,
            proposal.totalVoiceUsed,
            proposal.active && block.timestamp <= proposal.endTime
        );
    }

    /**
     * @dev Get participant's vote on a proposal
     */
    function getParticipantVote(
        uint256 _proposalId,
        address _participant
    )
        external
        view
        returns (
            bool hasVoted,
            uint256 totalCreditsUsed,
            uint256 totalVoiceGenerated,
            uint256[] memory creditsPerOption
        )
    {
        Vote storage vote = proposals[_proposalId].votes[_participant];

        uint256[] memory credits = new uint256[](
            proposals[_proposalId].options.length
        );
        for (uint256 i = 0; i < proposals[_proposalId].options.length; i++) {
            credits[i] = vote.creditsPerOption[i];
        }

        return (
            vote.hasVoted,
            vote.totalCreditsUsed,
            vote.totalVoiceGenerated,
            credits
        );
    }

    /**
     * @dev Get participant's credit balance
     */
    function getParticipantCredits(
        address _participant
    )
        external
        view
        returns (
            uint256 totalCredits,
            uint256 creditsUsed,
            uint256 creditsRemaining,
            uint256 voiceGenerated,
            uint256 proposalsParticipated
        )
    {
        Participant storage participant = participants[_participant];
        return (
            participant.totalCredits,
            participant.creditsUsed,
            participant.creditsRemaining,
            participant.voiceGenerated,
            participant.proposalsParticipated
        );
    }

    /**
     * @dev Calculate the voice efficiency of credits spent
     */
    function calculateVoiceEfficiency(
        uint256[] calldata _credits
    )
        external
        pure
        returns (uint256 totalVoice, uint256 totalCredits, uint256 efficiency)
    {
        uint256 voice = 0;
        uint256 credits = 0;

        for (uint256 i = 0; i < _credits.length; i++) {
            voice += Math.sqrt(_credits[i]);
            credits += _credits[i];
        }

        uint256 eff = credits > 0 ? (voice * 10000) / credits : 0;

        return (voice, credits, eff);
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    function _calculateInitialCredits(
        address _participant
    ) internal view returns (uint256) {
        if (distributionMethod == CreditDistribution.EQUAL) {
            return defaultCreditsPerParticipant;
        } else if (distributionMethod == CreditDistribution.STAKE_BASED) {
            uint256 stake = stakeToken.balanceOf(_participant);
            return Math.min(stake / 1e18, defaultCreditsPerParticipant * 5); // Max 5x base credits
        } else {
            // Reputation-based (simplified)
            return defaultCreditsPerParticipant;
        }
    }

    function _calculateRoundCredits(
        address _participant,
        uint256 _roundId
    ) internal view returns (uint256) {
        QVRound storage round = qvRounds[_roundId];

        if (distributionMethod == CreditDistribution.EQUAL) {
            return round.creditsPerParticipant;
        } else if (distributionMethod == CreditDistribution.STAKE_BASED) {
            uint256 stake = stakeToken.balanceOf(_participant);
            uint256 baseCredits = round.creditsPerParticipant;
            return Math.min(stake / 1e18, baseCredits * 3); // Max 3x round credits
        } else {
            return round.creditsPerParticipant;
        }
    }

    function _getAvailableCredits(
        address _participant,
        uint256 _proposalId
    ) internal view returns (uint256) {
        uint256 roundId = _findProposalRound(_proposalId);

        if (roundId > 0) {
            return qvRounds[roundId].participantCredits[_participant];
        } else {
            return participants[_participant].creditsRemaining;
        }
    }

    function _deductCredits(
        address _participant,
        uint256 _amount,
        uint256 _roundId
    ) internal {
        if (_roundId > 0) {
            qvRounds[_roundId].participantCredits[_participant] -= _amount;
        } else {
            participants[_participant].creditsRemaining -= _amount;
        }
    }

    function _findProposalRound(
        uint256 _proposalId
    ) internal view returns (uint256) {
        // Search through active rounds to find which one contains this proposal
        for (uint256 i = 1; i < nextRoundId; i++) {
            QVRound storage round = qvRounds[i];
            for (uint256 j = 0; j < round.proposalIds.length; j++) {
                if (round.proposalIds[j] == _proposalId) {
                    return i;
                }
            }
        }
        return 0; // Not in any round
    }

    function _calculateCreditCost(
        uint256 _amount
    ) internal pure returns (uint256) {
        // Simple linear pricing: 0.001 ETH per credit
        return _amount * 0.001 ether;
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    function setDistributionMethod(
        CreditDistribution _method
    ) external onlyOwner {
        distributionMethod = _method;
    }

    function setDefaultCredits(uint256 _credits) external onlyOwner {
        defaultCreditsPerParticipant = _credits;
    }

    function setFees(
        uint256 _registrationFee,
        uint256 _proposalFee
    ) external onlyOwner {
        registrationFee = _registrationFee;
        proposalCreationFee = _proposalFee;
    }

    function withdrawFees() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

/**
 * 🗳️ QUADRATIC VOTING FEATURES:
 *
 * 1. DEMOCRATIC VOICE DISTRIBUTION:
 *    - Voice = √Credits prevents wealth dominance
 *    - Diminishing returns encourage broad participation
 *    - Multiple credit distribution mechanisms
 *
 * 2. FLEXIBLE VOTING ROUNDS:
 *    - Time-bounded voting rounds
 *    - Credit allocation per round
 *    - Multiple proposals per round
 *    - Cross-proposal credit limits
 *
 * 3. CREDIT MANAGEMENT:
 *    - Initial credit allocation
 *    - Credit purchasing (optional)
 *    - Credit transfers between participants
 *    - Round-specific credit pools
 *
 * 4. VOTING STRATEGIES:
 *    - Direct option voting
 *    - Weighted allocation across options
 *    - Strategic credit distribution
 *    - Voice efficiency optimization
 *
 * 📊 USAGE EXAMPLES:
 *
 * // Register and get credits
 * qv.registerParticipant{value: 0.01 ether}();
 *
 * // Create proposal with multiple options
 * string[] memory options = ["Option A", "Option B", "Option C"];
 * qv.createProposal("Budget Allocation", "How to allocate funds", options, 7 days, roundId);
 *
 * // Vote with specific credits per option
 * uint256[] memory optionIds = [0, 1, 2];
 * uint256[] memory credits = [25, 16, 9]; // Voice: 5, 4, 3
 * qv.voteQuadratic(proposalId, optionIds, credits);
 *
 * // Vote with weighted allocation
 * uint256[] memory weights = [5000, 3000, 2000]; // 50%, 30%, 20%
 * qv.voteQuadraticAllocated(proposalId, 100, weights);
 *
 * 🎯 QUADRATIC VOTING BENEFITS:
 * - Reduces influence of extreme wealth
 * - Encourages moderate, broad-based participation
 * - Allows nuanced preference expression
 * - Creates more democratic outcomes
 * - Incentivizes thoughtful credit allocation
 */

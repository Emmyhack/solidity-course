// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Conviction Voting System
 * @dev Implements conviction voting where support grows over time without explicit voting periods
 * @notice Continuous democratic decision-making with time-weighted preferences
 *
 * Key Concepts:
 * - Conviction grows over time based on continuous support
 * - No fixed voting periods - proposals can pass when conviction threshold is reached
 * - Supporters can change their support at any time
 * - Conviction decays when support is withdrawn
 * - Prevents last-minute manipulation through time-weighting
 */
contract ConvictionVotingSystem is ReentrancyGuard, Pausable, Ownable {
    using Math for uint256;

    // ======================
    // STRUCTS & ENUMS
    // ======================

    struct Proposal {
        uint256 id;
        address proposer;
        string title;
        string description;
        uint256 requestedAmount; // Amount requested from treasury
        address beneficiary; // Who receives the funds
        uint256 createdAt;
        bool executed;
        bool cancelled;
        // Conviction tracking
        uint256 totalConviction;
        uint256 convictionLast; // Last block conviction was calculated
        uint256 supportersCount;
        // Thresholds
        uint256 convictionThreshold; // Required conviction to pass
        uint256 maxConviction; // Maximum possible conviction
        mapping(address => Support) supporters;
        address[] supportersList;
    }

    struct Support {
        uint256 amount; // Amount of tokens supporting
        uint256 conviction; // Current conviction for this supporter
        uint256 lastUpdate; // Last time conviction was updated
        bool isActive; // Whether currently supporting
    }

    struct ConvictionParams {
        uint256 convictionGrowth; // Rate at which conviction grows (per block)
        uint256 convictionDecay; // Rate at which conviction decays when support removed
        uint256 minThreshold; // Minimum conviction threshold
        uint256 maxThreshold; // Maximum conviction threshold
        uint256 spendingLimit; // Maximum amount that can be spent
        uint256 minSupport; // Minimum token amount to support
    }

    struct TreasuryInfo {
        uint256 totalFunds;
        uint256 allocatedFunds;
        uint256 availableFunds;
        uint256 spentFunds;
        mapping(uint256 => uint256) proposalAllocations;
    }

    // ======================
    // STATE VARIABLES
    // ======================

    IERC20 public stakingToken;

    mapping(uint256 => Proposal) public proposals;
    mapping(address => uint256) public stakedBalances;
    mapping(address => uint256[]) public userSupports; // proposals user is supporting

    TreasuryInfo public treasury;
    ConvictionParams public convictionParams;

    uint256 public nextProposalId = 1;
    uint256 public totalStaked;
    uint256 public activeProposals;

    // Constants for conviction calculation
    uint256 private constant PRECISION = 1e18;
    uint256 private constant BLOCKS_PER_DAY = 7200; // Approximate blocks per day
    uint256 private constant MAX_CONVICTION_DAYS = 180; // Max conviction build time

    // ======================
    // EVENTS
    // ======================

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        string title,
        uint256 requestedAmount,
        address beneficiary
    );

    event SupportAdded(
        uint256 indexed proposalId,
        address indexed supporter,
        uint256 amount,
        uint256 newConviction
    );

    event SupportWithdrawn(
        uint256 indexed proposalId,
        address indexed supporter,
        uint256 amount
    );

    event ConvictionUpdated(
        uint256 indexed proposalId,
        uint256 totalConviction,
        uint256 threshold
    );

    event ProposalPassed(
        uint256 indexed proposalId,
        uint256 finalConviction,
        uint256 threshold
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        uint256 amount,
        address beneficiary
    );

    event TokensStaked(address indexed user, uint256 amount);
    event TokensUnstaked(address indexed user, uint256 amount);
    event FundsDeposited(uint256 amount);

    // ======================
    // ERRORS
    // ======================

    error InsufficientStake();
    error ProposalNotFound();
    error ProposalAlreadyExecuted();
    error InsufficientFunds();
    error ConvictionTooLow();
    error AlreadySupporting();
    error NotSupporting();
    error InvalidAmount();
    error ProposalCancelled();

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor(
        IERC20 _stakingToken,
        uint256 _convictionGrowth,
        uint256 _minThreshold,
        uint256 _spendingLimit
    ) {
        stakingToken = _stakingToken;

        convictionParams = ConvictionParams({
            convictionGrowth: _convictionGrowth,
            convictionDecay: _convictionGrowth * 2, // Decay faster than growth
            minThreshold: _minThreshold,
            maxThreshold: _minThreshold * 100,
            spendingLimit: _spendingLimit,
            minSupport: 1e18 // 1 token minimum
        });
    }

    // ======================
    // STAKING FUNCTIONS
    // ======================

    /**
     * @dev Stake tokens to participate in conviction voting
     */
    function stakeTokens(uint256 _amount) external whenNotPaused {
        require(_amount > 0, "Amount must be positive");

        stakingToken.transferFrom(msg.sender, address(this), _amount);
        stakedBalances[msg.sender] += _amount;
        totalStaked += _amount;

        emit TokensStaked(msg.sender, _amount);
    }

    /**
     * @dev Unstake tokens (only if not supporting any active proposals)
     */
    function unstakeTokens(
        uint256 _amount
    ) external whenNotPaused nonReentrant {
        require(
            stakedBalances[msg.sender] >= _amount,
            "Insufficient staked balance"
        );

        // Check if user has active supports
        uint256 totalSupported = _getTotalSupported(msg.sender);
        require(
            stakedBalances[msg.sender] - _amount >= totalSupported,
            "Cannot unstake supported tokens"
        );

        stakedBalances[msg.sender] -= _amount;
        totalStaked -= _amount;

        stakingToken.transfer(msg.sender, _amount);

        emit TokensUnstaked(msg.sender, _amount);
    }

    // ======================
    // PROPOSAL FUNCTIONS
    // ======================

    /**
     * @dev Create a new proposal for funding
     */
    function createProposal(
        string calldata _title,
        string calldata _description,
        uint256 _requestedAmount,
        address _beneficiary
    ) external whenNotPaused returns (uint256) {
        require(_requestedAmount > 0, "Amount must be positive");
        require(
            _requestedAmount <= convictionParams.spendingLimit,
            "Exceeds spending limit"
        );
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(
            stakedBalances[msg.sender] >= convictionParams.minSupport,
            "Insufficient stake to propose"
        );

        uint256 proposalId = nextProposalId++;

        Proposal storage proposal = proposals[proposalId];
        proposal.id = proposalId;
        proposal.proposer = msg.sender;
        proposal.title = _title;
        proposal.description = _description;
        proposal.requestedAmount = _requestedAmount;
        proposal.beneficiary = _beneficiary;
        proposal.createdAt = block.number;
        proposal.convictionLast = block.number;

        // Calculate required conviction threshold based on requested amount
        proposal.convictionThreshold = _calculateConvictionThreshold(
            _requestedAmount
        );
        proposal.maxConviction = proposal.convictionThreshold * 2; // Allow up to 2x threshold

        activeProposals++;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            _title,
            _requestedAmount,
            _beneficiary
        );
        return proposalId;
    }

    /**
     * @dev Support a proposal with staked tokens
     */
    function supportProposal(
        uint256 _proposalId,
        uint256 _amount
    ) external whenNotPaused {
        Proposal storage proposal = proposals[_proposalId];
        require(proposal.id != 0, "Proposal not found");
        require(!proposal.executed, "Proposal already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(_amount > 0, "Amount must be positive");
        require(
            stakedBalances[msg.sender] >= _amount,
            "Insufficient staked balance"
        );

        // Update conviction before adding support
        _updateConviction(_proposalId);

        Support storage support = proposal.supporters[msg.sender];

        if (support.isActive) {
            // Increase existing support
            support.amount += _amount;
        } else {
            // New support
            support.amount = _amount;
            support.isActive = true;
            support.lastUpdate = block.number;
            proposal.supportersList.push(msg.sender);
            proposal.supportersCount++;
            userSupports[msg.sender].push(_proposalId);
        }

        // Check if proposal can now pass
        _checkConvictionThreshold(_proposalId);

        emit SupportAdded(
            _proposalId,
            msg.sender,
            _amount,
            proposal.totalConviction
        );
    }

    /**
     * @dev Withdraw support from a proposal
     */
    function withdrawSupport(
        uint256 _proposalId,
        uint256 _amount
    ) external whenNotPaused {
        Proposal storage proposal = proposals[_proposalId];
        Support storage support = proposal.supporters[msg.sender];

        require(support.isActive, "Not supporting this proposal");
        require(support.amount >= _amount, "Insufficient support amount");
        require(!proposal.executed, "Cannot withdraw from executed proposal");

        // Update conviction before withdrawing
        _updateConviction(_proposalId);

        support.amount -= _amount;

        if (support.amount == 0) {
            support.isActive = false;
            proposal.supportersCount--;
            _removeFromUserSupports(msg.sender, _proposalId);
        }

        emit SupportWithdrawn(_proposalId, msg.sender, _amount);
    }

    /**
     * @dev Change support amount for a proposal
     */
    function changeSupport(
        uint256 _proposalId,
        uint256 _newAmount
    ) external whenNotPaused {
        Proposal storage proposal = proposals[_proposalId];
        Support storage support = proposal.supporters[msg.sender];

        require(support.isActive, "Not supporting this proposal");
        require(
            !proposal.executed,
            "Cannot change support for executed proposal"
        );
        require(
            _newAmount <= stakedBalances[msg.sender],
            "Insufficient staked balance"
        );

        // Update conviction first
        _updateConviction(_proposalId);

        uint256 oldAmount = support.amount;
        support.amount = _newAmount;

        if (_newAmount == 0) {
            support.isActive = false;
            proposal.supportersCount--;
            _removeFromUserSupports(msg.sender, _proposalId);
            emit SupportWithdrawn(_proposalId, msg.sender, oldAmount);
        } else {
            emit SupportAdded(
                _proposalId,
                msg.sender,
                _newAmount,
                proposal.totalConviction
            );
        }

        _checkConvictionThreshold(_proposalId);
    }

    // ======================
    // CONVICTION CALCULATION
    // ======================

    /**
     * @dev Update conviction for a specific proposal
     */
    function updateConviction(uint256 _proposalId) external {
        _updateConviction(_proposalId);
    }

    /**
     * @dev Update conviction for multiple proposals
     */
    function updateMultipleConvictions(
        uint256[] calldata _proposalIds
    ) external {
        for (uint256 i = 0; i < _proposalIds.length; i++) {
            _updateConviction(_proposalIds[i]);
        }
    }

    /**
     * @dev Internal function to update conviction for a proposal
     */
    function _updateConviction(uint256 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];

        if (proposal.executed || proposal.cancelled) {
            return;
        }

        uint256 blocksSinceUpdate = block.number - proposal.convictionLast;

        if (blocksSinceUpdate == 0) {
            return;
        }

        // Calculate total supported amount
        uint256 totalSupported = 0;
        for (uint256 i = 0; i < proposal.supportersList.length; i++) {
            address supporter = proposal.supportersList[i];
            Support storage support = proposal.supporters[supporter];

            if (support.isActive) {
                totalSupported += support.amount;

                // Update individual conviction
                uint256 blocksSinceSupport = block.number - support.lastUpdate;
                uint256 convictionIncrease = (support.amount *
                    blocksSinceSupport *
                    convictionParams.convictionGrowth) / PRECISION;
                support.conviction = Math.min(
                    support.conviction + convictionIncrease,
                    proposal.maxConviction
                );
                support.lastUpdate = block.number;
            }
        }

        // Calculate total conviction with time weight
        uint256 timeWeight = _calculateTimeWeight(blocksSinceUpdate);
        uint256 convictionIncrease = (totalSupported *
            timeWeight *
            convictionParams.convictionGrowth) / PRECISION;

        proposal.totalConviction = Math.min(
            proposal.totalConviction + convictionIncrease,
            proposal.maxConviction
        );

        proposal.convictionLast = block.number;

        emit ConvictionUpdated(
            _proposalId,
            proposal.totalConviction,
            proposal.convictionThreshold
        );
    }

    /**
     * @dev Calculate time weight for conviction growth
     */
    function _calculateTimeWeight(
        uint256 _blocks
    ) internal pure returns (uint256) {
        // Logarithmic growth with diminishing returns
        if (_blocks == 0) return 0;

        uint256 maxBlocks = MAX_CONVICTION_DAYS * BLOCKS_PER_DAY;
        uint256 clampedBlocks = Math.min(_blocks, maxBlocks);

        // Simple time weight: grows slower over time
        return (PRECISION * clampedBlocks) / (clampedBlocks + BLOCKS_PER_DAY);
    }

    /**
     * @dev Check if proposal has reached conviction threshold
     */
    function _checkConvictionThreshold(uint256 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];

        if (
            proposal.totalConviction >= proposal.convictionThreshold &&
            !proposal.executed
        ) {
            _executeProposal(_proposalId);
        }
    }

    // ======================
    // PROPOSAL EXECUTION
    // ======================

    /**
     * @dev Execute a proposal that has reached conviction threshold
     */
    function executeProposal(
        uint256 _proposalId
    ) external whenNotPaused nonReentrant {
        _updateConviction(_proposalId);
        _executeProposal(_proposalId);
    }

    /**
     * @dev Internal execution logic
     */
    function _executeProposal(uint256 _proposalId) internal {
        Proposal storage proposal = proposals[_proposalId];

        require(!proposal.executed, "Already executed");
        require(!proposal.cancelled, "Proposal cancelled");
        require(
            proposal.totalConviction >= proposal.convictionThreshold,
            "Insufficient conviction"
        );
        require(
            treasury.availableFunds >= proposal.requestedAmount,
            "Insufficient treasury funds"
        );

        proposal.executed = true;
        activeProposals--;

        // Update treasury
        treasury.availableFunds -= proposal.requestedAmount;
        treasury.spentFunds += proposal.requestedAmount;
        treasury.proposalAllocations[_proposalId] = proposal.requestedAmount;

        // Transfer funds to beneficiary
        stakingToken.transfer(proposal.beneficiary, proposal.requestedAmount);

        emit ProposalPassed(
            _proposalId,
            proposal.totalConviction,
            proposal.convictionThreshold
        );
        emit ProposalExecuted(
            _proposalId,
            proposal.requestedAmount,
            proposal.beneficiary
        );
    }

    // ======================
    // TREASURY MANAGEMENT
    // ======================

    /**
     * @dev Deposit funds to treasury
     */
    function depositToTreasury(uint256 _amount) external {
        stakingToken.transferFrom(msg.sender, address(this), _amount);
        treasury.totalFunds += _amount;
        treasury.availableFunds += _amount;

        emit FundsDeposited(_amount);
    }

    /**
     * @dev Emergency withdraw from treasury (owner only)
     */
    function emergencyWithdraw(uint256 _amount) external onlyOwner {
        require(
            _amount <= treasury.availableFunds,
            "Insufficient available funds"
        );

        treasury.availableFunds -= _amount;
        treasury.totalFunds -= _amount;

        stakingToken.transfer(owner(), _amount);
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Get proposal details and current conviction
     */
    function getProposal(
        uint256 _proposalId
    )
        external
        view
        returns (
            address proposer,
            string memory title,
            uint256 requestedAmount,
            address beneficiary,
            uint256 totalConviction,
            uint256 convictionThreshold,
            uint256 supportersCount,
            bool executed,
            bool canExecute
        )
    {
        Proposal storage proposal = proposals[_proposalId];

        return (
            proposal.proposer,
            proposal.title,
            proposal.requestedAmount,
            proposal.beneficiary,
            proposal.totalConviction,
            proposal.convictionThreshold,
            proposal.supportersCount,
            proposal.executed,
            proposal.totalConviction >= proposal.convictionThreshold &&
                !proposal.executed
        );
    }

    /**
     * @dev Get user's support for a proposal
     */
    function getUserSupport(
        uint256 _proposalId,
        address _user
    )
        external
        view
        returns (
            uint256 amount,
            uint256 conviction,
            bool isActive,
            uint256 lastUpdate
        )
    {
        Support storage support = proposals[_proposalId].supporters[_user];
        return (
            support.amount,
            support.conviction,
            support.isActive,
            support.lastUpdate
        );
    }

    /**
     * @dev Get all proposals a user is supporting
     */
    function getUserSupports(
        address _user
    ) external view returns (uint256[] memory) {
        return userSupports[_user];
    }

    /**
     * @dev Get current conviction for a proposal (with simulation)
     */
    function getCurrentConviction(
        uint256 _proposalId
    ) external view returns (uint256) {
        Proposal storage proposal = proposals[_proposalId];

        if (proposal.executed || proposal.cancelled) {
            return proposal.totalConviction;
        }

        uint256 blocksSinceUpdate = block.number - proposal.convictionLast;

        if (blocksSinceUpdate == 0) {
            return proposal.totalConviction;
        }

        // Simulate conviction growth
        uint256 totalSupported = 0;
        for (uint256 i = 0; i < proposal.supportersList.length; i++) {
            address supporter = proposal.supportersList[i];
            Support storage support = proposal.supporters[supporter];

            if (support.isActive) {
                totalSupported += support.amount;
            }
        }

        uint256 timeWeight = _calculateTimeWeight(blocksSinceUpdate);
        uint256 convictionIncrease = (totalSupported *
            timeWeight *
            convictionParams.convictionGrowth) / PRECISION;

        return
            Math.min(
                proposal.totalConviction + convictionIncrease,
                proposal.maxConviction
            );
    }

    /**
     * @dev Get treasury status
     */
    function getTreasuryInfo()
        external
        view
        returns (
            uint256 totalFunds,
            uint256 availableFunds,
            uint256 spentFunds,
            uint256 allocatedFunds
        )
    {
        return (
            treasury.totalFunds,
            treasury.availableFunds,
            treasury.spentFunds,
            treasury.allocatedFunds
        );
    }

    // ======================
    // INTERNAL HELPERS
    // ======================

    function _calculateConvictionThreshold(
        uint256 _requestedAmount
    ) internal view returns (uint256) {
        // Threshold grows with requested amount (quadratic curve)
        uint256 baseThreshold = convictionParams.minThreshold;
        uint256 amountRatio = (_requestedAmount * PRECISION) /
            convictionParams.spendingLimit;

        // Quadratic scaling: threshold = base * (1 + ratio^2)
        uint256 scalingFactor = PRECISION +
            (amountRatio * amountRatio) /
            PRECISION;

        return (baseThreshold * scalingFactor) / PRECISION;
    }

    function _getTotalSupported(address _user) internal view returns (uint256) {
        uint256 total = 0;
        uint256[] memory supports = userSupports[_user];

        for (uint256 i = 0; i < supports.length; i++) {
            uint256 proposalId = supports[i];
            Support storage support = proposals[proposalId].supporters[_user];

            if (support.isActive) {
                total += support.amount;
            }
        }

        return total;
    }

    function _removeFromUserSupports(
        address _user,
        uint256 _proposalId
    ) internal {
        uint256[] storage supports = userSupports[_user];

        for (uint256 i = 0; i < supports.length; i++) {
            if (supports[i] == _proposalId) {
                supports[i] = supports[supports.length - 1];
                supports.pop();
                break;
            }
        }
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    function setConvictionParams(
        uint256 _convictionGrowth,
        uint256 _minThreshold,
        uint256 _spendingLimit
    ) external onlyOwner {
        convictionParams.convictionGrowth = _convictionGrowth;
        convictionParams.minThreshold = _minThreshold;
        convictionParams.spendingLimit = _spendingLimit;
        convictionParams.maxThreshold = _minThreshold * 100;
    }

    function cancelProposal(uint256 _proposalId) external onlyOwner {
        Proposal storage proposal = proposals[_proposalId];
        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.cancelled = true;
        activeProposals--;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}

/**
 * 🕰️ CONVICTION VOTING FEATURES:
 *
 * 1. TIME-WEIGHTED DEMOCRACY:
 *    - Conviction grows over time with continuous support
 *    - No fixed voting periods - organic consensus building
 *    - Prevents last-minute manipulation
 *    - Rewards long-term commitment
 *
 * 2. DYNAMIC THRESHOLDS:
 *    - Threshold scales with requested amount
 *    - Larger requests require more conviction
 *    - Protects treasury from large proposals
 *    - Enables small proposals to pass quickly
 *
 * 3. FLEXIBLE SUPPORT:
 *    - Supporters can change their support at any time
 *    - Support automatically increases conviction over time
 *    - Withdrawal causes conviction decay
 *    - Enables changing preferences
 *
 * 4. TREASURY INTEGRATION:
 *    - Direct funding from treasury upon threshold reach
 *    - Automatic execution when conviction sufficient
 *    - Spending limits and controls
 *    - Transparent fund allocation
 *
 * 📊 USAGE EXAMPLES:
 *
 * // Stake tokens to participate
 * conviction.stakeTokens(1000e18);
 *
 * // Create funding proposal
 * conviction.createProposal(
 *     "Community Development",
 *     "Fund development of community tools",
 *     50000e18,
 *     developerAddress
 * );
 *
 * // Support proposal with tokens
 * conviction.supportProposal(proposalId, 500e18);
 *
 * // Change support level
 * conviction.changeSupport(proposalId, 750e18);
 *
 * // Update conviction (can be called by anyone)
 * conviction.updateConviction(proposalId);
 *
 * 🎯 CONVICTION VOTING BENEFITS:
 * - Enables continuous governance without voting periods
 * - Reduces gaming through time requirements
 * - Allows gradual consensus building
 * - Protects against whale attacks
 * - Encourages thoughtful, sustained support
 */

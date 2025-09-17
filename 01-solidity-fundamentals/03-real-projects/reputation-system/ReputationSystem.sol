// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ReputationSystem - Production-Ready Reputation Protocol
 * @author Solidity Course - Learn by Building Real DeFi
 * @notice A decentralized reputation system inspired by Uber, Airbnb, and Web3 identity protocols
 * @dev Demonstrates advanced mappings, access control, and event-driven architecture
 *
 * LEARNING GOALS:
 * - Master nested mappings and complex data structures
 * - Understand reputation mathematics and algorithms
 * - Learn production-grade access control patterns
 * - Build systems that scale to millions of users
 *
 * REAL-WORLD INSPIRATION:
 * - Uber: Driver/rider rating system (5-star ratings)
 * - Airbnb: Host/guest reputation with reviews
 * - Amazon: Product and seller ratings
 * - Web3 Identity: Gitcoin Passport, Worldcoin, ENS
 *
 * HACKATHON POTENTIAL:
 * This contract demonstrates patterns for:
 * - Decentralized identity and reputation
 * - Cross-platform reputation portability
 * - Sybil attack resistance
 * - Reputation-based access control
 * - Social credit scoring systems
 */

contract ReputationSystem {
    // ===== PROTOCOL CONSTANTS =====

    string public constant PROTOCOL_NAME = "ReputationDAO";
    string public constant VERSION = "1.0.0";

    // Reputation scoring parameters (inspired by PageRank algorithm)
    uint256 public constant MIN_RATING = 1; // Minimum rating (1 star)
    uint256 public constant MAX_RATING = 5; // Maximum rating (5 stars)
    uint256 public constant INITIAL_REPUTATION = 100; // Starting reputation score
    uint256 public constant MAX_REPUTATION = 1000; // Maximum possible reputation
    uint256 public constant REPUTATION_DECAY_RATE = 1; // Daily decay rate (1 point per day)

    // Anti-spam and sybil resistance
    uint256 public constant MIN_STAKE_FOR_RATING = 0.01 ether; // Minimum ETH to rate
    uint256 public constant COOLDOWN_PERIOD = 1 days; // Cooldown between ratings
    uint256 public constant MAX_RATINGS_PER_USER = 100; // Maximum ratings from one user

    // ===== STATE VARIABLES =====

    address public immutable owner;
    address public reputationOracle; // Oracle for external reputation data
    bool public systemPaused; // Emergency pause mechanism
    uint256 public totalUsers; // Total registered users
    uint256 public totalRatings; // Total ratings given
    uint256 public protocolRevenue; // Revenue from staking fees

    // ===== DATA STRUCTURES =====

    // Core user profile with comprehensive reputation data
    struct UserProfile {
        address userAddress; // User's wallet address
        string username; // Chosen username (unique)
        string profileURI; // IPFS hash for profile metadata
        uint256 reputation; // Current reputation score (0-1000)
        uint256 totalRatingsReceived; // Number of ratings received
        uint256 totalRatingsGiven; // Number of ratings given
        uint256 averageRating; // Average star rating (1-5, scaled by 100)
        uint256 lastActivityTimestamp; // Last interaction timestamp
        uint256 joinDate; // Account creation date
        bool isVerified; // Verification status (KYC/social)
        bool isActive; // Account active status
        uint256 stakedAmount; // ETH staked for rating privileges
        uint256 lastRatingTimestamp; // Last time user gave a rating
    }

    // Individual rating with full context
    struct Rating {
        address rater; // Who gave the rating
        address ratee; // Who received the rating
        uint8 stars; // Star rating (1-5)
        string category; // Rating category (service, product, etc.)
        string comment; // Written review/comment
        uint256 timestamp; // When rating was given
        uint256 stakeAmount; // ETH staked with this rating
        bool isVerified; // Verified transaction rating
        uint256 helpfulVotes; // Community helpful votes
        uint256 reportCount; // Spam/abuse reports
    }

    // Reputation category breakdown (multi-dimensional reputation)
    struct CategoryReputation {
        uint256 serviceQuality; // Service quality score
        uint256 reliability; // Reliability/punctuality score
        uint256 communication; // Communication skills score
        uint256 trustworthiness; // Trust and honesty score
        uint256 expertise; // Domain expertise score
    }

    // Platform/service integration data
    struct PlatformReputation {
        string platformName; // Platform identifier (Uber, Airbnb, etc.)
        uint256 externalReputation; // Reputation score from external platform
        uint256 verificationLevel; // Level of verification (0-3)
        uint256 lastUpdate; // Last sync timestamp
        bool isActive; // Active integration status
    }

    // ===== MAPPINGS (Complex Data Relationships) =====

    // Core user data
    mapping(address => UserProfile) public users; // Address → User Profile
    mapping(string => address) public usernameToAddress; // Username → Address
    mapping(address => bool) public isRegistered; // Quick registration check

    // Rating system mappings
    mapping(uint256 => Rating) public ratings; // Rating ID → Rating Data
    mapping(address => uint256[]) public ratingsReceived; // User → Array of Rating IDs received
    mapping(address => uint256[]) public ratingsGiven; // User → Array of Rating IDs given
    mapping(address => mapping(address => uint256)) public userToUserRating; // Rater → Ratee → Rating ID
    mapping(address => mapping(string => uint256[])) public categoryRatings; // User → Category → Rating IDs

    // Advanced reputation tracking
    mapping(address => CategoryReputation) public categoryScores; // User → Category Breakdown
    mapping(address => mapping(string => PlatformReputation))
        public platformIntegrations; // User → Platform → Data
    mapping(address => mapping(address => bool)) public hasRated; // Rater → Ratee → Has Rated (prevent double rating)

    // Governance and moderation
    mapping(address => bool) public moderators; // Moderator addresses
    mapping(address => uint256) public userStakes; // User → Staked ETH amount
    mapping(uint256 => mapping(address => bool)) public ratingHelpfulVotes; // Rating ID → Voter → Has Voted
    mapping(address => uint256) public lastActivityTime; // User → Last Activity (for decay)

    // ===== ARRAYS FOR ITERATION =====

    address[] public allUsers; // All registered users
    uint256[] public allRatingIds; // All rating IDs
    string[] public supportedCategories; // Supported rating categories

    // ===== COUNTERS =====

    uint256 public nextRatingId = 1; // Next rating ID to assign
    uint256 public nextUserId = 1; // Next user ID to assign

    // ===== EVENTS =====

    // User lifecycle events
    event UserRegistered(
        address indexed user,
        string username,
        uint256 timestamp
    );

    event UserVerified(
        address indexed user,
        string verificationType,
        uint256 timestamp
    );

    event ProfileUpdated(
        address indexed user,
        string newProfileURI,
        uint256 timestamp
    );

    // Rating events
    event RatingGiven(
        address indexed rater,
        address indexed ratee,
        uint256 indexed ratingId,
        uint8 stars,
        string category,
        uint256 stakeAmount,
        uint256 timestamp
    );

    event RatingUpdated(
        uint256 indexed ratingId,
        uint8 newStars,
        string newComment,
        uint256 timestamp
    );

    event RatingDisputed(
        uint256 indexed ratingId,
        address indexed disputer,
        string reason,
        uint256 timestamp
    );

    // Reputation events
    event ReputationUpdated(
        address indexed user,
        uint256 oldReputation,
        uint256 newReputation,
        string reason,
        uint256 timestamp
    );

    event CategoryScoreUpdated(
        address indexed user,
        string category,
        uint256 newScore,
        uint256 timestamp
    );

    event PlatformIntegrationAdded(
        address indexed user,
        string platformName,
        uint256 externalReputation,
        uint256 timestamp
    );

    // Moderation events
    event RatingReported(
        uint256 indexed ratingId,
        address indexed reporter,
        string reason,
        uint256 timestamp
    );

    event RatingRemoved(
        uint256 indexed ratingId,
        address indexed moderator,
        string reason,
        uint256 timestamp
    );

    // ===== MODIFIERS =====

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyModerator() {
        require(
            moderators[msg.sender] || msg.sender == owner,
            "Only moderator"
        );
        _;
    }

    modifier whenNotPaused() {
        require(!systemPaused, "System paused");
        _;
    }

    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "Not registered");
        _;
    }

    modifier validRating(uint8 _stars) {
        require(_stars >= MIN_RATING && _stars <= MAX_RATING, "Invalid rating");
        _;
    }

    modifier canRate(address _ratee) {
        require(_ratee != msg.sender, "Cannot rate yourself");
        require(isRegistered[_ratee], "Ratee not registered");
        require(!hasRated[msg.sender][_ratee], "Already rated this user");
        require(
            block.timestamp >=
                users[msg.sender].lastRatingTimestamp + COOLDOWN_PERIOD,
            "Cooldown period active"
        );
        require(msg.value >= MIN_STAKE_FOR_RATING, "Insufficient stake");
        _;
    }

    // ===== CONSTRUCTOR =====

    /**
     * @dev Initialize the reputation system
     * @param _reputationOracle Oracle address for external reputation data
     */
    constructor(address _reputationOracle) {
        owner = msg.sender;
        reputationOracle = _reputationOracle;
        systemPaused = false;

        // Initialize supported categories
        supportedCategories.push("service");
        supportedCategories.push("product");
        supportedCategories.push("communication");
        supportedCategories.push("reliability");
        supportedCategories.push("expertise");

        // Set owner as initial moderator
        moderators[owner] = true;
    }

    // ===== USER REGISTRATION =====

    /**
     * @title Register New User
     * @dev Registers a new user in the reputation system
     * @param _username Unique username for the user
     * @param _profileURI IPFS hash containing profile metadata
     *
     * Requirements:
     * - Username must be unique and non-empty
     * - User address must not be already registered
     * - System must not be paused
     */
    function registerUser(
        string calldata _username,
        string calldata _profileURI
    ) external payable whenNotPaused {
        require(!isRegistered[msg.sender], "Already registered");
        require(bytes(_username).length > 0, "Username required");
        require(usernameToAddress[_username] == address(0), "Username taken");

        // Create user profile
        users[msg.sender] = UserProfile({
            userAddress: msg.sender,
            username: _username,
            profileURI: _profileURI,
            reputation: INITIAL_REPUTATION,
            totalRatingsReceived: 0,
            totalRatingsGiven: 0,
            averageRating: 0,
            lastActivityTimestamp: block.timestamp,
            joinDate: block.timestamp,
            isVerified: false,
            isActive: true,
            stakedAmount: msg.value,
            lastRatingTimestamp: 0
        });

        // Initialize category scores
        categoryScores[msg.sender] = CategoryReputation({
            serviceQuality: INITIAL_REPUTATION,
            reliability: INITIAL_REPUTATION,
            communication: INITIAL_REPUTATION,
            trustworthiness: INITIAL_REPUTATION,
            expertise: INITIAL_REPUTATION
        });

        // Update mappings and arrays
        isRegistered[msg.sender] = true;
        usernameToAddress[_username] = msg.sender;
        allUsers.push(msg.sender);

        if (msg.value > 0) {
            userStakes[msg.sender] = msg.value;
        }

        totalUsers++;

        emit UserRegistered(msg.sender, _username, block.timestamp);
    }

    // ===== RATING SYSTEM =====

    /**
     * @title Give Rating
     * @dev Allows a user to rate another user with ETH stake
     * @param _ratee Address of user being rated
     * @param _stars Star rating (1-5)
     * @param _category Rating category
     * @param _comment Written review/comment
     *
     * Requirements:
     * - Both users must be registered
     * - Cannot rate yourself
     * - Must stake minimum ETH amount
     * - Must respect cooldown period
     * - Cannot double-rate the same user
     */
    function giveRating(
        address _ratee,
        uint8 _stars,
        string calldata _category,
        string calldata _comment
    )
        external
        payable
        whenNotPaused
        onlyRegistered
        validRating(_stars)
        canRate(_ratee)
    {
        // Create rating record
        uint256 ratingId = nextRatingId++;

        ratings[ratingId] = Rating({
            rater: msg.sender,
            ratee: _ratee,
            stars: _stars,
            category: _category,
            comment: _comment,
            timestamp: block.timestamp,
            stakeAmount: msg.value,
            isVerified: _isVerifiedTransaction(),
            helpfulVotes: 0,
            reportCount: 0
        });

        // Update user rating arrays
        ratingsGiven[msg.sender].push(ratingId);
        ratingsReceived[_ratee].push(ratingId);
        categoryRatings[_ratee][_category].push(ratingId);
        allRatingIds.push(ratingId);

        // Prevent double rating
        hasRated[msg.sender][_ratee] = true;
        userToUserRating[msg.sender][_ratee] = ratingId;

        // Update user profiles
        users[msg.sender].totalRatingsGiven++;
        users[msg.sender].lastRatingTimestamp = block.timestamp;
        users[msg.sender].lastActivityTimestamp = block.timestamp;
        users[_ratee].totalRatingsReceived++;
        users[_ratee].lastActivityTimestamp = block.timestamp;

        // Add stake to user's staked amount
        userStakes[msg.sender] += msg.value;
        users[msg.sender].stakedAmount += msg.value;

        // Update reputation scores
        _updateReputation(_ratee, _stars, _category);

        // Update protocol metrics
        totalRatings++;
        protocolRevenue += msg.value / 100; // 1% protocol fee

        emit RatingGiven(
            msg.sender,
            _ratee,
            ratingId,
            _stars,
            _category,
            msg.value,
            block.timestamp
        );
    }

    // ===== REPUTATION CALCULATION =====

    /**
     * @dev Internal function to update user reputation based on new rating
     * @param _user User whose reputation is being updated
     * @param _stars Star rating received
     * @param _category Category of the rating
     */
    function _updateReputation(
        address _user,
        uint8 _stars,
        string memory _category
    ) internal {
        UserProfile storage user = users[_user];
        uint256 oldReputation = user.reputation;

        // Calculate new average rating
        uint256 totalRatings = user.totalRatingsReceived;
        if (totalRatings == 1) {
            // First rating
            user.averageRating = _stars * 100; // Scale by 100 for precision
        } else {
            // Weighted average of existing ratings
            user.averageRating =
                ((user.averageRating * (totalRatings - 1)) + (_stars * 100)) /
                totalRatings;
        }

        // Update overall reputation (simplified algorithm)
        // In production, this would be more sophisticated (PageRank-style)
        uint256 ratingWeight = _calculateRatingWeight(msg.sender);
        uint256 reputationChange = (_stars * ratingWeight * 10) / 100; // Scale factor

        if (_stars >= 4) {
            // Good rating increases reputation
            user.reputation = _min(
                user.reputation + reputationChange,
                MAX_REPUTATION
            );
        } else if (_stars <= 2) {
            // Bad rating decreases reputation
            user.reputation = user.reputation > reputationChange
                ? user.reputation - reputationChange
                : 0;
        }
        // Neutral ratings (3 stars) don't change reputation much

        // Update category-specific reputation
        _updateCategoryReputation(_user, _category, _stars);

        emit ReputationUpdated(
            _user,
            oldReputation,
            user.reputation,
            string(abi.encodePacked("Rating: ", _stars, " stars")),
            block.timestamp
        );
    }

    /**
     * @dev Calculate the weight of a rating based on rater's reputation
     * @param _rater Address of the user giving the rating
     * @return weight Weight factor for the rating (higher reputation = higher weight)
     */
    function _calculateRatingWeight(
        address _rater
    ) internal view returns (uint256 weight) {
        UserProfile memory rater = users[_rater];

        // Base weight
        weight = 100;

        // Reputation multiplier (higher reputation = higher weight)
        weight = (weight * rater.reputation) / INITIAL_REPUTATION;

        // Verification bonus
        if (rater.isVerified) {
            weight += 50;
        }

        // Activity bonus (more active users have higher weight)
        if (rater.totalRatingsGiven > 10) {
            weight += 25;
        }

        // Stake bonus (higher stake = higher weight)
        if (rater.stakedAmount > MIN_STAKE_FOR_RATING * 10) {
            weight += 25;
        }

        return weight;
    }

    /**
     * @dev Update category-specific reputation scores
     * @param _user User whose category reputation is being updated
     * @param _category Category being rated
     * @param _stars Star rating received
     */
    function _updateCategoryReputation(
        address _user,
        string memory _category,
        uint8 _stars
    ) internal {
        CategoryReputation storage catRep = categoryScores[_user];
        uint256 change = _stars * 20; // Scale factor for category scores

        // Update specific category (simplified - in production would be more nuanced)
        if (keccak256(bytes(_category)) == keccak256(bytes("service"))) {
            catRep.serviceQuality = _updateCategoryScore(
                catRep.serviceQuality,
                change,
                _stars
            );
        } else if (
            keccak256(bytes(_category)) == keccak256(bytes("communication"))
        ) {
            catRep.communication = _updateCategoryScore(
                catRep.communication,
                change,
                _stars
            );
        } else if (
            keccak256(bytes(_category)) == keccak256(bytes("reliability"))
        ) {
            catRep.reliability = _updateCategoryScore(
                catRep.reliability,
                change,
                _stars
            );
        } else if (
            keccak256(bytes(_category)) == keccak256(bytes("expertise"))
        ) {
            catRep.expertise = _updateCategoryScore(
                catRep.expertise,
                change,
                _stars
            );
        }
        // Default case updates trustworthiness
        catRep.trustworthiness = _updateCategoryScore(
            catRep.trustworthiness,
            change,
            _stars
        );

        emit CategoryScoreUpdated(_user, _category, change, block.timestamp);
    }

    /**
     * @dev Helper function to update individual category score
     * @param currentScore Current score in the category
     * @param change Amount of change to apply
     * @param stars Number of stars in the rating
     * @return newScore Updated category score
     */
    function _updateCategoryScore(
        uint256 currentScore,
        uint256 change,
        uint8 stars
    ) internal pure returns (uint256 newScore) {
        if (stars >= 4) {
            newScore = _min(currentScore + change, MAX_REPUTATION);
        } else if (stars <= 2) {
            newScore = currentScore > change ? currentScore - change : 0;
        } else {
            newScore = currentScore; // Neutral rating doesn't change score
        }
        return newScore;
    }

    // ===== VIEW FUNCTIONS =====

    /**
     * @title Get User Reputation
     * @dev Returns comprehensive reputation data for a user
     * @param _user User address to query
     * @return profile Complete user profile
     * @return categoryRep Category-specific reputation breakdown
     */
    function getUserReputation(
        address _user
    )
        external
        view
        returns (
            UserProfile memory profile,
            CategoryReputation memory categoryRep
        )
    {
        require(isRegistered[_user], "User not registered");
        return (users[_user], categoryScores[_user]);
    }

    /**
     * @title Get User Ratings
     * @dev Returns all ratings received by a user
     * @param _user User address to query
     * @return receivedRatings Array of ratings received
     * @return givenRatings Array of ratings given
     */
    function getUserRatings(
        address _user
    )
        external
        view
        returns (Rating[] memory receivedRatings, Rating[] memory givenRatings)
    {
        require(isRegistered[_user], "User not registered");

        uint256[] memory receivedIds = ratingsReceived[_user];
        uint256[] memory givenIds = ratingsGiven[_user];

        receivedRatings = new Rating[](receivedIds.length);
        givenRatings = new Rating[](givenIds.length);

        for (uint256 i = 0; i < receivedIds.length; i++) {
            receivedRatings[i] = ratings[receivedIds[i]];
        }

        for (uint256 i = 0; i < givenIds.length; i++) {
            givenRatings[i] = ratings[givenIds[i]];
        }

        return (receivedRatings, givenRatings);
    }

    /**
     * @title Get Protocol Statistics
     * @dev Returns overall protocol metrics
     */
    function getProtocolStats()
        external
        view
        returns (
            uint256 _totalUsers,
            uint256 _totalRatings,
            uint256 _averageReputation,
            uint256 _totalStaked,
            uint256 _protocolRevenue
        )
    {
        _totalUsers = totalUsers;
        _totalRatings = totalRatings;
        _protocolRevenue = protocolRevenue;

        // Calculate total staked
        _totalStaked = address(this).balance;

        // Calculate average reputation
        if (totalUsers > 0) {
            uint256 totalReputation = 0;
            for (uint256 i = 0; i < allUsers.length; i++) {
                totalReputation += users[allUsers[i]].reputation;
            }
            _averageReputation = totalReputation / totalUsers;
        } else {
            _averageReputation = 0;
        }

        return (
            _totalUsers,
            _totalRatings,
            _averageReputation,
            _totalStaked,
            _protocolRevenue
        );
    }

    // ===== UTILITY FUNCTIONS =====

    function _isVerifiedTransaction() internal pure returns (bool) {
        // Simplified verification logic
        // In production, this would check various factors like gas price, transaction patterns, etc.
        return true;
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    // ===== ADMIN FUNCTIONS =====

    /**
     * @title Emergency Pause
     * @dev Pauses the entire system in case of emergency
     */
    function emergencyPause() external onlyOwner {
        systemPaused = true;
    }

    /**
     * @title Resume System
     * @dev Resumes system operations after pause
     */
    function resumeSystem() external onlyOwner {
        systemPaused = false;
    }

    /**
     * @title Add Moderator
     * @dev Adds a new moderator to the system
     * @param _moderator Address to grant moderator privileges
     */
    function addModerator(address _moderator) external onlyOwner {
        moderators[_moderator] = true;
    }

    /**
     * @title Remove Moderator
     * @dev Removes moderator privileges from an address
     * @param _moderator Address to remove moderator privileges from
     */
    function removeModerator(address _moderator) external onlyOwner {
        moderators[_moderator] = false;
    }

    // ===== RECEIVE FUNCTION =====

    /**
     * @dev Allow contract to receive ETH for staking
     */
    receive() external payable {
        // Accept ETH for staking purposes
        if (isRegistered[msg.sender]) {
            userStakes[msg.sender] += msg.value;
            users[msg.sender].stakedAmount += msg.value;
        }
    }
}

/**
 * DEPLOYMENT GUIDE:
 *
 * 1. Deploy with oracle address parameter
 * 2. Register initial users
 * 3. Begin rating interactions
 * 4. Monitor reputation evolution
 *
 * HACKATHON EXTENSIONS:
 * - Multi-platform reputation aggregation
 * - NFT-based reputation certificates
 * - Cross-chain reputation portability
 * - AI-powered reputation analysis
 * - Integration with existing platforms (Uber, Airbnb, etc.)
 *
 * This contract demonstrates advanced Solidity patterns while solving real-world
 * reputation and trust problems in decentralized systems.
 */

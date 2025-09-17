// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title UserRegistry
 * @dev Advanced user management with complex data structures
 *
 * Features:
 * - User registration with unique usernames
 * - Profile management with custom attributes
 * - Reputation and activity tracking
 * - Efficient user enumeration and search
 * - Gas-optimized storage patterns
 */

contract UserRegistry {
    // ======================
    // DATA STRUCTURES
    // ======================

    struct UserProfile {
        string username;
        string displayName;
        string bio;
        string avatarUrl;
        uint256 joinDate;
        uint256 lastActivity;
        uint256 reputation;
        bool isActive;
        mapping(string => string) customAttributes; // key => value
        mapping(string => uint256) numericAttributes; // key => value
    }

    struct UserStats {
        uint256 postsCount;
        uint256 commentsCount;
        uint256 likesReceived;
        uint256 likesGiven;
        uint256 friendsCount;
        uint256 followersCount;
        uint256 followingCount;
    }

    // Packed struct for gas optimization
    struct UserFlags {
        bool isVerified;
        bool isPrivate;
        bool allowsFriendRequests;
        bool allowsMessages;
        uint8 privacyLevel; // 0-255
        uint16 activityScore; // 0-65535
        uint32 lastLoginTime; // Unix timestamp (fits until 2106)
    }

    // ======================
    // STATE VARIABLES
    // ======================

    // Main data mappings
    mapping(address => UserProfile) public userProfiles;
    mapping(address => UserStats) public userStats;
    mapping(address => UserFlags) public userFlags;

    // Username system
    mapping(string => address) public usernameToAddress;
    mapping(address => string) public addressToUsername;
    mapping(string => bool) public usernameExists;

    // User enumeration
    address[] public allUsers;
    mapping(address => uint256) public userIndices;
    mapping(address => bool) public isRegistered;

    // Activity tracking
    mapping(address => uint256[]) public userActivityTimestamps;
    mapping(uint256 => address[]) public dailyActiveUsers; // day => users

    // Search and filtering
    mapping(string => address[]) public usersByCountry;
    mapping(string => address[]) public usersByInterest;
    mapping(uint256 => address[]) public usersByJoinMonth;

    // Reputation system
    mapping(address => mapping(address => bool)) public hasGivenReputation;
    mapping(address => uint256) public reputationHistory; // cumulative

    // Constants
    uint256 public constant INITIAL_REPUTATION = 100;
    uint256 public constant MAX_BIO_LENGTH = 500;
    uint256 public constant MAX_USERNAME_LENGTH = 32;
    uint256 public constant REPUTATION_DECAY_DAYS = 30;

    // ======================
    // EVENTS
    // ======================

    event UserRegistered(address indexed user, string username);
    event ProfileUpdated(address indexed user, string field);
    event ReputationChanged(
        address indexed user,
        uint256 oldRep,
        uint256 newRep
    );
    event UserDeactivated(address indexed user);
    event UserReactivated(address indexed user);
    event CustomAttributeSet(address indexed user, string key, string value);

    // ======================
    // MODIFIERS
    // ======================

    modifier onlyRegistered() {
        require(isRegistered[msg.sender], "User not registered");
        _;
    }

    modifier validUsername(string memory _username) {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(
            bytes(_username).length <= MAX_USERNAME_LENGTH,
            "Username too long"
        );
        require(!usernameExists[_username], "Username already taken");
        _;
    }

    // ======================
    // USER REGISTRATION
    // ======================

    /**
     * @dev Register a new user with comprehensive data setup
     */
    function registerUser(
        string memory _username,
        string memory _displayName,
        string memory _bio,
        string memory _country
    ) external validUsername(_username) {
        require(!isRegistered[msg.sender], "User already registered");
        require(bytes(_bio).length <= MAX_BIO_LENGTH, "Bio too long");

        address user = msg.sender;

        // Set up username mapping
        usernameToAddress[_username] = user;
        addressToUsername[user] = _username;
        usernameExists[_username] = true;

        // Initialize profile
        userProfiles[user].username = _username;
        userProfiles[user].displayName = _displayName;
        userProfiles[user].bio = _bio;
        userProfiles[user].joinDate = block.timestamp;
        userProfiles[user].lastActivity = block.timestamp;
        userProfiles[user].reputation = INITIAL_REPUTATION;
        userProfiles[user].isActive = true;

        // Initialize stats
        userStats[user] = UserStats({
            postsCount: 0,
            commentsCount: 0,
            likesReceived: 0,
            likesGiven: 0,
            friendsCount: 0,
            followersCount: 0,
            followingCount: 0
        });

        // Initialize flags
        userFlags[user] = UserFlags({
            isVerified: false,
            isPrivate: false,
            allowsFriendRequests: true,
            allowsMessages: true,
            privacyLevel: 1,
            activityScore: 0,
            lastLoginTime: uint32(block.timestamp)
        });

        // Set up enumeration
        userIndices[user] = allUsers.length;
        allUsers.push(user);
        isRegistered[user] = true;

        // Set up categorization
        if (bytes(_country).length > 0) {
            usersByCountry[_country].push(user);
        }

        uint256 joinMonth = (block.timestamp / 30 days);
        usersByJoinMonth[joinMonth].push(user);

        // Track activity
        _recordActivity(user);

        emit UserRegistered(user, _username);
    }

    // ======================
    // PROFILE MANAGEMENT
    // ======================

    /**
     * @dev Update user profile information
     */
    function updateProfile(
        string memory _displayName,
        string memory _bio,
        string memory _avatarUrl
    ) external onlyRegistered {
        require(bytes(_bio).length <= MAX_BIO_LENGTH, "Bio too long");

        UserProfile storage profile = userProfiles[msg.sender];
        profile.displayName = _displayName;
        profile.bio = _bio;
        profile.avatarUrl = _avatarUrl;
        profile.lastActivity = block.timestamp;

        _recordActivity(msg.sender);
        emit ProfileUpdated(msg.sender, "profile");
    }

    /**
     * @dev Set custom string attribute
     */
    function setCustomAttribute(
        string memory _key,
        string memory _value
    ) external onlyRegistered {
        userProfiles[msg.sender].customAttributes[_key] = _value;
        userProfiles[msg.sender].lastActivity = block.timestamp;

        // Add to interest mapping if it's an interest
        if (keccak256(bytes(_key)) == keccak256(bytes("interest"))) {
            usersByInterest[_value].push(msg.sender);
        }

        _recordActivity(msg.sender);
        emit CustomAttributeSet(msg.sender, _key, _value);
    }

    /**
     * @dev Set custom numeric attribute
     */
    function setNumericAttribute(
        string memory _key,
        uint256 _value
    ) external onlyRegistered {
        userProfiles[msg.sender].numericAttributes[_key] = _value;
        userProfiles[msg.sender].lastActivity = block.timestamp;

        _recordActivity(msg.sender);
        emit ProfileUpdated(msg.sender, _key);
    }

    /**
     * @dev Update user flags and privacy settings
     */
    function updateUserFlags(
        bool _isPrivate,
        bool _allowsFriendRequests,
        bool _allowsMessages,
        uint8 _privacyLevel
    ) external onlyRegistered {
        UserFlags storage flags = userFlags[msg.sender];
        flags.isPrivate = _isPrivate;
        flags.allowsFriendRequests = _allowsFriendRequests;
        flags.allowsMessages = _allowsMessages;
        flags.privacyLevel = _privacyLevel;
        flags.lastLoginTime = uint32(block.timestamp);

        _recordActivity(msg.sender);
        emit ProfileUpdated(msg.sender, "flags");
    }

    // ======================
    // REPUTATION SYSTEM
    // ======================

    /**
     * @dev Give reputation to another user
     */
    function giveReputation(
        address _user,
        uint256 _amount
    ) external onlyRegistered {
        require(isRegistered[_user], "Target user not registered");
        require(_user != msg.sender, "Cannot give reputation to yourself");
        require(
            !hasGivenReputation[msg.sender][_user],
            "Already gave reputation"
        );
        require(_amount > 0 && _amount <= 10, "Invalid reputation amount");

        hasGivenReputation[msg.sender][_user] = true;

        uint256 oldRep = userProfiles[_user].reputation;
        userProfiles[_user].reputation += _amount;
        reputationHistory[_user] += _amount;

        userStats[_user].likesReceived++;
        userStats[msg.sender].likesGiven++;

        _recordActivity(msg.sender);
        _recordActivity(_user);

        emit ReputationChanged(_user, oldRep, userProfiles[_user].reputation);
    }

    /**
     * @dev Calculate decayed reputation based on activity
     */
    function calculateCurrentReputation(
        address _user
    ) public view returns (uint256) {
        if (!isRegistered[_user]) return 0;

        UserProfile storage profile = userProfiles[_user];
        uint256 daysSinceActivity = (block.timestamp - profile.lastActivity) /
            1 days;

        if (daysSinceActivity <= REPUTATION_DECAY_DAYS) {
            return profile.reputation;
        }

        // Linear decay after inactivity period
        uint256 decayAmount = (daysSinceActivity - REPUTATION_DECAY_DAYS) * 2;
        if (decayAmount >= profile.reputation) {
            return INITIAL_REPUTATION / 2; // Minimum reputation
        }

        return profile.reputation - decayAmount;
    }

    // ======================
    // ACTIVITY TRACKING
    // ======================

    /**
     * @dev Record user activity (internal)
     */
    function _recordActivity(address _user) internal {
        userProfiles[_user].lastActivity = block.timestamp;
        userActivityTimestamps[_user].push(block.timestamp);

        // Track daily active users
        uint256 today = block.timestamp / 1 days;
        dailyActiveUsers[today].push(_user);

        // Update activity score
        UserFlags storage flags = userFlags[_user];
        if (flags.activityScore < 65535) {
            flags.activityScore++;
        }
    }

    /**
     * @dev Update user stats (called by other contracts)
     */
    function updateUserStats(
        address _user,
        string memory _action,
        uint256 _amount
    ) external {
        require(isRegistered[_user], "User not registered");

        UserStats storage stats = userStats[_user];

        if (keccak256(bytes(_action)) == keccak256(bytes("post"))) {
            stats.postsCount += _amount;
        } else if (keccak256(bytes(_action)) == keccak256(bytes("comment"))) {
            stats.commentsCount += _amount;
        } else if (keccak256(bytes(_action)) == keccak256(bytes("friend"))) {
            stats.friendsCount += _amount;
        } else if (keccak256(bytes(_action)) == keccak256(bytes("follower"))) {
            stats.followersCount += _amount;
        } else if (keccak256(bytes(_action)) == keccak256(bytes("following"))) {
            stats.followingCount += _amount;
        }

        _recordActivity(_user);
    }

    // ======================
    // USER QUERIES
    // ======================

    /**
     * @dev Get complete user profile
     */
    function getUserProfile(
        address _user
    )
        external
        view
        returns (
            string memory username,
            string memory displayName,
            string memory bio,
            string memory avatarUrl,
            uint256 joinDate,
            uint256 lastActivity,
            uint256 reputation,
            bool isActive
        )
    {
        UserProfile storage profile = userProfiles[_user];
        return (
            profile.username,
            profile.displayName,
            profile.bio,
            profile.avatarUrl,
            profile.joinDate,
            profile.lastActivity,
            profile.reputation,
            profile.isActive
        );
    }

    /**
     * @dev Get user statistics
     */
    function getUserStats(
        address _user
    ) external view returns (UserStats memory) {
        return userStats[_user];
    }

    /**
     * @dev Get user flags
     */
    function getUserFlags(
        address _user
    ) external view returns (UserFlags memory) {
        return userFlags[_user];
    }

    /**
     * @dev Get custom attribute
     */
    function getCustomAttribute(
        address _user,
        string memory _key
    ) external view returns (string memory) {
        return userProfiles[_user].customAttributes[_key];
    }

    /**
     * @dev Get numeric attribute
     */
    function getNumericAttribute(
        address _user,
        string memory _key
    ) external view returns (uint256) {
        return userProfiles[_user].numericAttributes[_key];
    }

    // ======================
    // USER ENUMERATION
    // ======================

    /**
     * @dev Get users with pagination
     */
    function getUsers(
        uint256 _start,
        uint256 _limit
    )
        external
        view
        returns (
            address[] memory users,
            string[] memory usernames,
            bool hasMore
        )
    {
        require(_start < allUsers.length, "Start index out of bounds");

        uint256 end = _start + _limit;
        if (end > allUsers.length) {
            end = allUsers.length;
        }

        uint256 length = end - _start;
        users = new address[](length);
        usernames = new string[](length);

        for (uint256 i = 0; i < length; i++) {
            address user = allUsers[_start + i];
            users[i] = user;
            usernames[i] = userProfiles[user].username;
        }

        hasMore = end < allUsers.length;
    }

    /**
     * @dev Get users by country
     */
    function getUsersByCountry(
        string memory _country
    ) external view returns (address[] memory) {
        return usersByCountry[_country];
    }

    /**
     * @dev Get users by interest
     */
    function getUsersByInterest(
        string memory _interest
    ) external view returns (address[] memory) {
        return usersByInterest[_interest];
    }

    /**
     * @dev Get daily active users
     */
    function getDailyActiveUsers(
        uint256 _day
    ) external view returns (address[] memory) {
        return dailyActiveUsers[_day];
    }

    /**
     * @dev Search users by reputation range
     */
    function getUsersByReputationRange(
        uint256 _minRep,
        uint256 _maxRep,
        uint256 _limit
    ) external view returns (address[] memory matchedUsers) {
        address[] memory tempUsers = new address[](allUsers.length);
        uint256 count = 0;

        for (uint256 i = 0; i < allUsers.length && count < _limit; i++) {
            address user = allUsers[i];
            uint256 reputation = calculateCurrentReputation(user);

            if (reputation >= _minRep && reputation <= _maxRep) {
                tempUsers[count] = user;
                count++;
            }
        }

        matchedUsers = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            matchedUsers[i] = tempUsers[i];
        }
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    /**
     * @dev Verify a user (admin function)
     */
    function verifyUser(address _user) external {
        // Add proper access control in production
        require(isRegistered[_user], "User not registered");
        userFlags[_user].isVerified = true;
        emit ProfileUpdated(_user, "verified");
    }

    /**
     * @dev Deactivate a user
     */
    function deactivateUser(address _user) external {
        require(isRegistered[_user], "User not registered");
        userProfiles[_user].isActive = false;
        emit UserDeactivated(_user);
    }

    /**
     * @dev Reactivate a user
     */
    function reactivateUser(address _user) external {
        require(isRegistered[_user], "User not registered");
        userProfiles[_user].isActive = true;
        _recordActivity(_user);
        emit UserReactivated(_user);
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    function getTotalUsers() external view returns (uint256) {
        return allUsers.length;
    }

    function getUserByUsername(
        string memory _username
    ) external view returns (address) {
        return usernameToAddress[_username];
    }

    function isUsernameAvailable(
        string memory _username
    ) external view returns (bool) {
        return !usernameExists[_username];
    }
}

/**
 *  KEY LEARNING POINTS:
 *
 * 1. COMPLEX DATA STRUCTURES:
 *    - Nested mappings for user attributes
 *    - Packed structs for gas optimization
 *    - Arrays for enumeration and search
 *    - Multiple indexing strategies
 *
 * 2. GAS OPTIMIZATION:
 *    - Packed structs reduce storage slots
 *    - Efficient data access patterns
 *    - Batch operations where possible
 *    - Strategic use of memory vs storage
 *
 * 3. ENUMERATION PATTERNS:
 *    - Index mappings for O(1) access
 *    - Category-based organization
 *    - Pagination for large datasets
 *    - Search and filtering capabilities
 *
 * 4. REAL-WORLD FEATURES:
 *    - Reputation system with decay
 *    - Activity tracking and analytics
 *    - Privacy controls and permissions
 *    - User verification system
 *
 *  PRODUCTION CONSIDERATIONS:
 * - Add proper access controls
 * - Implement upgrade patterns
 * - Consider off-chain indexing
 * - Optimize for your specific use case
 */

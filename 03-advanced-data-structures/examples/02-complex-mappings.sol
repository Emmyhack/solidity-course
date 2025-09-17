// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Complex Mapping Patterns
 * @dev Advanced mapping techniques and data structures
 *
 * This contract demonstrates:
 * - Nested mappings and complex key structures
 * - Iterable mappings with key enumeration
 * - Reverse mappings and bidirectional lookups
 * - Mapping with struct values and complex data
 * - Efficient data access patterns
 * - Gas-optimized mapping operations
 */

contract ComplexMappings {
    // ======================
    // BASIC MAPPING PATTERNS
    // ======================

    // Simple mappings
    mapping(address => uint256) public balances;
    mapping(address => bool) public isWhitelisted;
    mapping(uint256 => string) public tokenURIs;

    // Nested mappings
    mapping(address => mapping(address => uint256)) public allowances; // ERC20 style
    mapping(address => mapping(uint256 => bool)) public userTokens; // user => tokenId => owns
    mapping(uint256 => mapping(string => uint256)) public gameStats; // gameId => statName => value

    // Triple nested mapping
    mapping(address => mapping(uint256 => mapping(address => uint256)))
        public gamePlayerStats;

    // ======================
    // STRUCT-BASED MAPPINGS
    // ======================

    struct User {
        string name;
        uint256 joinDate;
        uint256[] ownedTokens;
        mapping(string => uint256) attributes;
        mapping(address => bool) friends;
        bool isActive;
    }

    struct Token {
        string name;
        string symbol;
        address owner;
        uint256 mintDate;
        mapping(string => string) metadata;
        uint256[] transferHistory;
    }

    struct Game {
        string name;
        address creator;
        uint256 startTime;
        uint256 endTime;
        mapping(address => bool) players;
        mapping(address => uint256) scores;
        address[] playerList; // For iteration
        bool isActive;
    }

    // Mappings with struct values
    mapping(address => User) public users;
    mapping(uint256 => Token) public tokens;
    mapping(uint256 => Game) public games;

    // ======================
    // ITERABLE MAPPINGS
    // ======================

    // Address enumeration
    address[] public allUsers;
    mapping(address => uint256) public userIndices; // address => index in allUsers
    mapping(address => bool) public userExists;

    // Token enumeration
    uint256[] public allTokenIds;
    mapping(uint256 => uint256) public tokenIndices;
    mapping(uint256 => bool) public tokenExists;

    // Game enumeration
    uint256[] public allGameIds;
    mapping(uint256 => uint256) public gameIndices;
    uint256 public nextGameId = 1;

    // ======================
    // REVERSE MAPPINGS
    // ======================

    // Bidirectional username system
    mapping(address => string) public addressToUsername;
    mapping(string => address) public usernameToAddress;
    mapping(string => bool) public usernameExists;

    // Token ownership reverse lookup
    mapping(address => uint256[]) public ownerToTokens;
    mapping(uint256 => address) public tokenToOwner;

    // Category system with reverse lookup
    mapping(uint256 => string) public tokenToCategory;
    mapping(string => uint256[]) public categoryToTokens;

    // ======================
    // EVENTS
    // ======================

    event UserRegistered(address indexed user, string username);
    event TokenMinted(uint256 indexed tokenId, address indexed owner);
    event GameCreated(uint256 indexed gameId, address indexed creator);
    event UserAttributeSet(
        address indexed user,
        string attribute,
        uint256 value
    );
    event TokenTransferred(
        uint256 indexed tokenId,
        address indexed from,
        address indexed to
    );

    // ======================
    // USER MANAGEMENT
    // ======================

    /**
     * @dev Register a new user with username
     */
    function registerUser(string memory _username) public {
        require(bytes(_username).length > 0, "Username cannot be empty");
        require(!usernameExists[_username], "Username already taken");
        require(
            bytes(addressToUsername[msg.sender]).length == 0,
            "User already registered"
        );

        // Set up bidirectional mapping
        addressToUsername[msg.sender] = _username;
        usernameToAddress[_username] = msg.sender;
        usernameExists[_username] = true;

        // Set up iterable mapping
        if (!userExists[msg.sender]) {
            userIndices[msg.sender] = allUsers.length;
            allUsers.push(msg.sender);
            userExists[msg.sender] = true;
        }

        // Initialize user struct
        users[msg.sender].name = _username;
        users[msg.sender].joinDate = block.timestamp;
        users[msg.sender].isActive = true;

        emit UserRegistered(msg.sender, _username);
    }

    /**
     * @dev Set user attribute
     */
    function setUserAttribute(string memory _attribute, uint256 _value) public {
        require(userExists[msg.sender], "User not registered");

        users[msg.sender].attributes[_attribute] = _value;
        emit UserAttributeSet(msg.sender, _attribute, _value);
    }

    /**
     * @dev Get user attribute
     */
    function getUserAttribute(
        address _user,
        string memory _attribute
    ) public view returns (uint256) {
        return users[_user].attributes[_attribute];
    }

    /**
     * @dev Add friend relationship
     */
    function addFriend(address _friend) public {
        require(userExists[msg.sender], "User not registered");
        require(userExists[_friend], "Friend not registered");
        require(_friend != msg.sender, "Cannot add yourself as friend");

        users[msg.sender].friends[_friend] = true;
        users[_friend].friends[msg.sender] = true; // Bidirectional friendship
    }

    /**
     * @dev Check if two users are friends
     */
    function areFriends(
        address _user1,
        address _user2
    ) public view returns (bool) {
        return users[_user1].friends[_user2];
    }

    // ======================
    // TOKEN MANAGEMENT
    // ======================

    /**
     * @dev Mint a new token
     */
    function mintToken(
        string memory _name,
        string memory _symbol,
        string memory _category
    ) public returns (uint256 tokenId) {
        require(userExists[msg.sender], "User not registered");

        tokenId = allTokenIds.length + 1;

        // Set up token data
        tokens[tokenId].name = _name;
        tokens[tokenId].symbol = _symbol;
        tokens[tokenId].owner = msg.sender;
        tokens[tokenId].mintDate = block.timestamp;

        // Set up iterable mapping
        tokenIndices[tokenId] = allTokenIds.length;
        allTokenIds.push(tokenId);
        tokenExists[tokenId] = true;

        // Set up ownership mappings
        tokenToOwner[tokenId] = msg.sender;
        ownerToTokens[msg.sender].push(tokenId);
        users[msg.sender].ownedTokens.push(tokenId);

        // Set up category mapping
        tokenToCategory[tokenId] = _category;
        categoryToTokens[_category].push(tokenId);

        emit TokenMinted(tokenId, msg.sender);
    }

    /**
     * @dev Transfer token (with all mapping updates)
     */
    function transferToken(uint256 _tokenId, address _to) public {
        require(tokenExists[_tokenId], "Token does not exist");
        require(tokenToOwner[_tokenId] == msg.sender, "Not token owner");
        require(userExists[_to], "Recipient not registered");
        require(_to != msg.sender, "Cannot transfer to yourself");

        address from = msg.sender;

        // Update token ownership
        tokens[_tokenId].owner = _to;
        tokenToOwner[_tokenId] = _to;

        // Update owner arrays
        _removeTokenFromOwner(from, _tokenId);
        ownerToTokens[_to].push(_tokenId);

        // Update user structs
        _removeTokenFromUserStruct(from, _tokenId);
        users[_to].ownedTokens.push(_tokenId);

        // Record transfer in history
        tokens[_tokenId].transferHistory.push(block.timestamp);

        emit TokenTransferred(_tokenId, from, _to);
    }

    /**
     * @dev Set token metadata
     */
    function setTokenMetadata(
        uint256 _tokenId,
        string memory _key,
        string memory _value
    ) public {
        require(tokenExists[_tokenId], "Token does not exist");
        require(tokenToOwner[_tokenId] == msg.sender, "Not token owner");

        tokens[_tokenId].metadata[_key] = _value;
    }

    /**
     * @dev Get token metadata
     */
    function getTokenMetadata(
        uint256 _tokenId,
        string memory _key
    ) public view returns (string memory) {
        return tokens[_tokenId].metadata[_key];
    }

    // ======================
    // GAME MANAGEMENT
    // ======================

    /**
     * @dev Create a new game
     */
    function createGame(
        string memory _name,
        uint256 _duration
    ) public returns (uint256 gameId) {
        require(userExists[msg.sender], "User not registered");

        gameId = nextGameId++;

        games[gameId].name = _name;
        games[gameId].creator = msg.sender;
        games[gameId].startTime = block.timestamp;
        games[gameId].endTime = block.timestamp + _duration;
        games[gameId].isActive = true;

        // Set up iterable mapping
        gameIndices[gameId] = allGameIds.length;
        allGameIds.push(gameId);

        emit GameCreated(gameId, msg.sender);
    }

    /**
     * @dev Join a game
     */
    function joinGame(uint256 _gameId) public {
        require(userExists[msg.sender], "User not registered");
        require(_gameId < nextGameId && _gameId > 0, "Game does not exist");
        require(games[_gameId].isActive, "Game is not active");
        require(block.timestamp <= games[_gameId].endTime, "Game has ended");
        require(!games[_gameId].players[msg.sender], "Already joined game");

        games[_gameId].players[msg.sender] = true;
        games[_gameId].playerList.push(msg.sender);
        games[_gameId].scores[msg.sender] = 0; // Initialize score
    }

    /**
     * @dev Set player score in game
     */
    function setGameScore(
        uint256 _gameId,
        address _player,
        uint256 _score
    ) public {
        require(
            games[_gameId].creator == msg.sender,
            "Only game creator can set scores"
        );
        require(games[_gameId].players[_player], "Player not in game");

        games[_gameId].scores[_player] = _score;
        gamePlayerStats[msg.sender][_gameId][_player] = _score; // Triple nested example
    }

    // ======================
    // ENUMERATION FUNCTIONS
    // ======================

    /**
     * @dev Get all users with pagination
     */
    function getAllUsers(
        uint256 _start,
        uint256 _limit
    ) public view returns (address[] memory userList, bool hasMore) {
        require(_start < allUsers.length, "Start index out of bounds");

        uint256 end = _start + _limit;
        if (end > allUsers.length) {
            end = allUsers.length;
        }

        userList = new address[](end - _start);
        for (uint256 i = _start; i < end; i++) {
            userList[i - _start] = allUsers[i];
        }

        hasMore = end < allUsers.length;
    }

    /**
     * @dev Get tokens owned by user
     */
    function getUserTokens(
        address _user
    ) public view returns (uint256[] memory) {
        return ownerToTokens[_user];
    }

    /**
     * @dev Get tokens in category
     */
    function getTokensByCategory(
        string memory _category
    ) public view returns (uint256[] memory) {
        return categoryToTokens[_category];
    }

    /**
     * @dev Get game players
     */
    function getGamePlayers(
        uint256 _gameId
    ) public view returns (address[] memory) {
        return games[_gameId].playerList;
    }

    /**
     * @dev Get game leaderboard
     */
    function getGameLeaderboard(
        uint256 _gameId
    ) public view returns (address[] memory players, uint256[] memory scores) {
        address[] memory playerList = games[_gameId].playerList;
        players = new address[](playerList.length);
        scores = new uint256[](playerList.length);

        for (uint256 i = 0; i < playerList.length; i++) {
            players[i] = playerList[i];
            scores[i] = games[_gameId].scores[playerList[i]];
        }
    }

    // ======================
    // INTERNAL HELPER FUNCTIONS
    // ======================

    /**
     * @dev Remove token from owner's array
     */
    function _removeTokenFromOwner(address _owner, uint256 _tokenId) internal {
        uint256[] storage tokens = ownerToTokens[_owner];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == _tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }

    /**
     * @dev Remove token from user struct
     */
    function _removeTokenFromUserStruct(
        address _user,
        uint256 _tokenId
    ) internal {
        uint256[] storage tokens = users[_user].ownedTokens;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == _tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }

    // ======================
    // ADVANCED QUERIES
    // ======================

    /**
     * @dev Complex query: Get mutual friends
     */
    function getMutualFriends(
        address _user1,
        address _user2
    ) public view returns (address[] memory mutualFriends) {
        // This is expensive - consider off-chain processing for production
        address[] memory tempFriends = new address[](allUsers.length);
        uint256 count = 0;

        for (uint256 i = 0; i < allUsers.length; i++) {
            address user = allUsers[i];
            if (users[_user1].friends[user] && users[_user2].friends[user]) {
                tempFriends[count] = user;
                count++;
            }
        }

        mutualFriends = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            mutualFriends[i] = tempFriends[i];
        }
    }

    /**
     * @dev Get user statistics
     */
    function getUserStats(
        address _user
    )
        public
        view
        returns (
            string memory username,
            uint256 joinDate,
            uint256 tokenCount,
            uint256 friendCount,
            bool isActive
        )
    {
        username = users[_user].name;
        joinDate = users[_user].joinDate;
        tokenCount = ownerToTokens[_user].length;
        isActive = users[_user].isActive;

        // Count friends (expensive operation)
        uint256 friends = 0;
        for (uint256 i = 0; i < allUsers.length; i++) {
            if (users[_user].friends[allUsers[i]]) {
                friends++;
            }
        }
        friendCount = friends;
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    function getTotalCounts()
        public
        view
        returns (uint256 totalUsers, uint256 totalTokens, uint256 totalGames)
    {
        return (allUsers.length, allTokenIds.length, allGameIds.length);
    }

    function isValidUser(address _user) public view returns (bool) {
        return userExists[_user];
    }

    function getUsernameByAddress(
        address _user
    ) public view returns (string memory) {
        return addressToUsername[_user];
    }

    function getAddressByUsername(
        string memory _username
    ) public view returns (address) {
        return usernameToAddress[_username];
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. MAPPING TYPES:
 *    - Simple: address => uint256
 *    - Nested: address => mapping(uint256 => bool)
 *    - Struct values: address => User struct
 *    - Complex keys: bytes32, strings (expensive)
 *
 * 2. ITERABLE MAPPINGS:
 *    - Arrays store keys for enumeration
 *    - Index mappings for O(1) removal
 *    - Existence mappings for validation
 *    - Pagination for large datasets
 *
 * 3. REVERSE MAPPINGS:
 *    - Bidirectional lookups
 *    - Category systems
 *    - Ownership tracking
 *    - Relationship management
 *
 * 4. GAS CONSIDERATIONS:
 *    - Nested mappings are expensive to iterate
 *    - Struct mappings cost more gas
 *    - Array maintenance has overhead
 *    - Complex queries should be off-chain
 *
 * 5. PATTERNS:
 *    - Existence flags prevent duplicates
 *    - Index mappings enable efficient removal
 *    - Reverse mappings enable bidirectional lookup
 *    - Pagination handles large datasets
 *
 * ⚠️ WARNINGS:
 * - Mappings can't be iterated natively
 * - Deletion doesn't reduce gas costs
 * - Nested loops can cause out-of-gas
 * - Large structs increase costs significantly
 *
 * 🚀 TRY THIS:
 * 1. Build your own iterable mapping
 * 2. Implement complex relationship systems
 * 3. Compare gas costs of different patterns
 * 4. Build efficient query systems
 */

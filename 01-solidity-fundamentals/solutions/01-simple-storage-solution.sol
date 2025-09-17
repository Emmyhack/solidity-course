// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Simple Storage Solution
 * @dev Complete solution for the Simple Storage project
 *
 * This contract demonstrates:
 * - Access control with owner and authorized users
 * - Data storage for different types
 * - Event emission for all state changes
 * - Input validation with meaningful errors
 * - Best practices for Solidity development
 */

contract SimpleStorage {
    // ======================
    // STATE VARIABLES
    // ======================

    address public owner;
    uint256 public storedNumber;
    string public storedText;

    // Mapping to track authorized users
    mapping(address => bool) public authorizedUsers;

    // Mapping to store user data
    mapping(address => UserData) public userData;

    // User data structure
    struct UserData {
        string name;
        uint256 age;
        bool exists;
    }

    // ======================
    // EVENTS
    // ======================

    event NumberStored(uint256 number, address indexed storedBy);
    event TextStored(string text, address indexed storedBy);
    event UserDataStored(address indexed user, string name, uint256 age);
    event UserAuthorized(address indexed user, address indexed authorizedBy);
    event UserDeauthorized(
        address indexed user,
        address indexed deauthorizedBy
    );

    // ======================
    // MODIFIERS
    // ======================

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAuthorized() {
        require(
            authorizedUsers[msg.sender] || msg.sender == owner,
            "Only authorized users can call this function"
        );
        _;
    }

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor() {
        owner = msg.sender;
        authorizedUsers[msg.sender] = true; // Owner is automatically authorized
        emit UserAuthorized(msg.sender, msg.sender);
    }

    // ======================
    // STORAGE FUNCTIONS
    // ======================

    /**
     * @dev Store a number (authorized users only)
     * @param _number The number to store
     */
    function storeNumber(uint256 _number) public onlyAuthorized {
        storedNumber = _number;
        emit NumberStored(_number, msg.sender);
    }

    /**
     * @dev Store text (authorized users only)
     * @param _text The text to store
     */
    function storeText(string memory _text) public onlyAuthorized {
        require(bytes(_text).length > 0, "Text cannot be empty");
        require(
            bytes(_text).length <= 100,
            "Text too long (max 100 characters)"
        );

        storedText = _text;
        emit TextStored(_text, msg.sender);
    }

    /**
     * @dev Store user data (authorized users only)
     * @param _name User's name
     * @param _age User's age
     */
    function storeUserData(
        string memory _name,
        uint256 _age
    ) public onlyAuthorized {
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(bytes(_name).length <= 50, "Name too long (max 50 characters)");
        require(_age > 0 && _age <= 150, "Age must be between 1 and 150");

        userData[msg.sender] = UserData({name: _name, age: _age, exists: true});

        emit UserDataStored(msg.sender, _name, _age);
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Get the stored number
     * @return The stored number
     */
    function getNumber() public view returns (uint256) {
        return storedNumber;
    }

    /**
     * @dev Get the stored text
     * @return The stored text
     */
    function getText() public view returns (string memory) {
        return storedText;
    }

    /**
     * @dev Get user data for a specific address
     * @param _user The user's address
     * @return name The user's name
     * @return age The user's age
     */
    function getUserData(
        address _user
    ) public view returns (string memory name, uint256 age) {
        require(userData[_user].exists, "User data not found");
        UserData memory user = userData[_user];
        return (user.name, user.age);
    }

    /**
     * @dev Check if an address is authorized
     * @param _user The address to check
     * @return True if authorized, false otherwise
     */
    function isAuthorized(address _user) public view returns (bool) {
        return authorizedUsers[_user];
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    /**
     * @dev Add an authorized user (owner only)
     * @param _user The address to authorize
     */
    function addAuthorizedUser(address _user) public onlyOwner {
        require(_user != address(0), "Cannot authorize zero address");
        require(!authorizedUsers[_user], "User already authorized");

        authorizedUsers[_user] = true;
        emit UserAuthorized(_user, msg.sender);
    }

    /**
     * @dev Remove an authorized user (owner only)
     * @param _user The address to deauthorize
     */
    function removeAuthorizedUser(address _user) public onlyOwner {
        require(_user != address(0), "Cannot deauthorize zero address");
        require(_user != owner, "Cannot deauthorize owner");
        require(authorizedUsers[_user], "User not authorized");

        authorizedUsers[_user] = false;
        emit UserDeauthorized(_user, msg.sender);
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    /**
     * @dev Get comprehensive contract information
     * @return contractOwner The contract owner
     * @return currentNumber The stored number
     * @return currentText The stored text
     * @return callerAuthorized Whether the caller is authorized
     */
    function getContractInfo()
        public
        view
        returns (
            address contractOwner,
            uint256 currentNumber,
            string memory currentText,
            bool callerAuthorized
        )
    {
        return (owner, storedNumber, storedText, authorizedUsers[msg.sender]);
    }

    /**
     * @dev Check if caller has user data stored
     * @return True if user data exists for caller
     */
    function hasUserData() public view returns (bool) {
        return userData[msg.sender].exists;
    }
}

/**
 * 🧠 SOLUTION LEARNING POINTS:
 *
 * 1. ACCESS CONTROL:
 *    - Owner has special privileges
 *    - Authorized users can store data
 *    - Modifiers make code cleaner and reusable
 *
 * 2. INPUT VALIDATION:
 *    - Check for empty strings
 *    - Validate age ranges
 *    - Prevent zero address operations
 *    - Meaningful error messages
 *
 * 3. EVENT EMISSION:
 *    - Events for all state changes
 *    - Indexed parameters for efficient filtering
 *    - Include relevant context (who did what)
 *
 * 4. DATA ORGANIZATION:
 *    - Structs group related data
 *    - Mappings for efficient lookups
 *    - Exists flags to check data presence
 *
 * 5. BEST PRACTICES:
 *    - Clear function documentation
 *    - Logical function grouping
 *    - Consistent naming conventions
 *    - Proper error handling
 *
 * 🚀 WHAT'S NEXT:
 * - Try the bonus challenges
 * - Optimize for gas usage
 * - Add more sophisticated access control
 * - Consider upgradeability patterns
 */

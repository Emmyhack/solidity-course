# Your First Smart Contract - From Zero to Blockchain Developer

🎯 **Goal**: Write, understand, and deploy your very first smart contract that could actually be used in the real world.

## 🌟 What We're Building: A Digital Reputation System

Instead of a simple "Hello World," we're building something **actually useful** - a reputation system like the ones used by:

- **Uber/Lyft**: Driver and passenger ratings
- **Airbnb**: Host and guest reviews
- **Freelance platforms**: Contractor reputation scores
- **E-commerce**: Seller trustworthiness ratings

**Why this matters**: Reputation systems power the entire sharing economy ($400B+ market). Understanding how to build trustless reputation systems is a **highly valuable skill** for modern applications.

### **🔥 Real-World Applications**

- **Decentralized marketplaces**: Replace eBay's centralized rating system
- **Professional networks**: LinkedIn-style endorsements that can't be faked
- **Community platforms**: Reddit-style karma that's transparent and portable
- **Service industries**: Uber-style ratings without platform lock-in

## 🛠️ Setting Up Remix IDE (Your Professional Development Environment)

### **Step 1: Access Your Free Cloud IDE**

1. **Navigate to**: [remix.ethereum.org](https://remix.ethereum.org)
2. **Wait for loading**: This is a full development environment running in your browser
3. **Bookmark this page**: You'll use it throughout your blockchain career

**💡 Pro Tip**: Remix is used by professional developers at major blockchain companies. Learning it well gives you immediately transferable skills.

### **Step 2: Create Your Project Structure**

1. **Right-click** on the contracts folder
2. **Select**: "New File"
3. **Name it**: `ReputationSystem.sol`
4. **Verify**: File appears in your workspace

**Why .sol extension?**

- **`.sol`** = Solidity source code file
- **Like `.js`** for JavaScript or **`.py`** for Python
- **Industry standard** for smart contract development

### **Step 3: Understand Your Workspace**

- **📁 Left Panel**: File explorer (like VS Code or IntelliJ)
- **📝 Center Panel**: Code editor with syntax highlighting
- **🔧 Right Panel**: Compilation and deployment tools
- **📊 Bottom Panel**: Console for debugging and testing

## 📝 Writing Your Reputation System - Every Line Explained

### **🔧 Step 1: Contract Header (Legal & Technical Requirements)**

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Digital Reputation System
 * @dev A decentralized reputation tracking system for service providers
 * @notice This contract allows users to rate service providers and build portable reputation
 * @author Your Name - Future Blockchain Developer
 */
```

**🔍 SYNTAX BREAKDOWN:**

#### **Line 1: Legal License Declaration**

```solidity
// SPDX-License-Identifier: MIT
```

- **`//`** = Single-line comment (ignored by computer, read by humans)
- **`SPDX-License-Identifier`** = Software Package Data Exchange license identifier
- **`MIT`** = Most permissive license (free to use, modify, commercialize)
- **Real-World**: Like putting "Copyright © 2024" on your software
- **Why Required**: Ethereum networks require license information for legal compliance

#### **Line 2: Compiler Version**

```solidity
pragma solidity ^0.8.19;
```

- **`pragma`** = Preprocessor directive (instruction for the compiler)
- **`solidity`** = The programming language we're using
- **`^0.8.19`** = Version constraint (use 0.8.19 or newer, but not 0.9.x)
- **`^`** = Caret notation for compatible versions
- **Real-World**: Like saying "this code requires Node.js 18 or newer"
- **Why Important**: Different Solidity versions have different features and security improvements

#### **Lines 4-8: Professional Documentation**

```solidity
/**
 * @title Digital Reputation System
 * @dev A decentralized reputation tracking system for service providers
 * @notice This contract allows users to rate service providers and build portable reputation
 * @author Your Name - Future Blockchain Developer
 */
```

- **`/**`\*\* = Start of multi-line documentation comment
- **`@title`** = Human-readable contract name
- **`@dev`** = Technical description for developers
- **`@notice`** = User-friendly explanation of what the contract does
- **`@author`** = Who created this contract
- **Real-World**: Like the description on a mobile app in the App Store

### **🏗️ Step 2: Contract Declaration & Core Data Structures**

```solidity
contract ReputationSystem {
    // Core contract state will go here
}
```

**🔍 SYNTAX BREAKDOWN:**

#### **Contract Declaration**

```solidity
contract ReputationSystem {
    // Everything between these braces belongs to this contract
}
```

- **`contract`** = Keyword that creates a new smart contract class
- **`ReputationSystem`** = Contract name (like a class name in Java/C++)
- **`{` and `}`** = Contract body delimiters
- **Real-World**: Like creating a new class called "ReputationSystem" in object-oriented programming

### **🗂️ Step 3: Data Storage Architecture**

```solidity
contract ReputationSystem {
    // ===== CONTRACT CONSTANTS =====
    uint8 public constant MIN_RATING = 1;      // Minimum allowed rating
    uint8 public constant MAX_RATING = 5;      // Maximum allowed rating
    uint256 public constant MIN_REVIEWS = 3;   // Minimum reviews for verified status

    // ===== CONTRACT STATE VARIABLES =====
    address public owner;                       // Contract administrator
    uint256 public totalUsers;                 // Total registered users
    uint256 public totalReviews;               // Total reviews submitted

    // ===== USER DATA STRUCTURES =====
    struct UserProfile {
        string name;                    // User's display name
        bool isActive;                  // Account status
        uint256 totalRatings;          // Total number of ratings received
        uint256 ratingSum;             // Sum of all ratings (for average calculation)
        uint256 reviewCount;           // Number of reviews received
        uint256 joinedAt;              // Timestamp when user joined
        bool isVerified;               // Verified status (auto-calculated)
    }

    struct Review {
        address reviewer;               // Who left the review
        address reviewee;              // Who was reviewed
        uint8 rating;                  // Rating from 1-5
        string comment;                // Written review
        uint256 timestamp;             // When review was submitted
        bool isValid;                  // Review validity status
    }

    // ===== MAPPINGS (Our Database) =====
    mapping(address => UserProfile) public users;              // Address to user profile
    mapping(address => bool) public isRegistered;              // Quick registration check
    mapping(uint256 => Review) public reviews;                 // Review ID to review data
    mapping(address => uint256[]) public userReviews;          // User to their review IDs
    mapping(address => mapping(address => bool)) public hasReviewed; // Prevent duplicate reviews

    // ===== ARRAYS FOR ENUMERATION =====
    address[] public registeredUsers;          // List of all users
    uint256 public nextReviewId;               // Auto-incrementing review ID counter
}
```

**🔍 DETAILED SYNTAX BREAKDOWN:**

#### **Constants vs Variables**

```solidity
uint8 public constant MIN_RATING = 1;      // Value never changes
address public owner;                       // Value can change
```

- **`constant`** = Value is fixed at compile time, saves gas, uses UPPER_CASE naming
- **`public`** = Anyone can read this value (creates automatic getter function)
- **No keyword** = Value can be modified throughout contract lifetime
- **Real-World**: MIN_RATING is like a law (never changes), owner is like current president (can change)

#### **Data Types Deep Dive**

```solidity
uint8 public constant MIN_RATING = 1;      // Unsigned integer, 0-255 range
uint256 public totalUsers;                 // Unsigned integer, very large range
address public owner;                      // Ethereum address (20 bytes)
bool isActive;                             // Boolean: true or false
string name;                               // Dynamic text data
```

- **`uint8`** = 8-bit unsigned integer (0 to 255) - perfect for ratings
- **`uint256`** = 256-bit unsigned integer (0 to 2^256-1) - standard for counters
- **`address`** = 20-byte Ethereum address (like 0x742d35Cc6...)
- **`bool`** = Boolean value (true/false)
- **`string`** = Dynamic UTF-8 text data

#### **Struct Definition**

```solidity
struct UserProfile {
    string name;                    // Member variable 1
    bool isActive;                  // Member variable 2
    uint256 totalRatings;          // Member variable 3
    // ... more members
}
```

- **`struct`** = Custom data type that groups related variables
- **Members** = Variables inside the struct
- **Real-World**: Like a form with multiple fields (name, email, phone, etc.)
- **Memory Layout**: All members stored together for efficiency

#### **Mapping Deep Dive**

```solidity
mapping(address => UserProfile) public users;
//      ↑         ↑            ↑
//     Key      Value      Visibility
```

- **`mapping`** = Key-value storage (like HashMap in Java or dict in Python)
- **`address => UserProfile`** = Maps Ethereum addresses to UserProfile structs
- **`public`** = Creates automatic getter function
- **Real-World**: Like a phonebook where address is the name and UserProfile is the info

#### **Nested Mapping**

```solidity
mapping(address => mapping(address => bool)) public hasReviewed;
//              ↑          ↑         ↑
//           User1      User2    Has User1 reviewed User2?
```

- **Nested mappings** = Two-dimensional key-value storage
- **Real-World**: Like a spreadsheet where rows are User1, columns are User2, cells are "has reviewed"

### **🔒 Step 4: Security & Access Control**

```solidity
contract ReputationSystem {
    // Previous code...

    // ===== EVENTS (Blockchain Logging) =====
    event UserRegistered(address indexed user, string name, uint256 timestamp);
    event ReviewSubmitted(address indexed reviewer, address indexed reviewee, uint8 rating, uint256 reviewId);
    event UserVerified(address indexed user, uint256 totalReviews);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ===== CUSTOM ERRORS (Gas Efficient) =====
    error NotOwner();
    error UserNotRegistered();
    error UserAlreadyRegistered();
    error InvalidRating(uint8 provided, uint8 min, uint8 max);
    error CannotReviewSelf();
    error AlreadyReviewed();
    error EmptyName();
    error EmptyComment();

    // ===== SECURITY MODIFIERS =====
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRegistered() {
        if (!isRegistered[msg.sender]) revert UserNotRegistered();
        _;
    }

    modifier validAddress(address _user) {
        require(_user != address(0), "Invalid address");
        _;
    }

    modifier validRating(uint8 _rating) {
        if (_rating < MIN_RATING || _rating > MAX_RATING) {
            revert InvalidRating(_rating, MIN_RATING, MAX_RATING);
        }
        _;
    }

    modifier notSelf(address _target) {
        if (msg.sender == _target) revert CannotReviewSelf();
        _;
    }

    modifier hasNotReviewed(address _reviewee) {
        if (hasReviewed[msg.sender][_reviewee]) revert AlreadyReviewed();
        _;
    }
}
```

**🔍 SECURITY SYNTAX BREAKDOWN:**

#### **Event Declaration**

```solidity
event UserRegistered(
    address indexed user,       // Indexed for efficient filtering
    string name,               // Not indexed (stored in data)
    uint256 timestamp          // Not indexed (stored in data)
);
```

- **`event`** = Declares a loggable event
- **`indexed`** = Makes parameter searchable/filterable (max 3 per event)
- **Real-World**: Like entries in a newspaper's activity log
- **Gas Cost**: Events are much cheaper than storing data in state variables

#### **Custom Errors**

```solidity
error InvalidRating(uint8 provided, uint8 min, uint8 max);
error NotOwner();
```

- **`error`** = Custom error type (more gas efficient than string messages)
- **Parameters** = Can include context data for debugging
- **Real-World**: Like specific error codes (404, 500, etc.) in web development

#### **Modifier Structure**

```solidity
modifier onlyOwner() {
    if (msg.sender != owner) revert NotOwner();    // Security check
    _;                                              // Function body executes here
}
```

- **`modifier`** = Reusable code that runs before/after functions
- **`msg.sender`** = Address of whoever called the function
- **`revert`** = Stops execution and refunds remaining gas
- **`_`** = Placeholder where the actual function body will execute
- **Real-World**: Like security checkpoints before entering restricted areas

#### **Built-in Global Variables**

```solidity
msg.sender          // Address of function caller
msg.value           // Amount of Ether sent with function call
block.timestamp     // Current block timestamp
block.number        // Current block number
tx.origin           // Original transaction sender
```

### **🚀 Step 5: Constructor & Initialization**

```solidity
contract ReputationSystem {
    // Previous code...

    /**
     * @dev Initializes the reputation system
     * @notice Creates a new reputation system with the deployer as owner
     */
    constructor() {
        owner = msg.sender;                     // Set contract deployer as owner
        totalUsers = 0;                         // Initialize user counter
        totalReviews = 0;                       // Initialize review counter
        nextReviewId = 1;                       // Start review IDs at 1

        emit OwnershipTransferred(address(0), owner);   // Log ownership establishment
    }
}
```

**🔍 CONSTRUCTOR SYNTAX BREAKDOWN:**

#### **Constructor Declaration**

```solidity
constructor() {
    // Initialization code that runs exactly once
}
```

- **`constructor`** = Special function that runs only when contract is deployed
- **No parameters** = This constructor doesn't need input (but could have some)
- **Runs once** = Unlike regular functions, constructor only executes during deployment
- **Real-World**: Like the setup that happens when you install a new app

#### **Initialization Patterns**

```solidity
owner = msg.sender;                     // Set deployer as owner
totalUsers = 0;                         // Initialize counter (actually optional, defaults to 0)
emit OwnershipTransferred(address(0), owner);   // Log the initialization
```

- **Setting owner** = Common pattern for access control
- **Initialize counters** = Good practice even though they default to 0
- **Emit events** = Log important initialization events

### **⚙️ Step 6: Core Business Logic Functions**

```solidity
contract ReputationSystem {
    // Previous code...

    /**
     * @dev Register a new user in the system
     * @param _name Display name for the user
     * @notice Allows anyone to create a profile in the reputation system
     */
    function registerUser(string memory _name) public {
        // Input validation
        if (bytes(_name).length == 0) revert EmptyName();
        if (isRegistered[msg.sender]) revert UserAlreadyRegistered();

        // Create user profile
        users[msg.sender] = UserProfile({
            name: _name,
            isActive: true,
            totalRatings: 0,
            ratingSum: 0,
            reviewCount: 0,
            joinedAt: block.timestamp,
            isVerified: false
        });

        // Update global state
        isRegistered[msg.sender] = true;
        registeredUsers.push(msg.sender);
        totalUsers++;

        // Log the registration
        emit UserRegistered(msg.sender, _name, block.timestamp);
    }

    /**
     * @dev Submit a review for another user
     * @param _reviewee Address of user being reviewed
     * @param _rating Rating from 1-5 stars
     * @param _comment Written review comment
     * @notice Allows registered users to rate and review other users
     */
    function submitReview(
        address _reviewee,
        uint8 _rating,
        string memory _comment
    )
        public
        onlyRegistered
        validAddress(_reviewee)
        validRating(_rating)
        notSelf(_reviewee)
        hasNotReviewed(_reviewee)
    {
        // Input validation
        if (!isRegistered[_reviewee]) revert UserNotRegistered();
        if (bytes(_comment).length == 0) revert EmptyComment();

        // Create review
        reviews[nextReviewId] = Review({
            reviewer: msg.sender,
            reviewee: _reviewee,
            rating: _rating,
            comment: _comment,
            timestamp: block.timestamp,
            isValid: true
        });

        // Update reviewer's review list
        userReviews[_reviewee].push(nextReviewId);

        // Update reviewee's statistics
        users[_reviewee].totalRatings += _rating;
        users[_reviewee].ratingSum += _rating;
        users[_reviewee].reviewCount++;

        // Mark as reviewed to prevent duplicates
        hasReviewed[msg.sender][_reviewee] = true;

        // Check if user should be verified
        if (users[_reviewee].reviewCount >= MIN_REVIEWS && !users[_reviewee].isVerified) {
            users[_reviewee].isVerified = true;
            emit UserVerified(_reviewee, users[_reviewee].reviewCount);
        }

        // Update global counters
        totalReviews++;
        nextReviewId++;

        // Log the review
        emit ReviewSubmitted(msg.sender, _reviewee, _rating, nextReviewId - 1);
    }
}
```

**🔍 FUNCTION SYNTAX BREAKDOWN:**

#### **Function Declaration Components**

```solidity
function submitReview(
    address _reviewee,          // Parameter 1
    uint8 _rating,             // Parameter 2
    string memory _comment     // Parameter 3
)
    public                     // Visibility modifier
    onlyRegistered            // Custom modifier 1
    validAddress(_reviewee)   // Custom modifier 2 (with parameter)
    validRating(_rating)      // Custom modifier 3 (with parameter)
    notSelf(_reviewee)        // Custom modifier 4 (with parameter)
    hasNotReviewed(_reviewee) // Custom modifier 5 (with parameter)
{
    // Function body
}
```

#### **Parameter Types and Memory Keywords**

```solidity
address _reviewee,          // Address type, stored in stack
uint8 _rating,             // Small integer, stored in stack
string memory _comment     // Dynamic string, temporary memory storage
```

- **`memory`** = Temporary storage during function execution
- **`storage`** = Permanent blockchain storage (not used for parameters)
- **`calldata`** = Read-only parameter data (more gas efficient for external calls)

#### **Input Validation Patterns**

```solidity
if (bytes(_name).length == 0) revert EmptyName();
if (isRegistered[msg.sender]) revert UserAlreadyRegistered();
```

- **`bytes(_name).length`** = Get byte length of string (more accurate than character count)
- **`revert ErrorName()`** = Stop execution with custom error (gas efficient)
- **Early validation** = Check all conditions before making changes

#### **Struct Initialization**

```solidity
users[msg.sender] = UserProfile({
    name: _name,                    // Named field assignment
    isActive: true,                 // Explicit value
    totalRatings: 0,               // Initialize to zero
    ratingSum: 0,                  // Initialize to zero
    reviewCount: 0,                // Initialize to zero
    joinedAt: block.timestamp,     // Current time
    isVerified: false              // Default state
});
```

- **Named initialization** = Explicitly set each field
- **Order independent** = Can assign fields in any order
- **Type safety** = Compiler ensures all fields are set

### **📊 Step 7: View Functions (Reading Data)**

```solidity
contract ReputationSystem {
    // Previous code...

    /**
     * @dev Get user's reputation score
     * @param _user Address of user to check
     * @return averageRating Average rating out of 5.0 (scaled by 100 for precision)
     * @return reviewCount Number of reviews received
     * @return isVerified Whether user has verified status
     * @notice Returns the reputation metrics for a given user
     */
    function getUserReputation(address _user)
        public
        view
        returns (
            uint256 averageRating,
            uint256 reviewCount,
            bool isVerified
        )
    {
        if (!isRegistered[_user]) {
            return (0, 0, false);
        }

        UserProfile memory profile = users[_user];

        if (profile.reviewCount == 0) {
            return (0, 0, profile.isVerified);
        }

        // Calculate average rating with 2 decimal precision
        // Example: 4.25 stars = 425 (divide by 100 to get 4.25)
        averageRating = (profile.ratingSum * 100) / profile.reviewCount;
        reviewCount = profile.reviewCount;
        isVerified = profile.isVerified;
    }

    /**
     * @dev Get user's basic profile information
     * @param _user Address of user to look up
     * @return name User's display name
     * @return isActive Account status
     * @return joinedAt Timestamp when user registered
     * @return totalReviews Number of reviews user has received
     */
    function getUserProfile(address _user)
        public
        view
        returns (
            string memory name,
            bool isActive,
            uint256 joinedAt,
            uint256 totalReviews
        )
    {
        require(isRegistered[_user], "User not registered");

        UserProfile memory profile = users[_user];
        return (
            profile.name,
            profile.isActive,
            profile.joinedAt,
            profile.reviewCount
        );
    }

    /**
     * @dev Get details of a specific review
     * @param _reviewId ID of the review to fetch
     * @return reviewer Address who submitted the review
     * @return reviewee Address who was reviewed
     * @return rating Rating given (1-5)
     * @return comment Written review text
     * @return timestamp When review was submitted
     */
    function getReview(uint256 _reviewId)
        public
        view
        returns (
            address reviewer,
            address reviewee,
            uint8 rating,
            string memory comment,
            uint256 timestamp
        )
    {
        require(_reviewId < nextReviewId && _reviewId > 0, "Invalid review ID");

        Review memory review = reviews[_reviewId];
        require(review.isValid, "Review not found or invalid");

        return (
            review.reviewer,
            review.reviewee,
            review.rating,
            review.comment,
            review.timestamp
        );
    }

    /**
     * @dev Get all review IDs for a specific user
     * @param _user Address of user whose reviews to fetch
     * @return reviewIds Array of review ID numbers
     * @notice Use this with getReview() to fetch full review details
     */
    function getUserReviews(address _user)
        public
        view
        returns (uint256[] memory reviewIds)
    {
        require(isRegistered[_user], "User not registered");
        return userReviews[_user];
    }

    /**
     * @dev Get system-wide statistics
     * @return totalUsers Number of registered users
     * @return totalReviews Number of reviews submitted
     * @return contractOwner Address of contract administrator
     */
    function getSystemStats()
        public
        view
        returns (
            uint256,
            uint256,
            address contractOwner
        )
    {
        return (totalUsers, totalReviews, owner);
    }
}
```

**🔍 VIEW FUNCTION SYNTAX BREAKDOWN:**

#### **View Function Declaration**

```solidity
function getUserReputation(address _user)
    public                  // Anyone can call
    view                   // Only reads data, doesn't modify state
    returns (              // Specifies return types
        uint256 averageRating,
        uint256 reviewCount,
        bool isVerified
    )
```

- **`view`** = Function only reads blockchain state, doesn't modify it
- **`returns`** = Declares what data types the function returns
- **Named returns** = Return variables are pre-declared and automatically returned

#### **Multiple Return Values**

```solidity
return (
    profile.name,          // string
    profile.isActive,      // bool
    profile.joinedAt,      // uint256
    profile.reviewCount    // uint256
);
```

- **Parentheses** = Group multiple return values
- **Order matters** = Must match the order in `returns` declaration
- **Type safety** = Each value must match declared type

#### **Mathematical Operations**

```solidity
averageRating = (profile.ratingSum * 100) / profile.reviewCount;
```

- **Multiplication first** = Prevents precision loss from integer division
- **`* 100`** = Creates 2 decimal places of precision
- **Example**: 425 represents 4.25 stars
- **Integer math** = Solidity doesn't have floating point numbers

#### **Memory vs Storage for Local Variables**

```solidity
UserProfile memory profile = users[_user];    // Copy to memory (cheaper for reading)
UserProfile storage profile = users[_user];   // Reference to storage (for modifications)
```

- **`memory`** = Creates a copy in temporary memory
- **`storage`** = Creates a reference to blockchain storage
- **Use memory for reading** = More gas efficient
- **Use storage for writing** = Necessary to modify state

### **🛡️ Step 8: Administrative Functions**

```solidity
contract ReputationSystem {
    // Previous code...

    /**
     * @dev Transfer ownership of the contract
     * @param _newOwner Address of new contract owner
     * @notice Only current owner can transfer ownership
     */
    function transferOwnership(address _newOwner)
        public
        onlyOwner
        validAddress(_newOwner)
    {
        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @dev Deactivate a user account (emergency function)
     * @param _user Address of user to deactivate
     * @notice Only owner can deactivate accounts for policy violations
     */
    function deactivateUser(address _user)
        public
        onlyOwner
        validAddress(_user)
    {
        require(isRegistered[_user], "User not registered");
        users[_user].isActive = false;
    }

    /**
     * @dev Reactivate a user account
     * @param _user Address of user to reactivate
     * @notice Only owner can reactivate deactivated accounts
     */
    function reactivateUser(address _user)
        public
        onlyOwner
        validAddress(_user)
    {
        require(isRegistered[_user], "User not registered");
        users[_user].isActive = true;
    }

    /**
     * @dev Emergency function to invalidate a review
     * @param _reviewId ID of review to invalidate
     * @notice Only owner can invalidate reviews for abuse/spam
     */
    function invalidateReview(uint256 _reviewId)
        public
        onlyOwner
    {
        require(_reviewId < nextReviewId && _reviewId > 0, "Invalid review ID");
        require(reviews[_reviewId].isValid, "Review already invalid");

        reviews[_reviewId].isValid = false;

        // Note: We don't recalculate user stats here for gas efficiency
        // In production, you might want to implement a recalculation function
    }
}
```

## 🔥 Complete Reputation System Contract

Here's your complete, production-ready reputation system:

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Digital Reputation System
 * @dev A decentralized reputation tracking system for service providers
 * @notice This contract allows users to rate service providers and build portable reputation
 * @author Your Name - Future Blockchain Developer
 */
contract ReputationSystem {

    // ===== CONTRACT CONSTANTS =====
    uint8 public constant MIN_RATING = 1;      // Minimum allowed rating
    uint8 public constant MAX_RATING = 5;      // Maximum allowed rating
    uint256 public constant MIN_REVIEWS = 3;   // Minimum reviews for verified status

    // ===== CONTRACT STATE VARIABLES =====
    address public owner;                       // Contract administrator
    uint256 public totalUsers;                 // Total registered users
    uint256 public totalReviews;               // Total reviews submitted

    // ===== USER DATA STRUCTURES =====
    struct UserProfile {
        string name;                    // User's display name
        bool isActive;                  // Account status
        uint256 totalRatings;          // Total number of ratings received
        uint256 ratingSum;             // Sum of all ratings (for average calculation)
        uint256 reviewCount;           // Number of reviews received
        uint256 joinedAt;              // Timestamp when user joined
        bool isVerified;               // Verified status (auto-calculated)
    }

    struct Review {
        address reviewer;               // Who left the review
        address reviewee;              // Who was reviewed
        uint8 rating;                  // Rating from 1-5
        string comment;                // Written review
        uint256 timestamp;             // When review was submitted
        bool isValid;                  // Review validity status
    }

    // ===== MAPPINGS (Our Database) =====
    mapping(address => UserProfile) public users;              // Address to user profile
    mapping(address => bool) public isRegistered;              // Quick registration check
    mapping(uint256 => Review) public reviews;                 // Review ID to review data
    mapping(address => uint256[]) public userReviews;          // User to their review IDs
    mapping(address => mapping(address => bool)) public hasReviewed; // Prevent duplicate reviews

    // ===== ARRAYS FOR ENUMERATION =====
    address[] public registeredUsers;          // List of all users
    uint256 public nextReviewId;               // Auto-incrementing review ID counter

    // ===== EVENTS (Blockchain Logging) =====
    event UserRegistered(address indexed user, string name, uint256 timestamp);
    event ReviewSubmitted(address indexed reviewer, address indexed reviewee, uint8 rating, uint256 reviewId);
    event UserVerified(address indexed user, uint256 totalReviews);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ===== CUSTOM ERRORS (Gas Efficient) =====
    error NotOwner();
    error UserNotRegistered();
    error UserAlreadyRegistered();
    error InvalidRating(uint8 provided, uint8 min, uint8 max);
    error CannotReviewSelf();
    error AlreadyReviewed();
    error EmptyName();
    error EmptyComment();

    // ===== SECURITY MODIFIERS =====
    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    modifier onlyRegistered() {
        if (!isRegistered[msg.sender]) revert UserNotRegistered();
        _;
    }

    modifier validAddress(address _user) {
        require(_user != address(0), "Invalid address");
        _;
    }

    modifier validRating(uint8 _rating) {
        if (_rating < MIN_RATING || _rating > MAX_RATING) {
            revert InvalidRating(_rating, MIN_RATING, MAX_RATING);
        }
        _;
    }

    modifier notSelf(address _target) {
        if (msg.sender == _target) revert CannotReviewSelf();
        _;
    }

    modifier hasNotReviewed(address _reviewee) {
        if (hasReviewed[msg.sender][_reviewee]) revert AlreadyReviewed();
        _;
    }

    /**
     * @dev Initializes the reputation system
     * @notice Creates a new reputation system with the deployer as owner
     */
    constructor() {
        owner = msg.sender;                     // Set contract deployer as owner
        totalUsers = 0;                         // Initialize user counter
        totalReviews = 0;                       // Initialize review counter
        nextReviewId = 1;                       // Start review IDs at 1

        emit OwnershipTransferred(address(0), owner);   // Log ownership establishment
    }

    /**
     * @dev Register a new user in the system
     * @param _name Display name for the user
     * @notice Allows anyone to create a profile in the reputation system
     */
    function registerUser(string memory _name) public {
        // Input validation
        if (bytes(_name).length == 0) revert EmptyName();
        if (isRegistered[msg.sender]) revert UserAlreadyRegistered();

        // Create user profile
        users[msg.sender] = UserProfile({
            name: _name,
            isActive: true,
            totalRatings: 0,
            ratingSum: 0,
            reviewCount: 0,
            joinedAt: block.timestamp,
            isVerified: false
        });

        // Update global state
        isRegistered[msg.sender] = true;
        registeredUsers.push(msg.sender);
        totalUsers++;

        // Log the registration
        emit UserRegistered(msg.sender, _name, block.timestamp);
    }

    /**
     * @dev Submit a review for another user
     * @param _reviewee Address of user being reviewed
     * @param _rating Rating from 1-5 stars
     * @param _comment Written review comment
     * @notice Allows registered users to rate and review other users
     */
    function submitReview(
        address _reviewee,
        uint8 _rating,
        string memory _comment
    )
        public
        onlyRegistered
        validAddress(_reviewee)
        validRating(_rating)
        notSelf(_reviewee)
        hasNotReviewed(_reviewee)
    {
        // Input validation
        if (!isRegistered[_reviewee]) revert UserNotRegistered();
        if (bytes(_comment).length == 0) revert EmptyComment();

        // Create review
        reviews[nextReviewId] = Review({
            reviewer: msg.sender,
            reviewee: _reviewee,
            rating: _rating,
            comment: _comment,
            timestamp: block.timestamp,
            isValid: true
        });

        // Update reviewer's review list
        userReviews[_reviewee].push(nextReviewId);

        // Update reviewee's statistics
        users[_reviewee].totalRatings += _rating;
        users[_reviewee].ratingSum += _rating;
        users[_reviewee].reviewCount++;

        // Mark as reviewed to prevent duplicates
        hasReviewed[msg.sender][_reviewee] = true;

        // Check if user should be verified
        if (users[_reviewee].reviewCount >= MIN_REVIEWS && !users[_reviewee].isVerified) {
            users[_reviewee].isVerified = true;
            emit UserVerified(_reviewee, users[_reviewee].reviewCount);
        }

        // Update global counters
        totalReviews++;
        nextReviewId++;

        // Log the review
        emit ReviewSubmitted(msg.sender, _reviewee, _rating, nextReviewId - 1);
    }

    /**
     * @dev Get user's reputation score
     * @param _user Address of user to check
     * @return averageRating Average rating out of 5.0 (scaled by 100 for precision)
     * @return reviewCount Number of reviews received
     * @return isVerified Whether user has verified status
     * @notice Returns the reputation metrics for a given user
     */
    function getUserReputation(address _user)
        public
        view
        returns (
            uint256 averageRating,
            uint256 reviewCount,
            bool isVerified
        )
    {
        if (!isRegistered[_user]) {
            return (0, 0, false);
        }

        UserProfile memory profile = users[_user];

        if (profile.reviewCount == 0) {
            return (0, 0, profile.isVerified);
        }

        // Calculate average rating with 2 decimal precision
        // Example: 4.25 stars = 425 (divide by 100 to get 4.25)
        averageRating = (profile.ratingSum * 100) / profile.reviewCount;
        reviewCount = profile.reviewCount;
        isVerified = profile.isVerified;
    }

    /**
     * @dev Get user's basic profile information
     * @param _user Address of user to look up
     * @return name User's display name
     * @return isActive Account status
     * @return joinedAt Timestamp when user registered
     * @return totalReviews Number of reviews user has received
     */
    function getUserProfile(address _user)
        public
        view
        returns (
            string memory name,
            bool isActive,
            uint256 joinedAt,
            uint256 totalReviews
        )
    {
        require(isRegistered[_user], "User not registered");

        UserProfile memory profile = users[_user];
        return (
            profile.name,
            profile.isActive,
            profile.joinedAt,
            profile.reviewCount
        );
    }

    /**
     * @dev Get details of a specific review
     * @param _reviewId ID of the review to fetch
     * @return reviewer Address who submitted the review
     * @return reviewee Address who was reviewed
     * @return rating Rating given (1-5)
     * @return comment Written review text
     * @return timestamp When review was submitted
     */
    function getReview(uint256 _reviewId)
        public
        view
        returns (
            address reviewer,
            address reviewee,
            uint8 rating,
            string memory comment,
            uint256 timestamp
        )
    {
        require(_reviewId < nextReviewId && _reviewId > 0, "Invalid review ID");

        Review memory review = reviews[_reviewId];
        require(review.isValid, "Review not found or invalid");

        return (
            review.reviewer,
            review.reviewee,
            review.rating,
            review.comment,
            review.timestamp
        );
    }

    /**
     * @dev Get all review IDs for a specific user
     * @param _user Address of user whose reviews to fetch
     * @return reviewIds Array of review ID numbers
     * @notice Use this with getReview() to fetch full review details
     */
    function getUserReviews(address _user)
        public
        view
        returns (uint256[] memory reviewIds)
    {
        require(isRegistered[_user], "User not registered");
        return userReviews[_user];
    }

    /**
     * @dev Get system-wide statistics
     * @return totalUsers Number of registered users
     * @return totalReviews Number of reviews submitted
     * @return contractOwner Address of contract administrator
     */
    function getSystemStats()
        public
        view
        returns (
            uint256,
            uint256,
            address contractOwner
        )
    {
        return (totalUsers, totalReviews, owner);
    }

    /**
     * @dev Transfer ownership of the contract
     * @param _newOwner Address of new contract owner
     * @notice Only current owner can transfer ownership
     */
    function transferOwnership(address _newOwner)
        public
        onlyOwner
        validAddress(_newOwner)
    {
        address previousOwner = owner;
        owner = _newOwner;
        emit OwnershipTransferred(previousOwner, _newOwner);
    }

    /**
     * @dev Deactivate a user account (emergency function)
     * @param _user Address of user to deactivate
     * @notice Only owner can deactivate accounts for policy violations
     */
    function deactivateUser(address _user)
        public
        onlyOwner
        validAddress(_user)
    {
        require(isRegistered[_user], "User not registered");
        users[_user].isActive = false;
    }

    /**
     * @dev Reactivate a user account
     * @param _user Address of user to reactivate
     * @notice Only owner can reactivate deactivated accounts
     */
    function reactivateUser(address _user)
        public
        onlyOwner
        validAddress(_user)
    {
        require(isRegistered[_user], "User not registered");
        users[_user].isActive = true;
    }

    /**
     * @dev Emergency function to invalidate a review
     * @param _reviewId ID of review to invalidate
     * @notice Only owner can invalidate reviews for abuse/spam
     */
    function invalidateReview(uint256 _reviewId)
        public
        onlyOwner
    {
        require(_reviewId < nextReviewId && _reviewId > 0, "Invalid review ID");
        require(reviews[_reviewId].isValid, "Review already invalid");

        reviews[_reviewId].isValid = false;
    }
}
```

## 🧪 Testing Your Reputation System

### **Step 1: Compile the Contract**

1. In Remix, click **"Solidity Compiler"** tab (📝 icon)
2. Ensure compiler version is **0.8.19 or newer**
3. Click **"Compile ReputationSystem.sol"**
4. Look for **green checkmark ✅** (no errors)

**Troubleshooting**: If you see red errors, check for typos in your code.

### **Step 2: Deploy to Test Network**

1. Click **"Deploy & Run Transactions"** tab (🚀 icon)
2. Select **"Remix VM (London)"** environment
3. Click **"Deploy"** button (no constructor parameters needed)
4. Your contract appears under **"Deployed Contracts"**

### **Step 3: Interactive Testing**

#### **Test 1: Register Users**

1. **Copy Account Address**: From account dropdown, copy first address
2. **Call registerUser**: Enter `"Alice Smith"` and click **registerUser**
3. **Switch Account**: Select second account from dropdown
4. **Register Second User**: Enter `"Bob Johnson"` and click **registerUser**
5. **Check Results**: Click `totalUsers` - should show **2**

#### **Test 2: Submit Reviews**

1. **Stay as Bob**: Keep second account selected
2. **Review Alice**: Call `submitReview` with:
   - **\_reviewee**: Paste Alice's address
   - **\_rating**: Enter `5`
   - **\_comment**: Enter `"Excellent service, highly recommended!"`
3. **Switch to Alice**: Select first account
4. **Review Bob**: Call `submitReview` with Bob's address, rating `4`, comment `"Good communication"`

#### **Test 3: Check Reputation**

1. **Get Alice's Reputation**: Call `getUserReputation` with Alice's address
   - Should show: `averageRating: 500` (5.00 \* 100), `reviewCount: 1`, `isVerified: false`
2. **Get Bob's Reputation**: Call `getUserReputation` with Bob's address
   - Should show: `averageRating: 400` (4.00 \* 100), `reviewCount: 1`, `isVerified: false`

#### **Test 4: View Reviews**

1. **Get Review Details**: Call `getReview` with reviewId `1`
   - Should show Alice's review details
2. **Get User Reviews**: Call `getUserReviews` with Alice's address
   - Should return array `[1]` (review ID 1)

### **Step 4: Advanced Testing Scenarios**

#### **Test Error Conditions**

1. **Try Self-Review**: Attempt to review your own address - should fail
2. **Duplicate Review**: Try reviewing the same person twice - should fail
3. **Invalid Rating**: Try rating `0` or `6` - should fail
4. **Empty Fields**: Try empty name or comment - should fail

#### **Test Admin Functions**

1. **Check Owner**: Call `owner` - should show deployer address
2. **Transfer Ownership**: Call `transferOwnership` with new address
3. **Deactivate User**: Call `deactivateUser` with a user's address

## 🎯 What You've Accomplished

### **✅ Advanced Smart Contract Architecture**

- **Complex data structures** with structs and mappings
- **Access control patterns** with modifiers
- **Event logging** for transparency and indexing
- **Gas-efficient error handling** with custom errors

### **✅ Real-World Application Skills**

- **User registration and management** systems
- **Rating and review** mechanisms
- **Reputation calculation** algorithms
- **Administrative controls** and emergency functions

### **✅ Production-Ready Patterns**

- **Input validation** and security checks
- **State management** with proper data structures
- **Mathematical operations** for rating calculations
- **Event-driven architecture** for frontend integration

### **✅ Professional Development Skills**

- **Comprehensive documentation** with NatSpec comments
- **Modular code organization** with logical grouping
- **Error handling** with descriptive custom errors
- **Testing methodology** with systematic verification

## 🏆 Competition Project Ideas

### **🥇 Hackathon Enhancement Ideas**

#### **🌟 Multi-Platform Integration**

```solidity
// Extend your reputation system to work across platforms
contract CrossPlatformReputation is ReputationSystem {
    // Import reputation from other platforms
    // Enable reputation portability
    // Create unified reputation scores
}
```

#### **🎯 AI-Powered Features**

```solidity
// Add machine learning integration
contract SmartReputation is ReputationSystem {
    // Detect fake reviews using AI
    // Auto-moderate content
    // Predict reputation trends
}
```

#### **🌐 DeFi Integration**

```solidity
// Integrate with DeFi protocols
contract ReputationDeFi is ReputationSystem {
    // Use reputation as loan collateral
    // Reputation-based interest rates
    // Stake reputation tokens
}
```

### **💡 Real-World Implementation Ideas**

1. **Freelance Platform**: Replace Upwork/Fiverr with decentralized reputation
2. **Rideshare Network**: Uber/Lyft alternative with portable driver ratings
3. **E-commerce Marketplace**: Amazon alternative with trustless seller ratings
4. **Professional Network**: LinkedIn with verifiable skill endorsements
5. **Service Reviews**: Yelp replacement with immutable business reviews

## 🚀 Next Steps: Building Your Portfolio

### **📈 Immediate Next Steps**

1. **[Account Management](../03-real-projects/digital-bank/02-account-management.md)**: Build advanced user systems
2. **[Transaction Handling](../03-real-projects/digital-bank/03-basic-transactions.md)**: Handle real money transfers
3. **[Testing Frameworks](../03-real-projects/digital-bank/04-testing-basics.md)**: Professional testing strategies

### **🏗️ Portfolio Projects**

- **Deploy to testnet**: Put your reputation system live
- **Build frontend**: Create a web interface
- **Add features**: Implement the enhancement ideas above
- **Write documentation**: Create user guides and API docs

### **🎯 Competition Preparation**

- **Choose your niche**: Pick a specific industry (rideshare, freelance, etc.)
- **Research problems**: Identify pain points in current systems
- **Build MVP**: Create working prototype
- **Prepare pitch**: Practice explaining your solution

## 🌟 Congratulations!

You've just built a **production-ready reputation system** that demonstrates:

- ✅ **Complex smart contract architecture**
- ✅ **Real-world problem solving**
- ✅ **Professional coding standards**
- ✅ **Security best practices**
- ✅ **Gas optimization techniques**

**This single contract showcases skills that companies pay $120,000-$300,000/year for!**

**Ready for your next challenge?** Let's dive into [Complete Syntax Mastery](../02-syntax-mastery/complete-syntax-guide.md) where you'll learn every Solidity feature through building a complete DeFi protocol! 🚀

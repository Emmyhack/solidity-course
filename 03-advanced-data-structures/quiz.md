# Module 3 Quiz: Advanced Data Structures

Test your understanding of complex data structures, gas optimization, and advanced Solidity patterns.

## 📋 Instructions

- **Time Limit**: 45 minutes
- **Total Points**: 100 points
- **Passing Score**: 70 points
- **Question Types**: Multiple choice, code analysis, implementation

---

## Section A: Multiple Choice (40 points)

### Question 1 (5 points)

Which struct packing uses the LEAST storage slots?

A)

```solidity
struct A {
    uint256 value1;
    bool flag;
    uint256 value2;
}
```

B)

```solidity
struct B {
    uint128 value1;
    uint128 value2;
    bool flag;
}
```

C)

```solidity
struct C {
    bool flag;
    uint256 value1;
    uint256 value2;
}
```

D)

```solidity
struct D {
    uint256 value1;
    uint256 value2;
    bool flag;
}
```

**Answer: B** (Uses 2 storage slots vs 3 for others)

### Question 2 (5 points)

What is the gas cost for reading from storage (SLOAD operation)?

A) 200 gas
B) 2,100 gas
C) 5,000 gas
D) 20,000 gas

**Answer: B** (2,100 gas for SLOAD)

### Question 3 (5 points)

Which mapping key type is most gas-efficient?

A) `mapping(string => uint256)`
B) `mapping(bytes32 => uint256)`
C) `mapping(uint256 => uint256)`
D) `mapping(address => uint256)`

**Answer: C** (uint256 keys are most efficient)

### Question 4 (5 points)

For iterable mappings, what's the best pattern for efficient removal?

A) Shift all elements after the removed item
B) Mark item as deleted but keep in array
C) Swap with last element and pop
D) Create a new array without the item

**Answer: C** (Swap and pop is O(1) operation)

### Question 5 (5 points)

Which array operation has O(1) complexity?

A) `push()` to dynamic array
B) `pop()` from dynamic array
C) Access by index
D) All of the above

**Answer: D** (All are O(1) operations)

### Question 6 (5 points)

What's the maximum number of values that can be packed in one storage slot?

A) 8 uint32 values
B) 16 uint16 values
C) 32 uint8 values
D) All of the above

**Answer: D** (All fit in 256 bits)

### Question 7 (5 points)

Which is more gas-efficient for temporary data processing?

A) Storage variables
B) Memory variables
C) Calldata parameters
D) State variables

**Answer: B** (Memory is cheaper for temporary processing)

### Question 8 (5 points)

What's the best way to store large strings in contracts?

A) String storage variables
B) IPFS hash references
C) Event emissions
D) Both B and C

**Answer: D** (IPFS + events avoid expensive storage)

---

## Section B: Code Analysis (30 points)

### Question 9 (10 points)

Analyze this code and identify the gas optimization issue:

```solidity
contract UserManager {
    struct User {
        string username;
        uint256 reputation;
        bool isActive;
        uint256 joinDate;
        address userAddress;
    }

    mapping(address => User) public users;

    function updateUser(address _user, uint256 _reputation, bool _isActive) external {
        users[_user].reputation = _reputation;
        users[_user].isActive = _isActive;
    }
}
```

**Issues identified:**

1. **String in struct**: Storing strings is expensive
2. **Poor struct packing**: Fields not ordered by size
3. **Multiple storage writes**: Each field update is separate SSTORE

**Optimized version:**

```solidity
struct User {
    address userAddress;  // 20 bytes
    uint96 reputation;    // 12 bytes (total: 32 bytes = 1 slot)
    uint64 joinDate;      // 8 bytes
    bool isActive;        // 1 byte (total: 9 bytes in slot 2)
}
mapping(address => bytes32) public usernameHashes; // Store hash instead
```

### Question 10 (10 points)

What's wrong with this enumeration pattern?

```solidity
contract PostManager {
    mapping(uint256 => bool) public postExists;

    function getAllPosts() external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](1000000);
        uint256 count = 0;

        for (uint256 i = 1; i <= 1000000; i++) {
            if (postExists[i]) {
                result[count] = i;
                count++;
            }
        }

        return result;
    }
}
```

**Issues:**

1. **O(n) complexity**: Loops through all possible IDs
2. **Gas limit risk**: Large loops can exceed block gas limit
3. **Memory waste**: Allocates maximum size array
4. **No pagination**: Returns all data at once

**Better approach:**

```solidity
uint256[] public allPostIds;
mapping(uint256 => uint256) public postIndices;

function getPostsPaginated(uint256 start, uint256 limit)
    external view returns (uint256[] memory, bool hasMore) {
    // Implementation with pagination
}
```

### Question 11 (10 points)

Optimize this voting contract for gas efficiency:

```solidity
contract Voting {
    struct Vote {
        address voter;
        uint256 choice;
        uint256 timestamp;
        string comment;
    }

    mapping(uint256 => Vote[]) public votes;

    function vote(uint256 _proposalId, uint256 _choice, string memory _comment) external {
        votes[_proposalId].push(Vote({
            voter: msg.sender,
            choice: _choice,
            timestamp: block.timestamp,
            comment: _comment
        }));
    }
}
```

**Optimized version:**

```solidity
contract OptimizedVoting {
    struct Vote {
        address voter;        // 20 bytes
        uint32 timestamp;     // 4 bytes
        uint8 choice;         // 1 byte (total: 25 bytes, needs 2 slots)
    }

    mapping(uint256 => Vote[]) public votes;
    mapping(bytes32 => string) public comments; // Hash-based storage

    event VoteCast(uint256 indexed proposalId, address indexed voter,
                   uint8 choice, string comment, bytes32 commentHash);

    function vote(uint256 _proposalId, uint8 _choice, string calldata _comment) external {
        votes[_proposalId].push(Vote({
            voter: msg.sender,
            timestamp: uint32(block.timestamp),
            choice: _choice
        }));

        if (bytes(_comment).length > 0) {
            bytes32 hash = keccak256(bytes(_comment));
            comments[hash] = _comment;
            emit VoteCast(_proposalId, msg.sender, _choice, _comment, hash);
        }
    }
}
```

---

## Section C: Implementation (30 points)

### Question 12 (15 points)

Implement an efficient data structure for a social media platform that supports:

- Adding posts with metadata
- Following relationships
- Feed generation for users
- Trending post discovery

```solidity
contract SocialMedia {
    // Your implementation here
    // Focus on gas efficiency and access patterns
    // Include pagination for large datasets
    // Use events for off-chain indexing
}
```

**Sample solution structure:**

```solidity
contract SocialMedia {
    struct Post {
        address author;       // 20 bytes
        uint32 timestamp;     // 4 bytes
        uint16 likesCount;    // 2 bytes
        uint16 commentsCount; // 2 bytes
        uint8 category;       // 1 byte (total: 29 bytes, 2 slots)
    }

    struct UserData {
        uint32 followersCount;  // 4 bytes
        uint32 followingCount;  // 4 bytes
        uint32 postsCount;      // 4 bytes
        bool isVerified;        // 1 byte (total: 13 bytes, 1 slot)
    }

    mapping(uint256 => Post) public posts;
    mapping(address => UserData) public userData;
    mapping(address => mapping(address => bool)) public isFollowing;
    mapping(address => uint256[]) public userPosts;
    mapping(address => address[]) public followers;

    uint256[] public allPostIds;
    uint256 public nextPostId = 1;

    event PostCreated(uint256 indexed postId, address indexed author);
    event UserFollowed(address indexed follower, address indexed followed);

    function createPost(uint8 _category) external returns (uint256) {
        uint256 postId = nextPostId++;

        posts[postId] = Post({
            author: msg.sender,
            timestamp: uint32(block.timestamp),
            likesCount: 0,
            commentsCount: 0,
            category: _category
        });

        userPosts[msg.sender].push(postId);
        allPostIds.push(postId);
        userData[msg.sender].postsCount++;

        emit PostCreated(postId, msg.sender);
        return postId;
    }

    function followUser(address _user) external {
        require(!isFollowing[msg.sender][_user], "Already following");

        isFollowing[msg.sender][_user] = true;
        followers[_user].push(msg.sender);

        userData[msg.sender].followingCount++;
        userData[_user].followersCount++;

        emit UserFollowed(msg.sender, _user);
    }

    function getFeed(uint256 _start, uint256 _limit)
        external view returns (uint256[] memory feedPosts, bool hasMore) {
        // Implementation for user feed with pagination
    }

    function getTrending(uint256 _limit)
        external view returns (uint256[] memory trendingPosts) {
        // Implementation for trending posts based on recent activity
    }
}
```

### Question 13 (15 points)

Design a gas-efficient inventory system for an NFT marketplace with the following requirements:

- Items with categories, rarity levels, and prices
- Ownership tracking and transfer history
- Search by category, price range, and rarity
- Batch operations for multiple items

```solidity
contract NFTMarketplace {
    // Your implementation here
    // Focus on packed structs and efficient indexing
    // Include batch operations
    // Optimize for common query patterns
}
```

**Sample solution highlights:**

```solidity
contract NFTMarketplace {
    struct Item {
        address owner;        // 20 bytes
        uint96 price;         // 12 bytes (32 bytes total = 1 slot)
        uint32 mintTime;      // 4 bytes
        uint16 category;      // 2 bytes
        uint8 rarity;         // 1 byte (7 bytes total, fits in slot 2)
    }

    mapping(uint256 => Item) public items;
    mapping(address => uint256[]) public ownerItems;
    mapping(uint16 => uint256[]) public categoryItems;
    mapping(uint8 => uint256[]) public rarityItems;

    // Batch operations for gas efficiency
    function batchTransfer(uint256[] calldata _tokenIds, address _to) external {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            _transfer(_tokenIds[i], _to);
        }
    }

    function searchItems(
        uint16 _category,
        uint8 _minRarity,
        uint96 _maxPrice,
        uint256 _limit
    ) external view returns (uint256[] memory matchingItems) {
        // Efficient search implementation
    }
}
```

---

## Answer Key Summary

**Section A (Multiple Choice):**

1. B (2 storage slots)
2. B (2,100 gas)
3. C (uint256 keys)
4. C (Swap and pop)
5. D (All are O(1))
6. D (All fit in 256 bits)
7. B (Memory variables)
8. D (IPFS + events)

**Section B (Code Analysis):** 9. String storage, poor packing, multiple SSTOREs 10. O(n) loops, gas limits, no pagination 11. Struct optimization, event usage, hash-based strings

**Section C (Implementation):** 12. Social media with packed structs and pagination 13. NFT marketplace with efficient indexing

---

## Grading Rubric

- **Section A**: 5 points per question (40 total)
- **Section B**: Code analysis and optimization skills (30 total)
- **Section C**: Implementation design and efficiency (30 total)

**Grade Scale:**

- A: 90-100 points
- B: 80-89 points
- C: 70-79 points
- F: Below 70 points

---

**Time to test your data structure mastery!** 🧠⚡

# Gas Optimization Guide for Advanced Data Structures

A comprehensive guide to optimizing gas usage when working with complex data structures in Solidity.

##  Overview

Gas optimization for data structures involves understanding storage layout, access patterns, and the trade-offs between different approaches. This guide provides practical techniques and real-world examples.

##  Storage Layout Fundamentals

### Storage Slots and Packing

Each storage slot is 32 bytes (256 bits). Understanding how Solidity packs data is crucial for optimization.

```solidity
//  Inefficient: Uses 3 storage slots
struct BadExample {
    uint128 value1;  // Slot 0 (128 bits used, 128 bits wasted)
    bool flag;       // Slot 1 (8 bits used, 248 bits wasted)
    uint128 value2;  // Slot 2 (128 bits used, 128 bits wasted)
}

//  Efficient: Uses 2 storage slots
struct GoodExample {
    uint128 value1;  // Slot 0 (first 128 bits)
    uint128 value2;  // Slot 0 (last 128 bits)
    bool flag;       // Slot 1 (8 bits used)
}

//  Even better: Uses 1 storage slot for small values
struct OptimalExample {
    uint64 value1;   // Slot 0 (bits 0-63)
    uint64 value2;   // Slot 0 (bits 64-127)
    uint32 value3;   // Slot 0 (bits 128-159)
    uint32 value4;   // Slot 0 (bits 160-191)
    bool flag1;      // Slot 0 (bit 192)
    bool flag2;      // Slot 0 (bit 193)
    // 62 bits still available in this slot
}
```

### Gas Costs by Operation

| Operation         | Gas Cost      | Notes                                |
| ----------------- | ------------- | ------------------------------------ |
| SSTORE (new)      | 20,000        | Setting storage value for first time |
| SSTORE (update)   | 5,000         | Changing existing storage value      |
| SLOAD             | 2,100         | Reading from storage                 |
| Memory allocation | 3 + quadratic | Becomes expensive for large data     |
| Calldata read     | 16            | Reading function parameter           |

##  Data Structure Optimization Techniques

### 1. Packed Structs

Use appropriate data types to minimize storage slots:

```solidity
// Example: User profile optimization
contract OptimizedUserProfile {
    struct UserProfile {
        address userAddress;    // 20 bytes - Slot 0
        uint96 reputation;     // 12 bytes - Slot 0 (total: 32 bytes)

        uint128 joinDate;      // 16 bytes - Slot 1
        uint64 lastActivity;   // 8 bytes  - Slot 1
        uint32 postsCount;     // 4 bytes  - Slot 1
        uint16 level;          // 2 bytes  - Slot 1
        uint8 status;          // 1 byte   - Slot 1
        bool isVerified;       // 1 bit    - Slot 1
        // Total: 2 storage slots instead of 8
    }

    mapping(address => UserProfile) public profiles;

    // Gas efficient profile update
    function updateProfile(
        uint96 _reputation,
        uint32 _postsCount,
        uint16 _level,
        uint8 _status,
        bool _isVerified
    ) external {
        UserProfile storage profile = profiles[msg.sender];

        // Single storage write - very efficient
        profile.reputation = _reputation;
        profile.postsCount = _postsCount;
        profile.level = _level;
        profile.status = _status;
        profile.isVerified = _isVerified;
        profile.lastActivity = uint64(block.timestamp);
    }
}
```

### 2. Efficient Array Operations

```solidity
contract OptimizedArrays {
    //  Expensive: Push one by one
    function addNumbersSlow(uint256[] memory _numbers) external {
        for (uint256 i = 0; i < _numbers.length; i++) {
            numbers.push(_numbers[i]);
        }
    }

    //  Better: Batch operations
    uint256[] public numbers;

    function addNumbersFast(uint256[] calldata _numbers) external {
        uint256 currentLength = numbers.length;

        // Pre-allocate space (if possible in your use case)
        for (uint256 i = 0; i < _numbers.length; i++) {
            numbers.push(_numbers[i]);
        }
    }

    //  Most efficient: Assembly optimization for simple cases
    function addNumbersAssembly(uint256[] calldata _numbers) external {
        assembly {
            // Load the storage slot for numbers array length
            let slot := numbers.slot
            let length := sload(slot)

            // Update length
            sstore(slot, add(length, _numbers.length))

            // Store new elements
            for { let i := 0 } lt(i, _numbers.length) { i := add(i, 1) } {
                let value := calldataload(add(_numbers.offset, mul(i, 0x20)))
                let newSlot := add(keccak256(slot, 0x20), add(length, i))
                sstore(newSlot, value)
            }
        }
    }
}
```

### 3. Mapping Optimization Patterns

```solidity
contract OptimizedMappings {
    //  Use appropriate key types
    mapping(bytes32 => uint256) public hashToValue;  // 32 bytes key
    mapping(uint256 => address) public idToAddress;   // 32 bytes key
    mapping(address => bool) public isWhitelisted;    // 20 bytes key (auto-padded)

    //  Packed mapping values
    struct PackedData {
        uint128 value1;
        uint128 value2;
        // Total: 1 storage slot
    }
    mapping(address => PackedData) public userData;

    //  Nested mappings for complex relationships
    mapping(address => mapping(uint256 => bool)) public userTokens;

    //  Efficient existence checking
    mapping(address => uint256) public userIndex; // 1-based index
    address[] public users;

    function addUser(address _user) external {
        require(userIndex[_user] == 0, "User exists");

        users.push(_user);
        userIndex[_user] = users.length; // 1-based indexing
    }

    function removeUser(address _user) external {
        uint256 index = userIndex[_user];
        require(index > 0, "User not found");

        // Swap with last element (gas efficient removal)
        uint256 lastIndex = users.length - 1;
        address lastUser = users[lastIndex];

        users[index - 1] = lastUser;
        userIndex[lastUser] = index;

        users.pop();
        delete userIndex[_user];
    }
}
```

### 4. Memory vs Storage Optimization

```solidity
contract MemoryStorageOptimization {
    struct Item {
        uint256 id;
        string name;
        uint256 value;
    }

    Item[] public items;

    //  Expensive: Multiple storage reads
    function processItemsSlow(uint256[] memory _indices) external view returns (uint256 total) {
        for (uint256 i = 0; i < _indices.length; i++) {
            total += items[_indices[i]].value; // Storage read each time
        }
    }

    //  Efficient: Load to memory once
    function processItemsFast(uint256[] memory _indices) external view returns (uint256 total) {
        for (uint256 i = 0; i < _indices.length; i++) {
            Item memory item = items[_indices[i]]; // Single storage read
            total += item.value;
        }
    }

    //  Most efficient: Batch processing
    function processItemsBatch(uint256 _start, uint256 _end) external view returns (uint256 total) {
        for (uint256 i = _start; i <= _end; i++) {
            total += items[i].value;
        }
    }
}
```

##  Advanced Optimization Techniques

### 1. Bit Manipulation for Flags

```solidity
contract BitFlags {
    // Instead of multiple bool mappings, use bit manipulation
    mapping(address => uint256) public userFlags;

    uint256 constant IS_VERIFIED = 1 << 0;     // Bit 0
    uint256 constant IS_PREMIUM = 1 << 1;      // Bit 1
    uint256 constant IS_MODERATOR = 1 << 2;    // Bit 2
    uint256 constant IS_BANNED = 1 << 3;       // Bit 3

    function setFlag(address _user, uint256 _flag) external {
        userFlags[_user] |= _flag;
    }

    function unsetFlag(address _user, uint256 _flag) external {
        userFlags[_user] &= ~_flag;
    }

    function hasFlag(address _user, uint256 _flag) external view returns (bool) {
        return (userFlags[_user] & _flag) != 0;
    }

    // Set multiple flags in one operation
    function setMultipleFlags(address _user, uint256 _flags) external {
        userFlags[_user] |= _flags;
    }
}
```

### 2. String Optimization

```solidity
contract StringOptimization {
    //  Expensive: Long strings in storage
    mapping(uint256 => string) public longDescriptions;

    //  Better: Hash-based storage with off-chain lookup
    mapping(uint256 => bytes32) public descriptionHashes;
    mapping(bytes32 => string) public hashToString;

    //  Even better: Use events for strings
    event DescriptionSet(uint256 indexed id, string description, bytes32 hash);

    function setDescriptionOptimized(uint256 _id, string calldata _description) external {
        bytes32 hash = keccak256(bytes(_description));
        descriptionHashes[_id] = hash;

        // Only store unique strings
        if (bytes(hashToString[hash]).length == 0) {
            hashToString[hash] = _description;
        }

        emit DescriptionSet(_id, _description, hash);
    }
}
```

### 3. Pagination Patterns

```solidity
contract EfficientPagination {
    struct User {
        address addr;
        string name;
        uint256 joinDate;
    }

    User[] public users;
    mapping(address => uint256) public userIndex;

    //  Efficient pagination with limit
    function getUsersPage(
        uint256 _start,
        uint256 _limit
    ) external view returns (
        User[] memory pageUsers,
        uint256 total,
        bool hasMore
    ) {
        total = users.length;

        if (_start >= total) {
            return (new User[](0), total, false);
        }

        uint256 end = _start + _limit;
        if (end > total) {
            end = total;
        }

        uint256 pageSize = end - _start;
        pageUsers = new User[](pageSize);

        for (uint256 i = 0; i < pageSize; i++) {
            pageUsers[i] = users[_start + i];
        }

        hasMore = end < total;
    }

    //  Cursor-based pagination for large datasets
    uint256 public constant PAGE_SIZE = 50;

    function getUsersCursor(
        uint256 _cursor
    ) external view returns (
        User[] memory pageUsers,
        uint256 newCursor,
        bool hasMore
    ) {
        uint256 remaining = users.length - _cursor;
        uint256 pageSize = remaining > PAGE_SIZE ? PAGE_SIZE : remaining;

        pageUsers = new User[](pageSize);

        for (uint256 i = 0; i < pageSize; i++) {
            pageUsers[i] = users[_cursor + i];
        }

        newCursor = _cursor + pageSize;
        hasMore = newCursor < users.length;
    }
}
```

##  Gas Analysis Examples

### Real-world Gas Comparisons

| Operation         | Unoptimized Gas | Optimized Gas | Savings |
| ----------------- | --------------- | ------------- | ------- |
| User Registration | 157,234         | 98,567        | 37%     |
| Profile Update    | 45,123          | 21,234        | 53%     |
| Batch Add Items   | 234,567         | 89,123        | 62%     |
| Search Users      | 167,890         | 45,234        | 73%     |

### Optimization Checklist

- [ ] **Struct Packing**: Order fields by size for optimal packing
- [ ] **Batch Operations**: Group multiple operations when possible
- [ ] **Memory Usage**: Use memory for temporary data processing
- [ ] **String Handling**: Consider alternatives to storage strings
- [ ] **Array Operations**: Optimize push/pop and search patterns
- [ ] **Mapping Design**: Use appropriate key types and value packing
- [ ] **Event Usage**: Use events for data that doesn't need on-chain storage
- [ ] **Assembly Optimization**: Use inline assembly for critical paths

##  Testing Gas Efficiency

```javascript
// Example test for gas optimization
describe("Gas Optimization Tests", function () {
  it("should use less gas for optimized operations", async function () {
    const optimized = await deployOptimizedContract();
    const unoptimized = await deployUnoptimizedContract();

    const tx1 = await optimized.batchOperation(data);
    const tx2 = await unoptimized.batchOperation(data);

    const gas1 = tx1.gasUsed;
    const gas2 = tx2.gasUsed;

    expect(gas1).to.be.lt(gas2);
    console.log(`Gas savings: ${(((gas2 - gas1) / gas2) * 100).toFixed(2)}%`);
  });
});
```

##  Additional Resources

- [Solidity Storage Layout Documentation](https://docs.soliditylang.org/en/latest/internals/layout_in_storage.html)
- [Gas Optimization Patterns](https://github.com/dragonfly-xyz/useful-solidity-patterns)
- [EVM Gas Costs](https://github.com/djrtwo/evm-opcode-gas-costs)
- [Storage Slot Calculator](https://solidity-utilities.org)

---

**Remember**: Always measure actual gas usage and test thoroughly. Optimization should never compromise security or functionality! 

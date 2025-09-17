# Gaming NFT Ecosystem

A comprehensive gaming NFT system featuring character progression, item crafting, virtual land ownership, and play-to-earn mechanics.

## Features

- **Character NFTs**: RPG-style characters with stats and progression
- **Equipment System**: Weapons, armor, and accessories
- **Virtual Land**: Ownable and tradeable land parcels
- **Crafting System**: Combine items to create new equipment
- **Guild Mechanics**: Team-based ownership and shared benefits
- **Tournament System**: Competitive gameplay with NFT rewards
- **Breeding System**: Create new characters from existing ones

## Contract Architecture

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

/**
 * @title GameCharacter
 * @dev RPG-style character NFTs with stats, levels, and equipment
 * 
 * Features:
 * - Randomly generated base stats using Chainlink VRF
 * - Character progression through experience and leveling
 * - Equipment slots for weapons, armor, and accessories
 * - Class-based abilities and restrictions
 * - Breeding system for creating new characters
 * - Soul-bound aspects for competitive integrity
 */
contract GameCharacter is ERC721, AccessControl, ReentrancyGuard, VRFConsumerBase {
    using Counters for Counters.Counter;

    // =============================================================
    //                            ROLES
    // =============================================================

    bytes32 public constant GAME_MASTER_ROLE = keccak256("GAME_MASTER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct BaseStats {
        uint16 strength;     // Physical damage and carrying capacity
        uint16 defense;      // Physical damage reduction
        uint16 magic;        // Magical damage and mana
        uint16 resistance;   // Magical damage reduction
        uint16 agility;      // Speed and critical hit chance
        uint16 luck;         // Rare drops and critical hit chance
    }

    struct Character {
        uint256 level;
        uint256 experience;
        BaseStats baseStats;
        BaseStats equipmentStats; // Bonus from equipped items
        CharacterClass class;
        uint256 generation;
        uint256 parentA;         // For breeding
        uint256 parentB;         // For breeding
        uint256 birthTime;
        bool soulBound;          // Cannot be traded if true
        mapping(EquipmentSlot => uint256) equipment; // Equipped item IDs
    }

    enum CharacterClass {
        WARRIOR,
        MAGE,
        ARCHER,
        ROGUE,
        PALADIN,
        NECROMANCER
    }

    enum EquipmentSlot {
        WEAPON,
        ARMOR,
        HELMET,
        BOOTS,
        ACCESSORY_1,
        ACCESSORY_2
    }

    // =============================================================
    //                            STORAGE
    // =============================================================

    Counters.Counter private _tokenIdCounter;
    
    mapping(uint256 => Character) public characters;
    mapping(bytes32 => uint256) private _vrfRequests;
    mapping(CharacterClass => BaseStats) public classBaseBonuses;
    mapping(uint256 => uint256) public experienceRequiredForLevel;
    
    // Breeding mechanics
    mapping(uint256 => uint256) public lastBreedTime;
    uint256 public breedingCooldown = 7 days;
    uint256 public maxGeneration = 10;
    
    // Chainlink VRF
    bytes32 internal keyHash;
    uint256 internal fee;
    
    // Game contracts
    address public gameItemContract;
    address public guildContract;
    
    // =============================================================
    //                            EVENTS
    // =============================================================

    event CharacterMinted(
        uint256 indexed tokenId,
        address indexed owner,
        CharacterClass class,
        uint256 generation
    );
    
    event CharacterLevelUp(
        uint256 indexed tokenId,
        uint256 newLevel,
        BaseStats newStats
    );
    
    event ExperienceGained(
        uint256 indexed tokenId,
        uint256 amount,
        uint256 totalExperience
    );
    
    event EquipmentChanged(
        uint256 indexed tokenId,
        EquipmentSlot slot,
        uint256 oldItemId,
        uint256 newItemId
    );
    
    event CharacterBred(
        uint256 indexed parentA,
        uint256 indexed parentB,
        uint256 indexed childId,
        CharacterClass childClass
    );

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor(
        string memory name,
        string memory symbol,
        address vrfCoordinator,
        address linkToken,
        bytes32 _keyHash,
        uint256 _fee
    ) 
        ERC721(name, symbol)
        VRFConsumerBase(vrfCoordinator, linkToken)
    {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(GAME_MASTER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        
        keyHash = _keyHash;
        fee = _fee;
        
        _initializeClassBonuses();
        _initializeExperienceTable();
    }

    // =============================================================
    //                        MINTING FUNCTIONS
    // =============================================================

    /**
     * @dev Mint a new character with random stats
     */
    function mintCharacter(
        address to,
        CharacterClass class,
        bool soulBound
    ) external onlyRole(MINTER_ROLE) returns (uint256) {
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");
        
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        // Request random stats from Chainlink VRF
        bytes32 requestId = requestRandomness(keyHash, fee);
        _vrfRequests[requestId] = tokenId;
        
        _safeMint(to, tokenId);
        
        // Initialize basic character data
        Character storage character = characters[tokenId];
        character.level = 1;
        character.experience = 0;
        character.class = class;
        character.generation = 1;
        character.birthTime = block.timestamp;
        character.soulBound = soulBound;
        
        return tokenId;
    }

    /**
     * @dev Fulfill randomness from Chainlink VRF
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 tokenId = _vrfRequests[requestId];
        require(_exists(tokenId), "Token does not exist");
        
        Character storage character = characters[tokenId];
        
        // Generate random base stats (50-100 range)
        character.baseStats = BaseStats({
            strength: uint16(50 + (randomness % 51)),
            defense: uint16(50 + ((randomness >> 8) % 51)),
            magic: uint16(50 + ((randomness >> 16) % 51)),
            resistance: uint16(50 + ((randomness >> 24) % 51)),
            agility: uint16(50 + ((randomness >> 32) % 51)),
            luck: uint16(50 + ((randomness >> 40) % 51))
        });
        
        // Apply class bonuses
        BaseStats memory classBonuses = classBaseBonuses[character.class];
        character.baseStats.strength += classBonuses.strength;
        character.baseStats.defense += classBonuses.defense;
        character.baseStats.magic += classBonuses.magic;
        character.baseStats.resistance += classBonuses.resistance;
        character.baseStats.agility += classBonuses.agility;
        character.baseStats.luck += classBonuses.luck;
        
        emit CharacterMinted(tokenId, ownerOf(tokenId), character.class, character.generation);
    }

    // =============================================================
    //                    PROGRESSION FUNCTIONS
    // =============================================================

    /**
     * @dev Grant experience to a character
     */
    function grantExperience(uint256 tokenId, uint256 amount) 
        external 
        onlyRole(GAME_MASTER_ROLE) 
    {
        require(_exists(tokenId), "Character does not exist");
        
        Character storage character = characters[tokenId];
        character.experience += amount;
        
        emit ExperienceGained(tokenId, amount, character.experience);
        
        // Check for level up
        _checkLevelUp(tokenId);
    }

    /**
     * @dev Check and process level ups
     */
    function _checkLevelUp(uint256 tokenId) internal {
        Character storage character = characters[tokenId];
        uint256 requiredExp = experienceRequiredForLevel[character.level + 1];
        
        while (character.experience >= requiredExp && requiredExp > 0) {
            character.level++;
            
            // Increase base stats on level up
            character.baseStats.strength += _getStatIncrease(character.class, "strength");
            character.baseStats.defense += _getStatIncrease(character.class, "defense");
            character.baseStats.magic += _getStatIncrease(character.class, "magic");
            character.baseStats.resistance += _getStatIncrease(character.class, "resistance");
            character.baseStats.agility += _getStatIncrease(character.class, "agility");
            character.baseStats.luck += _getStatIncrease(character.class, "luck");
            
            emit CharacterLevelUp(tokenId, character.level, character.baseStats);
            
            // Check next level
            requiredExp = experienceRequiredForLevel[character.level + 1];
        }
    }

    /**
     * @dev Get stat increase based on class
     */
    function _getStatIncrease(CharacterClass class, string memory stat) 
        internal 
        pure 
        returns (uint16) 
    {
        // Different classes get different stat growth
        if (keccak256(bytes(stat)) == keccak256(bytes("strength"))) {
            if (class == CharacterClass.WARRIOR || class == CharacterClass.PALADIN) return 3;
            if (class == CharacterClass.ARCHER || class == CharacterClass.ROGUE) return 2;
            return 1;
        }
        // Add similar logic for other stats...
        return 1;
    }

    // =============================================================
    //                    EQUIPMENT FUNCTIONS
    // =============================================================

    /**
     * @dev Equip an item to a character
     */
    function equipItem(uint256 tokenId, uint256 itemId, EquipmentSlot slot) 
        external 
        nonReentrant 
    {
        require(ownerOf(tokenId) == msg.sender, "Not character owner");
        require(_canEquipItem(tokenId, itemId, slot), "Cannot equip item");
        
        Character storage character = characters[tokenId];
        uint256 oldItemId = character.equipment[slot];
        
        if (oldItemId != 0) {
            // Unequip old item
            _unequipItem(tokenId, slot);
        }
        
        // Equip new item
        character.equipment[slot] = itemId;
        
        // Update equipment stats
        _updateEquipmentStats(tokenId);
        
        // Transfer item to this contract (if applicable)
        // IERC1155(gameItemContract).safeTransferFrom(msg.sender, address(this), itemId, 1, "");
        
        emit EquipmentChanged(tokenId, slot, oldItemId, itemId);
    }

    /**
     * @dev Unequip an item from a character
     */
    function unequipItem(uint256 tokenId, EquipmentSlot slot) external {
        require(ownerOf(tokenId) == msg.sender, "Not character owner");
        
        _unequipItem(tokenId, slot);
    }

    /**
     * @dev Internal unequip function
     */
    function _unequipItem(uint256 tokenId, EquipmentSlot slot) internal {
        Character storage character = characters[tokenId];
        uint256 itemId = character.equipment[slot];
        
        if (itemId != 0) {
            character.equipment[slot] = 0;
            
            // Update equipment stats
            _updateEquipmentStats(tokenId);
            
            // Return item to owner (if applicable)
            // IERC1155(gameItemContract).safeTransferFrom(address(this), ownerOf(tokenId), itemId, 1, "");
            
            emit EquipmentChanged(tokenId, slot, itemId, 0);
        }
    }

    /**
     * @dev Update equipment stats for a character
     */
    function _updateEquipmentStats(uint256 tokenId) internal {
        Character storage character = characters[tokenId];
        
        // Reset equipment stats
        character.equipmentStats = BaseStats(0, 0, 0, 0, 0, 0);
        
        // Sum up stats from all equipped items
        for (uint256 i = 0; i < 6; i++) {
            EquipmentSlot slot = EquipmentSlot(i);
            uint256 itemId = character.equipment[slot];
            
            if (itemId != 0) {
                // Get item stats from game item contract
                // BaseStats memory itemStats = IGameItem(gameItemContract).getItemStats(itemId);
                // character.equipmentStats.strength += itemStats.strength;
                // ... add other stats
            }
        }
    }

    /**
     * @dev Check if an item can be equipped
     */
    function _canEquipItem(uint256 tokenId, uint256 itemId, EquipmentSlot slot) 
        internal 
        view 
        returns (bool) 
    {
        // Check class restrictions, level requirements, etc.
        // This would interact with the game item contract
        return true; // Simplified
    }

    // =============================================================
    //                     BREEDING FUNCTIONS
    // =============================================================

    /**
     * @dev Breed two characters to create a new one
     */
    function breedCharacters(uint256 parentAId, uint256 parentBId) 
        external 
        nonReentrant 
        returns (uint256) 
    {
        require(ownerOf(parentAId) == msg.sender, "Not owner of parent A");
        require(ownerOf(parentBId) == msg.sender, "Not owner of parent B");
        require(parentAId != parentBId, "Cannot breed with itself");
        
        Character storage parentA = characters[parentAId];
        Character storage parentB = characters[parentBId];
        
        require(parentA.level >= 5, "Parent A level too low");
        require(parentB.level >= 5, "Parent B level too low");
        require(
            block.timestamp >= lastBreedTime[parentAId] + breedingCooldown,
            "Parent A breeding cooldown"
        );
        require(
            block.timestamp >= lastBreedTime[parentBId] + breedingCooldown,
            "Parent B breeding cooldown"
        );
        
        uint256 newGeneration = (parentA.generation > parentB.generation ? 
            parentA.generation : parentB.generation) + 1;
        require(newGeneration <= maxGeneration, "Max generation exceeded");
        
        // Create new character
        uint256 childId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        
        _safeMint(msg.sender, childId);
        
        Character storage child = characters[childId];
        child.level = 1;
        child.experience = 0;
        child.generation = newGeneration;
        child.parentA = parentAId;
        child.parentB = parentBId;
        child.birthTime = block.timestamp;
        
        // Determine child class (random chance based on parents)
        uint256 randomSeed = uint256(keccak256(abi.encodePacked(
            block.timestamp, block.difficulty, parentAId, parentBId
        )));
        
        if (randomSeed % 100 < 50) {
            child.class = parentA.class;
        } else {
            child.class = parentB.class;
        }
        
        // Inherit stats (average of parents with some randomness)
        _inheritStats(childId, parentAId, parentBId, randomSeed);
        
        // Update breeding cooldowns
        lastBreedTime[parentAId] = block.timestamp;
        lastBreedTime[parentBId] = block.timestamp;
        
        emit CharacterBred(parentAId, parentBId, childId, child.class);
        
        return childId;
    }

    /**
     * @dev Calculate inherited stats from parents
     */
    function _inheritStats(
        uint256 childId,
        uint256 parentAId,
        uint256 parentBId,
        uint256 randomSeed
    ) internal {
        Character storage child = characters[childId];
        Character storage parentA = characters[parentAId];
        Character storage parentB = characters[parentBId];
        
        // Average parent stats with some randomness
        child.baseStats.strength = uint16(_inheritStat(
            parentA.baseStats.strength,
            parentB.baseStats.strength,
            randomSeed
        ));
        
        child.baseStats.defense = uint16(_inheritStat(
            parentA.baseStats.defense,
            parentB.baseStats.defense,
            randomSeed >> 8
        ));
        
        child.baseStats.magic = uint16(_inheritStat(
            parentA.baseStats.magic,
            parentB.baseStats.magic,
            randomSeed >> 16
        ));
        
        child.baseStats.resistance = uint16(_inheritStat(
            parentA.baseStats.resistance,
            parentB.baseStats.resistance,
            randomSeed >> 24
        ));
        
        child.baseStats.agility = uint16(_inheritStat(
            parentA.baseStats.agility,
            parentB.baseStats.agility,
            randomSeed >> 32
        ));
        
        child.baseStats.luck = uint16(_inheritStat(
            parentA.baseStats.luck,
            parentB.baseStats.luck,
            randomSeed >> 40
        ));
        
        // Apply class bonuses
        BaseStats memory classBonuses = classBaseBonuses[child.class];
        child.baseStats.strength += classBonuses.strength;
        child.baseStats.defense += classBonuses.defense;
        child.baseStats.magic += classBonuses.magic;
        child.baseStats.resistance += classBonuses.resistance;
        child.baseStats.agility += classBonuses.agility;
        child.baseStats.luck += classBonuses.luck;
    }

    /**
     * @dev Calculate inherited stat value
     */
    function _inheritStat(
        uint16 parentAStat,
        uint16 parentBStat,
        uint256 randomness
    ) internal pure returns (uint256) {
        uint256 average = (uint256(parentAStat) + uint256(parentBStat)) / 2;
        uint256 variance = average / 10; // 10% variance
        
        // Add randomness within variance
        uint256 adjustment = (randomness % (variance * 2 + 1));
        if (adjustment > variance) {
            return average + (adjustment - variance);
        } else {
            return average - adjustment;
        }
    }

    // =============================================================
    //                    TRANSFER RESTRICTIONS
    // =============================================================

    /**
     * @dev Override transfer to handle soul-bound characters
     */
    function _transfer(address from, address to, uint256 tokenId) internal override {
        require(!characters[tokenId].soulBound, "Character is soul-bound");
        super._transfer(from, to, tokenId);
    }

    // =============================================================
    //                      VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Get total stats (base + equipment) for a character
     */
    function getTotalStats(uint256 tokenId) external view returns (BaseStats memory) {
        Character storage character = characters[tokenId];
        
        return BaseStats({
            strength: character.baseStats.strength + character.equipmentStats.strength,
            defense: character.baseStats.defense + character.equipmentStats.defense,
            magic: character.baseStats.magic + character.equipmentStats.magic,
            resistance: character.baseStats.resistance + character.equipmentStats.resistance,
            agility: character.baseStats.agility + character.equipmentStats.agility,
            luck: character.baseStats.luck + character.equipmentStats.luck
        });
    }

    /**
     * @dev Get character power level (total of all stats)
     */
    function getPowerLevel(uint256 tokenId) external view returns (uint256) {
        BaseStats memory totalStats = this.getTotalStats(tokenId);
        return uint256(totalStats.strength) + 
               uint256(totalStats.defense) + 
               uint256(totalStats.magic) + 
               uint256(totalStats.resistance) + 
               uint256(totalStats.agility) + 
               uint256(totalStats.luck);
    }

    /**
     * @dev Get equipped item for a slot
     */
    function getEquippedItem(uint256 tokenId, EquipmentSlot slot) 
        external 
        view 
        returns (uint256) 
    {
        return characters[tokenId].equipment[slot];
    }

    /**
     * @dev Check if character can breed
     */
    function canBreed(uint256 tokenId) external view returns (bool) {
        Character storage character = characters[tokenId];
        return character.level >= 5 && 
               block.timestamp >= lastBreedTime[tokenId] + breedingCooldown &&
               character.generation < maxGeneration;
    }

    // =============================================================
    //                    ADMIN FUNCTIONS
    // =============================================================

    /**
     * @dev Initialize class base bonuses
     */
    function _initializeClassBonuses() internal {
        classBaseBonuses[CharacterClass.WARRIOR] = BaseStats(15, 10, 0, 5, 5, 0);
        classBaseBonuses[CharacterClass.MAGE] = BaseStats(0, 5, 15, 10, 5, 0);
        classBaseBonuses[CharacterClass.ARCHER] = BaseStats(8, 5, 5, 5, 12, 0);
        classBaseBonuses[CharacterClass.ROGUE] = BaseStats(5, 3, 3, 3, 15, 6);
        classBaseBonuses[CharacterClass.PALADIN] = BaseStats(10, 12, 8, 8, 2, 0);
        classBaseBonuses[CharacterClass.NECROMANCER] = BaseStats(3, 5, 12, 8, 7, 5);
    }

    /**
     * @dev Initialize experience table
     */
    function _initializeExperienceTable() internal {
        for (uint256 i = 1; i <= 100; i++) {
            experienceRequiredForLevel[i] = i * i * 100; // Exponential growth
        }
    }

    /**
     * @dev Set game item contract
     */
    function setGameItemContract(address _gameItemContract) 
        external 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        gameItemContract = _gameItemContract;
    }

    /**
     * @dev Set breeding cooldown
     */
    function setBreedingCooldown(uint256 _cooldown) 
        external 
        onlyRole(GAME_MASTER_ROLE) 
    {
        breedingCooldown = _cooldown;
    }

    /**
     * @dev Emergency withdraw LINK tokens
     */
    function withdrawLink() external onlyRole(DEFAULT_ADMIN_ROLE) {
        LINK.transfer(msg.sender, LINK.balanceOf(address(this)));
    }

    // =============================================================
    //                        UTILITIES
    // =============================================================

    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(ERC721, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}

/**
 * @title GameItem
 * @dev ERC1155 contract for game items, equipment, and consumables
 */
contract GameItem is ERC1155, AccessControl {
    // Implementation for game items, weapons, armor, etc.
    // This would contain item stats, crafting recipes, etc.
}

/**
 * @title VirtualLand
 * @dev ERC721 contract for virtual land ownership
 */
contract VirtualLand is ERC721, AccessControl {
    struct LandParcel {
        int256 x;
        int256 y;
        uint256 size;
        LandType landType;
        address[] allowedBuilders;
        mapping(address => bool) buildings;
    }
    
    enum LandType {
        PLAINS,
        FOREST,
        MOUNTAIN,
        DESERT,
        SWAMP,
        RARE_CRYSTAL
    }
    
    // Implementation for virtual land system
}
```

## Gaming Economy Design

### Play-to-Earn Mechanics
1. **Battle Rewards**: Experience and items from combat
2. **Quest Completion**: Token rewards for mission completion
3. **Tournament Prizes**: Rare NFTs for competitive play
4. **Breeding Income**: Sell offspring for profit
5. **Land Rental**: Earn from land usage rights

### Item Progression System
1. **Common Items**: Basic equipment, easy to obtain
2. **Rare Items**: Enhanced stats, moderate difficulty
3. **Epic Items**: Significant bonuses, challenging to get
4. **Legendary Items**: Game-changing effects, extremely rare
5. **Mythical Items**: Unique one-of-a-kind artifacts

### Guild System Benefits
1. **Shared Resources**: Pool items and currencies
2. **Group Quests**: Multiplayer challenges
3. **Territory Control**: Own and defend land together
4. **Economic Bonuses**: Reduced fees and enhanced rewards
5. **Social Features**: Chat, events, and competitions

This gaming NFT ecosystem provides a foundation for complex game mechanics while maintaining true ownership and tradeable assets.
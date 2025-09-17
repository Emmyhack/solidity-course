# Module 8: NFTs & Digital Assets

Build comprehensive NFT ecosystems including marketplaces, gaming assets, digital art platforms, and advanced NFT mechanics.

##  Module Overview

This module covers the complete NFT ecosystem from basic token standards to complex marketplace mechanics. You'll build production-ready NFT platforms that handle millions in trading volume with advanced features like royalties, fractional ownership, and cross-chain compatibility.

**Duration:** 35-40 hours  
**Difficulty:** Advanced  
**Prerequisites:** Modules 1-7

##  Learning Objectives

By the end of this module, you will be able to:

- Implement ERC-721, ERC-1155, and advanced NFT standards
- Build NFT marketplaces with bidding and auction systems
- Create royalty systems and creator monetization
- Implement fractional NFT ownership (F-NFTs)
- Build gaming NFTs with metadata and upgrades
- Create cross-chain NFT bridges
- Implement dynamic and evolving NFTs
- Build NFT lending and staking protocols
- Design tokenomics for NFT projects
- Handle IPFS and decentralized storage

##  Module Structure

### 8.1 NFT Standards & Implementation (8-10 hours)

- **Topics:** ERC-721, ERC-1155, metadata standards, gas optimization
- **Practice:** Build optimized NFT contracts
- **Files:** `standards/`, NFT implementations

### 8.2 NFT Marketplaces (10-12 hours)

- **Topics:** Trading systems, auctions, bidding, escrow
- **Practice:** Build complete marketplace
- **Files:** `marketplace/`, trading contracts

### 8.3 Advanced NFT Features (8-10 hours)

- **Topics:** Royalties, fractional ownership, dynamic NFTs
- **Practice:** Implement advanced mechanics
- **Files:** `advanced/`, feature contracts

### 8.4 Gaming & Utility NFTs (6-8 hours)

- **Topics:** Gaming assets, upgrades, utility tokens
- **Practice:** Build gaming NFT system
- **Files:** `gaming/`, utility contracts

### 8.5 Cross-Chain & Storage (3-5 hours)

- **Topics:** Cross-chain bridges, IPFS, metadata management
- **Practice:** Deploy multi-chain NFTs
- **Files:** `cross-chain/`, bridge contracts

##  Module Files

```
08-nft-digital-assets/
├── README.md                    # This file
├── standards/
│   ├── README.md               # NFT standards guide
│   ├── OptimizedERC721.sol     # Gas-optimized ERC-721
│   ├── AdvancedERC1155.sol     # Multi-token contract
│   ├── ERC721A.sol             # Batch minting optimization
│   └── CustomStandards.sol     # Custom NFT standards
├── marketplace/
│   ├── README.md               # Marketplace development
│   ├── NFTMarketplace.sol      # Complete marketplace
│   ├── AuctionHouse.sol        # Auction system
│   ├── OfferSystem.sol         # Bidding mechanism
│   └── EscrowContract.sol      # Secure trading
├── advanced/
│   ├── README.md               # Advanced features guide
│   ├── RoyaltyEngine.sol       # Creator royalties
│   ├── FractionalNFT.sol       # F-NFT implementation
│   ├── DynamicNFT.sol          # Evolving metadata
│   └── NFTStaking.sol          # Staking rewards
├── gaming/
│   ├── README.md               # Gaming NFTs guide
│   ├── GameItem.sol            # Gaming assets
│   ├── CharacterNFT.sol        # RPG characters
│   ├── LandNFT.sol             # Virtual land
│   └── UpgradeSystem.sol       # Item upgrades
├── cross-chain/
│   ├── README.md               # Cross-chain guide
│   ├── NFTBridge.sol           # Bridge contract
│   ├── LayerZeroNFT.sol        # LayerZero integration
│   └── IPFSManager.sol         # Metadata storage
├── projects/
│   ├── art-marketplace/        # Digital art platform
│   ├── gaming-ecosystem/       # Complete gaming NFTs
│   ├── music-platform/         # Music NFT platform
│   └── metaverse-assets/       # Virtual world assets
└── assignments/
    ├── nft-collection.md       # Create NFT collection
    ├── marketplace-build.md    # Build marketplace
    ├── gaming-nfts.md          # Gaming asset system
    └── solutions/              # Assignment solutions
```

##  Core NFT Technologies

### 1. Advanced ERC-721 Implementation

```solidity
// Gas-optimized ERC-721 with batch operations
contract OptimizedERC721 is ERC721, Ownable {
    using Strings for uint256;

    struct TokenData {
        address owner;
        uint96 timestamp; // Packed with owner
    }

    mapping(uint256 => TokenData) private _tokenData;
    mapping(address => uint256) private _balances;
    mapping(uint256 => address) private _tokenApprovals;
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    uint256 private _currentIndex;
    string private _baseTokenURI;

    // Batch mint for gas efficiency
    function batchMint(address to, uint256 quantity) external onlyOwner {
        uint256 startTokenId = _currentIndex;
        _balances[to] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = startTokenId + i;
            _tokenData[tokenId] = TokenData({
                owner: to,
                timestamp: uint96(block.timestamp)
            });
            emit Transfer(address(0), to, tokenId);
        }

        _currentIndex += quantity;
    }

    // Gas-optimized ownership lookup
    function ownerOf(uint256 tokenId) public view override returns (address) {
        return _tokenData[tokenId].owner;
    }
}
```

### 2. Comprehensive NFT Marketplace

```solidity
contract NFTMarketplace is ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address paymentToken; // address(0) for ETH
        uint256 deadline;
        bool active;
    }

    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;
        uint256 currentBid;
        address currentBidder;
        uint256 endTime;
        address paymentToken;
        bool active;
    }

    mapping(bytes32 => Listing) public listings;
    mapping(bytes32 => Auction) public auctions;
    mapping(address => mapping(address => uint256)) public offers; // buyer => nft => amount

    uint256 public platformFee = 250; // 2.5%
    address public feeRecipient;

    event ItemListed(bytes32 indexed listingId, address indexed seller, uint256 price);
    event ItemSold(bytes32 indexed listingId, address indexed buyer, uint256 price);
    event AuctionCreated(bytes32 indexed auctionId, address indexed seller, uint256 startPrice);
    event BidPlaced(bytes32 indexed auctionId, address indexed bidder, uint256 amount);

    function listItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken,
        uint256 duration
    ) external {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");
        require(IERC721(nftContract).isApprovedForAll(msg.sender, address(this)), "Not approved");

        bytes32 listingId = keccak256(abi.encodePacked(nftContract, tokenId, block.timestamp));

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            paymentToken: paymentToken,
            deadline: block.timestamp + duration,
            active: true
        });

        emit ItemListed(listingId, msg.sender, price);
    }

    function buyItem(bytes32 listingId) external payable nonReentrant {
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(block.timestamp <= listing.deadline, "Listing expired");

        uint256 totalPrice = listing.price;
        uint256 fee = (totalPrice * platformFee) / 10000;
        uint256 sellerAmount = totalPrice - fee;

        if (listing.paymentToken == address(0)) {
            require(msg.value >= totalPrice, "Insufficient payment");
            payable(listing.seller).transfer(sellerAmount);
            payable(feeRecipient).transfer(fee);
        } else {
            IERC20(listing.paymentToken).safeTransferFrom(msg.sender, listing.seller, sellerAmount);
            IERC20(listing.paymentToken).safeTransferFrom(msg.sender, feeRecipient, fee);
        }

        IERC721(listing.nftContract).safeTransferFrom(listing.seller, msg.sender, listing.tokenId);
        listing.active = false;

        emit ItemSold(listingId, msg.sender, totalPrice);
    }
}
```

### 3. Advanced Royalty System

```solidity
contract RoyaltyEngine is EIP2981 {
    struct RoyaltyInfo {
        address recipient;
        uint256 bps; // Basis points (1/100th of a percent)
    }

    mapping(address => mapping(uint256 => RoyaltyInfo)) private _royalties;
    mapping(address => RoyaltyInfo) private _defaultRoyalties;

    function setTokenRoyalty(
        address nftContract,
        uint256 tokenId,
        address recipient,
        uint256 bps
    ) external {
        require(bps <= 1000, "Royalty too high"); // Max 10%
        _royalties[nftContract][tokenId] = RoyaltyInfo(recipient, bps);
    }

    function royaltyInfo(address nftContract, uint256 tokenId, uint256 salePrice)
        external
        view
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        RoyaltyInfo memory royalty = _royalties[nftContract][tokenId];

        if (royalty.recipient == address(0)) {
            royalty = _defaultRoyalties[nftContract];
        }

        receiver = royalty.recipient;
        royaltyAmount = (salePrice * royalty.bps) / 10000;
    }
}
```

### 4. Fractional NFT Implementation

```solidity
contract FractionalNFT is ERC20, ReentrancyGuard {
    IERC721 public immutable nftContract;
    uint256 public immutable tokenId;
    address public curator;

    uint256 public reservePrice;
    uint256 public auctionEnd;
    address public highestBidder;
    uint256 public highestBid;

    bool public auctionActive;
    bool public redeemed;

    constructor(
        address _nftContract,
        uint256 _tokenId,
        uint256 _supply,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        nftContract = IERC721(_nftContract);
        tokenId = _tokenId;
        curator = msg.sender;
        _mint(msg.sender, _supply);
    }

    function startAuction(uint256 _reservePrice) external {
        require(msg.sender == curator, "Only curator");
        require(!auctionActive, "Auction already active");

        reservePrice = _reservePrice;
        auctionEnd = block.timestamp + 7 days;
        auctionActive = true;
    }

    function bid() external payable {
        require(auctionActive, "No active auction");
        require(block.timestamp < auctionEnd, "Auction ended");
        require(msg.value > highestBid, "Bid too low");
        require(msg.value >= reservePrice, "Below reserve");

        if (highestBidder != address(0)) {
            payable(highestBidder).transfer(highestBid);
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }

    function redeem() external nonReentrant {
        require(auctionActive, "No auction");
        require(block.timestamp >= auctionEnd, "Auction ongoing");
        require(highestBidder == msg.sender, "Not highest bidder");
        require(!redeemed, "Already redeemed");

        redeemed = true;
        nftContract.safeTransferFrom(address(this), msg.sender, tokenId);

        // Distribute proceeds to token holders
        uint256 totalSupply = totalSupply();
        // Implementation for distributing ETH to token holders
    }
}
```

##  Gaming NFT Ecosystem

### Character NFTs with Stats

```solidity
contract GameCharacter is ERC721, VRFConsumerBase {
    struct Character {
        uint256 level;
        uint256 experience;
        uint256 strength;
        uint256 defense;
        uint256 magic;
        uint256 health;
        string class;
        uint256 generation;
    }

    mapping(uint256 => Character) public characters;
    mapping(bytes32 => uint256) private vrfRequests;

    function mintCharacter(address to) external returns (uint256) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        // Request random stats from Chainlink VRF
        bytes32 requestId = requestRandomness(keyHash, fee);
        vrfRequests[requestId] = tokenId;

        _safeMint(to, tokenId);
        return tokenId;
    }

    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        uint256 tokenId = vrfRequests[requestId];

        characters[tokenId] = Character({
            level: 1,
            experience: 0,
            strength: (randomness % 50) + 50,
            defense: ((randomness >> 8) % 50) + 50,
            magic: ((randomness >> 16) % 50) + 50,
            health: ((randomness >> 24) % 50) + 50,
            class: _getRandomClass(randomness),
            generation: 1
        });
    }

    function levelUp(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not owner");
        Character storage character = characters[tokenId];
        require(character.experience >= _getRequiredXP(character.level), "Insufficient XP");

        character.level++;
        character.strength += _getStatIncrease();
        character.defense += _getStatIncrease();
        character.magic += _getStatIncrease();
        character.health += _getStatIncrease();
    }
}
```

##  Cross-Chain NFT Bridge

```solidity
contract NFTBridge {
    using SafeERC20 for IERC20;

    mapping(uint256 => mapping(address => mapping(uint256 => bool))) public bridgedTokens;
    mapping(bytes32 => bool) public processedMessages;

    event TokenBridged(
        address indexed from,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 destinationChain
    );

    function bridgeToken(
        address nftContract,
        uint256 tokenId,
        uint256 destinationChain
    ) external {
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not owner");

        // Lock NFT in bridge contract
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);
        bridgedTokens[destinationChain][nftContract][tokenId] = true;

        emit TokenBridged(msg.sender, nftContract, tokenId, destinationChain);
    }

    function claimToken(
        address nftContract,
        uint256 tokenId,
        uint256 sourceChain,
        bytes32 messageHash,
        bytes calldata signature
    ) external {
        require(!processedMessages[messageHash], "Already processed");
        require(_verifySignature(messageHash, signature), "Invalid signature");

        processedMessages[messageHash] = true;
        IERC721(nftContract).safeTransferFrom(address(this), msg.sender, tokenId);
    }
}
```

##  Real-World Project Examples

### 1. Digital Art Marketplace

- **Artist verification system**
- **Provenance tracking**
- **Edition controls**
- **Collector portfolios**
- **Social features**

### 2. Gaming Ecosystem

- **Character progression**
- **Item crafting system**
- **Guild mechanics**
- **Tournament rewards**
- **Cross-game compatibility**

### 3. Music Platform

- **Artist royalties**
- **Fan engagement**
- **Exclusive content**
- **Streaming rights**
- **Concert tickets**

### 4. Metaverse Assets

- **Virtual real estate**
- **Avatar customization**
- **Building tools**
- **Economic systems**
- **Social interactions**

##  NFT Economics & Tokenomics

### Revenue Models

1. **Primary Sales**: Initial minting fees
2. **Secondary Royalties**: Ongoing creator earnings
3. **Platform Fees**: Marketplace commissions
4. **Staking Rewards**: Utility token distributions
5. **Governance Rights**: DAO participation

### Price Discovery Mechanisms

1. **Fixed Price Sales**: Simple purchasing
2. **Dutch Auctions**: Declining price over time
3. **English Auctions**: Traditional bidding
4. **Bonding Curves**: Algorithmic pricing
5. **Fractionalization**: Shared ownership

##  Analytics & Metrics

### Key Performance Indicators

- **Trading Volume**: Total marketplace activity
- **Floor Price**: Minimum collection price
- **Holder Distribution**: Ownership concentration
- **Royalty Generation**: Creator earnings
- **Cross-Chain Activity**: Multi-network usage

##  Security Considerations

### NFT-Specific Vulnerabilities

1. **Metadata Manipulation**: Centralized storage risks
2. **Reentrancy in Transfers**: ERC-721 callback attacks
3. **Oracle Manipulation**: Price feed attacks
4. **Front-Running**: MEV in auctions
5. **Approval Exploits**: Unlimited approvals

### Best Practices

1. **Decentralized Storage**: Use IPFS for metadata
2. **Reentrancy Guards**: Protect transfer functions
3. **Time Locks**: Delay sensitive operations
4. **Access Controls**: Limit admin functions
5. **Audit Requirements**: Professional security reviews

---

**Ready to build the future of digital ownership?**  Create NFT experiences that captivate users and generate real value!

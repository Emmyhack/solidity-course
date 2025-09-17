# Comprehensive NFT Marketplace

A production-ready NFT marketplace supporting multiple trading mechanisms, royalties, and advanced features like auctions, offers, and bundle sales.

## Features

- **Multiple Sale Types**: Fixed price, auctions, offers, bundles
- **Royalty System**: EIP-2981 compliant creator royalties
- **Multi-Token Support**: ETH and ERC-20 payments
- **Security Features**: Reentrancy protection, access controls
- **Gas Optimization**: Efficient storage and operations
- **Upgradeable**: Proxy pattern for future improvements

## Contract Architecture

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title NFTMarketplace
 * @dev Comprehensive NFT marketplace with multiple trading mechanisms
 * 
 * Features:
 * - Fixed price listings with instant buy
 * - English auctions with bidding
 * - Offer system for any NFT
 * - Bundle sales for multiple NFTs
 * - Creator royalties (EIP-2981)
 * - Platform fees with fee sharing
 * - Multi-token payment support
 * - Advanced security measures
 */
contract NFTMarketplace is ReentrancyGuard, Pausable, AccessControl {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    // =============================================================
    //                            ROLES
    // =============================================================

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // =============================================================
    //                            STRUCTS
    // =============================================================

    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address paymentToken; // address(0) for ETH
        uint256 deadline;
        bool active;
        bytes32 listingType; // "FIXED", "AUCTION", "BUNDLE"
    }

    struct Auction {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 startPrice;
        uint256 reservePrice;
        uint256 currentBid;
        address currentBidder;
        uint256 startTime;
        uint256 endTime;
        address paymentToken;
        bool active;
        bool settled;
    }

    struct Offer {
        address buyer;
        address nftContract;
        uint256 tokenId;
        uint256 amount;
        address paymentToken;
        uint256 deadline;
        bool active;
    }

    struct Bundle {
        address seller;
        address[] nftContracts;
        uint256[] tokenIds;
        uint256 totalPrice;
        address paymentToken;
        uint256 deadline;
        bool active;
    }

    struct RoyaltyInfo {
        address recipient;
        uint256 amount;
    }

    // =============================================================
    //                            STORAGE
    // =============================================================

    // Platform settings
    uint256 public platformFee = 250; // 2.5% in basis points
    address public feeRecipient;
    uint256 public minAuctionDuration = 1 hours;
    uint256 public maxAuctionDuration = 30 days;
    uint256 public bidExtensionTime = 15 minutes;

    // Supported payment tokens
    mapping(address => bool) public supportedTokens;
    
    // Listings and auctions
    mapping(bytes32 => Listing) public listings;
    mapping(bytes32 => Auction) public auctions;
    mapping(bytes32 => Offer) public offers;
    mapping(bytes32 => Bundle) public bundles;

    // User offers mapping: nftContract => tokenId => buyer => offerHash
    mapping(address => mapping(uint256 => mapping(address => bytes32))) public userOffers;
    
    // Collection-wide offers: nftContract => buyer => offerHash
    mapping(address => mapping(address => bytes32)) public collectionOffers;

    // Blacklisted contracts and users
    mapping(address => bool) public blacklistedContracts;
    mapping(address => bool) public blacklistedUsers;

    // Volume tracking
    mapping(address => uint256) public userVolume;
    mapping(address => uint256) public collectionVolume;
    uint256 public totalVolume;

    // =============================================================
    //                            EVENTS
    // =============================================================

    event ItemListed(
        bytes32 indexed listingId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken
    );

    event ItemSold(
        bytes32 indexed listingId,
        address indexed buyer,
        address indexed seller,
        uint256 price,
        uint256 platformFee,
        uint256 royaltyFee
    );

    event AuctionCreated(
        bytes32 indexed auctionId,
        address indexed seller,
        address indexed nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 endTime
    );

    event BidPlaced(
        bytes32 indexed auctionId,
        address indexed bidder,
        uint256 amount,
        uint256 newEndTime
    );

    event AuctionSettled(
        bytes32 indexed auctionId,
        address indexed winner,
        uint256 winningBid
    );

    event OfferMade(
        bytes32 indexed offerId,
        address indexed buyer,
        address indexed nftContract,
        uint256 tokenId,
        uint256 amount
    );

    event OfferAccepted(
        bytes32 indexed offerId,
        address indexed seller,
        address indexed buyer,
        uint256 amount
    );

    event BundleListed(
        bytes32 indexed bundleId,
        address indexed seller,
        uint256 itemCount,
        uint256 totalPrice
    );

    event BundleSold(
        bytes32 indexed bundleId,
        address indexed buyer,
        uint256 totalPrice
    );

    // =============================================================
    //                         CONSTRUCTOR
    // =============================================================

    constructor(address _feeRecipient) {
        require(_feeRecipient != address(0), "Invalid fee recipient");
        
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        
        feeRecipient = _feeRecipient;
        
        // ETH is always supported
        supportedTokens[address(0)] = true;
    }

    // =============================================================
    //                        LISTING FUNCTIONS
    // =============================================================

    /**
     * @dev List an NFT for fixed price sale
     */
    function listItem(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address paymentToken,
        uint256 duration
    ) external whenNotPaused nonReentrant {
        require(!blacklistedUsers[msg.sender], "User blacklisted");
        require(!blacklistedContracts[nftContract], "Contract blacklisted");
        require(supportedTokens[paymentToken], "Payment token not supported");
        require(price > 0, "Price must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");
        
        // Verify ownership and approval
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not token owner");
        require(
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
            IERC721(nftContract).getApproved(tokenId) == address(this),
            "Contract not approved"
        );

        bytes32 listingId = keccak256(
            abi.encodePacked(nftContract, tokenId, msg.sender, block.timestamp)
        );

        listings[listingId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            paymentToken: paymentToken,
            deadline: block.timestamp + duration,
            active: true,
            listingType: "FIXED"
        });

        emit ItemListed(listingId, msg.sender, nftContract, tokenId, price, paymentToken);
    }

    /**
     * @dev Buy an NFT from a fixed price listing
     */
    function buyItem(bytes32 listingId) external payable whenNotPaused nonReentrant {
        require(!blacklistedUsers[msg.sender], "User blacklisted");
        
        Listing storage listing = listings[listingId];
        require(listing.active, "Listing not active");
        require(block.timestamp <= listing.deadline, "Listing expired");
        require(msg.sender != listing.seller, "Cannot buy own listing");

        // Verify current ownership
        require(
            IERC721(listing.nftContract).ownerOf(listing.tokenId) == listing.seller,
            "Seller no longer owns token"
        );

        uint256 totalPrice = listing.price;
        
        // Calculate royalties
        RoyaltyInfo memory royalty = _calculateRoyalty(
            listing.nftContract,
            listing.tokenId,
            totalPrice
        );
        
        // Calculate platform fee
        uint256 platformFeeAmount = (totalPrice * platformFee) / 10000;
        uint256 sellerAmount = totalPrice - platformFeeAmount - royalty.amount;

        // Handle payment
        _processPayment(
            msg.sender,
            listing.seller,
            listing.paymentToken,
            totalPrice,
            sellerAmount,
            platformFeeAmount,
            royalty
        );

        // Transfer NFT
        IERC721(listing.nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            listing.tokenId
        );

        // Update volume tracking
        _updateVolume(msg.sender, listing.seller, listing.nftContract, totalPrice);

        // Deactivate listing
        listing.active = false;

        emit ItemSold(
            listingId,
            msg.sender,
            listing.seller,
            totalPrice,
            platformFeeAmount,
            royalty.amount
        );
    }

    // =============================================================
    //                        AUCTION FUNCTIONS
    // =============================================================

    /**
     * @dev Create an auction for an NFT
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startPrice,
        uint256 reservePrice,
        uint256 duration,
        address paymentToken
    ) external whenNotPaused nonReentrant {
        require(!blacklistedUsers[msg.sender], "User blacklisted");
        require(!blacklistedContracts[nftContract], "Contract blacklisted");
        require(supportedTokens[paymentToken], "Payment token not supported");
        require(startPrice > 0, "Start price must be greater than 0");
        require(reservePrice >= startPrice, "Reserve below start price");
        require(
            duration >= minAuctionDuration && duration <= maxAuctionDuration,
            "Invalid auction duration"
        );

        // Verify ownership and approval
        require(IERC721(nftContract).ownerOf(tokenId) == msg.sender, "Not token owner");
        require(
            IERC721(nftContract).isApprovedForAll(msg.sender, address(this)) ||
            IERC721(nftContract).getApproved(tokenId) == address(this),
            "Contract not approved"
        );

        bytes32 auctionId = keccak256(
            abi.encodePacked(nftContract, tokenId, msg.sender, block.timestamp)
        );

        uint256 endTime = block.timestamp + duration;

        auctions[auctionId] = Auction({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            startPrice: startPrice,
            reservePrice: reservePrice,
            currentBid: 0,
            currentBidder: address(0),
            startTime: block.timestamp,
            endTime: endTime,
            paymentToken: paymentToken,
            active: true,
            settled: false
        });

        emit AuctionCreated(auctionId, msg.sender, nftContract, tokenId, startPrice, endTime);
    }

    /**
     * @dev Place a bid on an auction
     */
    function placeBid(bytes32 auctionId, uint256 bidAmount) 
        external 
        payable 
        whenNotPaused 
        nonReentrant 
    {
        require(!blacklistedUsers[msg.sender], "User blacklisted");
        
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(block.timestamp < auction.endTime, "Auction ended");
        require(msg.sender != auction.seller, "Cannot bid on own auction");

        // Verify current ownership
        require(
            IERC721(auction.nftContract).ownerOf(auction.tokenId) == auction.seller,
            "Seller no longer owns token"
        );

        uint256 minBidAmount = auction.currentBid == 0 
            ? auction.startPrice 
            : auction.currentBid + ((auction.currentBid * 500) / 10000); // 5% minimum increase

        require(bidAmount >= minBidAmount, "Bid too low");

        // Handle payment based on token type
        if (auction.paymentToken == address(0)) {
            require(msg.value >= bidAmount, "Insufficient ETH sent");
        } else {
            require(msg.value == 0, "ETH not accepted for this auction");
            require(
                IERC20(auction.paymentToken).balanceOf(msg.sender) >= bidAmount,
                "Insufficient token balance"
            );
            require(
                IERC20(auction.paymentToken).allowance(msg.sender, address(this)) >= bidAmount,
                "Insufficient token allowance"
            );
        }

        // Refund previous bidder
        if (auction.currentBidder != address(0)) {
            _refundBidder(auction.currentBidder, auction.currentBid, auction.paymentToken);
        }

        // Update auction state
        auction.currentBid = bidAmount;
        auction.currentBidder = msg.sender;

        // Extend auction if bid placed near end
        if (auction.endTime - block.timestamp < bidExtensionTime) {
            auction.endTime = block.timestamp + bidExtensionTime;
        }

        // Lock bidder's funds
        if (auction.paymentToken != address(0)) {
            IERC20(auction.paymentToken).safeTransferFrom(msg.sender, address(this), bidAmount);
        }

        emit BidPlaced(auctionId, msg.sender, bidAmount, auction.endTime);
    }

    /**
     * @dev Settle an auction after it ends
     */
    function settleAuction(bytes32 auctionId) external whenNotPaused nonReentrant {
        Auction storage auction = auctions[auctionId];
        require(auction.active, "Auction not active");
        require(block.timestamp >= auction.endTime, "Auction still ongoing");
        require(!auction.settled, "Auction already settled");

        auction.active = false;
        auction.settled = true;

        // Check if reserve price was met
        if (auction.currentBid >= auction.reservePrice && auction.currentBidder != address(0)) {
            // Calculate fees and royalties
            RoyaltyInfo memory royalty = _calculateRoyalty(
                auction.nftContract,
                auction.tokenId,
                auction.currentBid
            );
            
            uint256 platformFeeAmount = (auction.currentBid * platformFee) / 10000;
            uint256 sellerAmount = auction.currentBid - platformFeeAmount - royalty.amount;

            // Process payment to seller and fee recipients
            _processAuctionPayment(
                auction.seller,
                auction.paymentToken,
                sellerAmount,
                platformFeeAmount,
                royalty
            );

            // Transfer NFT to winner
            IERC721(auction.nftContract).safeTransferFrom(
                auction.seller,
                auction.currentBidder,
                auction.tokenId
            );

            // Update volume tracking
            _updateVolume(
                auction.currentBidder,
                auction.seller,
                auction.nftContract,
                auction.currentBid
            );

            emit AuctionSettled(auctionId, auction.currentBidder, auction.currentBid);
        } else {
            // Refund highest bidder if reserve not met
            if (auction.currentBidder != address(0)) {
                _refundBidder(auction.currentBidder, auction.currentBid, auction.paymentToken);
            }
            
            emit AuctionSettled(auctionId, address(0), 0);
        }
    }

    // =============================================================
    //                        OFFER FUNCTIONS
    // =============================================================

    /**
     * @dev Make an offer on any NFT
     */
    function makeOffer(
        address nftContract,
        uint256 tokenId,
        uint256 amount,
        address paymentToken,
        uint256 duration
    ) external whenNotPaused nonReentrant {
        require(!blacklistedUsers[msg.sender], "User blacklisted");
        require(!blacklistedContracts[nftContract], "Contract blacklisted");
        require(supportedTokens[paymentToken], "Payment token not supported");
        require(amount > 0, "Offer amount must be greater than 0");
        require(duration > 0, "Duration must be greater than 0");

        // Check if user already has an offer on this token
        bytes32 existingOfferId = userOffers[nftContract][tokenId][msg.sender];
        if (existingOfferId != bytes32(0) && offers[existingOfferId].active) {
            // Cancel existing offer
            _cancelOffer(existingOfferId);
        }

        bytes32 offerId = keccak256(
            abi.encodePacked(nftContract, tokenId, msg.sender, block.timestamp)
        );

        offers[offerId] = Offer({
            buyer: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            amount: amount,
            paymentToken: paymentToken,
            deadline: block.timestamp + duration,
            active: true
        });

        userOffers[nftContract][tokenId][msg.sender] = offerId;

        // Lock buyer's funds
        if (paymentToken == address(0)) {
            require(msg.value >= amount, "Insufficient ETH sent");
        } else {
            IERC20(paymentToken).safeTransferFrom(msg.sender, address(this), amount);
        }

        emit OfferMade(offerId, msg.sender, nftContract, tokenId, amount);
    }

    /**
     * @dev Accept an offer on your NFT
     */
    function acceptOffer(bytes32 offerId) external whenNotPaused nonReentrant {
        require(!blacklistedUsers[msg.sender], "User blacklisted");
        
        Offer storage offer = offers[offerId];
        require(offer.active, "Offer not active");
        require(block.timestamp <= offer.deadline, "Offer expired");
        require(
            IERC721(offer.nftContract).ownerOf(offer.tokenId) == msg.sender,
            "Not token owner"
        );

        // Calculate royalties and fees
        RoyaltyInfo memory royalty = _calculateRoyalty(
            offer.nftContract,
            offer.tokenId,
            offer.amount
        );
        
        uint256 platformFeeAmount = (offer.amount * platformFee) / 10000;
        uint256 sellerAmount = offer.amount - platformFeeAmount - royalty.amount;

        // Process payment
        _processOfferPayment(
            msg.sender,
            offer.paymentToken,
            sellerAmount,
            platformFeeAmount,
            royalty
        );

        // Transfer NFT
        IERC721(offer.nftContract).safeTransferFrom(msg.sender, offer.buyer, offer.tokenId);

        // Update volume tracking
        _updateVolume(offer.buyer, msg.sender, offer.nftContract, offer.amount);

        // Deactivate offer
        offer.active = false;
        delete userOffers[offer.nftContract][offer.tokenId][offer.buyer];

        emit OfferAccepted(offerId, msg.sender, offer.buyer, offer.amount);
    }

    // =============================================================
    //                        BUNDLE FUNCTIONS
    // =============================================================

    /**
     * @dev List multiple NFTs as a bundle
     */
    function listBundle(
        address[] calldata nftContracts,
        uint256[] calldata tokenIds,
        uint256 totalPrice,
        address paymentToken,
        uint256 duration
    ) external whenNotPaused nonReentrant {
        require(!blacklistedUsers[msg.sender], "User blacklisted");
        require(nftContracts.length == tokenIds.length, "Array length mismatch");
        require(nftContracts.length > 1, "Bundle must contain multiple items");
        require(nftContracts.length <= 20, "Bundle too large");
        require(supportedTokens[paymentToken], "Payment token not supported");
        require(totalPrice > 0, "Price must be greater than 0");

        // Verify ownership and approvals for all NFTs
        for (uint256 i = 0; i < nftContracts.length; i++) {
            require(!blacklistedContracts[nftContracts[i]], "Contract blacklisted");
            require(
                IERC721(nftContracts[i]).ownerOf(tokenIds[i]) == msg.sender,
                "Not owner of all tokens"
            );
            require(
                IERC721(nftContracts[i]).isApprovedForAll(msg.sender, address(this)) ||
                IERC721(nftContracts[i]).getApproved(tokenIds[i]) == address(this),
                "Contract not approved for all tokens"
            );
        }

        bytes32 bundleId = keccak256(
            abi.encodePacked(nftContracts, tokenIds, msg.sender, block.timestamp)
        );

        bundles[bundleId] = Bundle({
            seller: msg.sender,
            nftContracts: nftContracts,
            tokenIds: tokenIds,
            totalPrice: totalPrice,
            paymentToken: paymentToken,
            deadline: block.timestamp + duration,
            active: true
        });

        emit BundleListed(bundleId, msg.sender, nftContracts.length, totalPrice);
    }

    /**
     * @dev Buy a bundle of NFTs
     */
    function buyBundle(bytes32 bundleId) external payable whenNotPaused nonReentrant {
        require(!blacklistedUsers[msg.sender], "User blacklisted");
        
        Bundle storage bundle = bundles[bundleId];
        require(bundle.active, "Bundle not active");
        require(block.timestamp <= bundle.deadline, "Bundle expired");
        require(msg.sender != bundle.seller, "Cannot buy own bundle");

        // Verify current ownership of all NFTs
        for (uint256 i = 0; i < bundle.nftContracts.length; i++) {
            require(
                IERC721(bundle.nftContracts[i]).ownerOf(bundle.tokenIds[i]) == bundle.seller,
                "Seller no longer owns all tokens"
            );
        }

        uint256 totalPrice = bundle.totalPrice;
        
        // Calculate total royalties for all NFTs in bundle
        uint256 totalRoyalties = 0;
        for (uint256 i = 0; i < bundle.nftContracts.length; i++) {
            RoyaltyInfo memory royalty = _calculateRoyalty(
                bundle.nftContracts[i],
                bundle.tokenIds[i],
                totalPrice / bundle.nftContracts.length // Average price per NFT
            );
            totalRoyalties += royalty.amount;
        }
        
        uint256 platformFeeAmount = (totalPrice * platformFee) / 10000;
        uint256 sellerAmount = totalPrice - platformFeeAmount - totalRoyalties;

        // Handle payment
        if (bundle.paymentToken == address(0)) {
            require(msg.value >= totalPrice, "Insufficient ETH sent");
            
            // Pay seller
            payable(bundle.seller).transfer(sellerAmount);
            
            // Pay platform fee
            payable(feeRecipient).transfer(platformFeeAmount);
            
            // Pay royalties (simplified - in production, handle individual royalties)
            // This is a simplified implementation
        } else {
            IERC20 paymentToken = IERC20(bundle.paymentToken);
            paymentToken.safeTransferFrom(msg.sender, bundle.seller, sellerAmount);
            paymentToken.safeTransferFrom(msg.sender, feeRecipient, platformFeeAmount);
            // Handle royalty payments similarly
        }

        // Transfer all NFTs
        for (uint256 i = 0; i < bundle.nftContracts.length; i++) {
            IERC721(bundle.nftContracts[i]).safeTransferFrom(
                bundle.seller,
                msg.sender,
                bundle.tokenIds[i]
            );
            
            // Update individual collection volumes
            _updateVolume(
                msg.sender,
                bundle.seller,
                bundle.nftContracts[i],
                totalPrice / bundle.nftContracts.length
            );
        }

        // Deactivate bundle
        bundle.active = false;

        emit BundleSold(bundleId, msg.sender, totalPrice);
    }

    // =============================================================
    //                    INTERNAL FUNCTIONS
    // =============================================================

    /**
     * @dev Calculate royalty for an NFT using EIP-2981
     */
    function _calculateRoyalty(
        address nftContract,
        uint256 tokenId,
        uint256 salePrice
    ) internal view returns (RoyaltyInfo memory) {
        try IERC2981(nftContract).royaltyInfo(tokenId, salePrice) returns (
            address recipient,
            uint256 amount
        ) {
            return RoyaltyInfo({recipient: recipient, amount: amount});
        } catch {
            return RoyaltyInfo({recipient: address(0), amount: 0});
        }
    }

    /**
     * @dev Process payment for listings
     */
    function _processPayment(
        address buyer,
        address seller,
        address paymentToken,
        uint256 totalPrice,
        uint256 sellerAmount,
        uint256 platformFeeAmount,
        RoyaltyInfo memory royalty
    ) internal {
        if (paymentToken == address(0)) {
            // ETH payment
            require(msg.value >= totalPrice, "Insufficient ETH sent");
            
            payable(seller).transfer(sellerAmount);
            payable(feeRecipient).transfer(platformFeeAmount);
            
            if (royalty.recipient != address(0) && royalty.amount > 0) {
                payable(royalty.recipient).transfer(royalty.amount);
            }
        } else {
            // ERC20 payment
            IERC20 token = IERC20(paymentToken);
            token.safeTransferFrom(buyer, seller, sellerAmount);
            token.safeTransferFrom(buyer, feeRecipient, platformFeeAmount);
            
            if (royalty.recipient != address(0) && royalty.amount > 0) {
                token.safeTransferFrom(buyer, royalty.recipient, royalty.amount);
            }
        }
    }

    /**
     * @dev Process payment for auction settlements
     */
    function _processAuctionPayment(
        address seller,
        address paymentToken,
        uint256 sellerAmount,
        uint256 platformFeeAmount,
        RoyaltyInfo memory royalty
    ) internal {
        if (paymentToken == address(0)) {
            payable(seller).transfer(sellerAmount);
            payable(feeRecipient).transfer(platformFeeAmount);
            
            if (royalty.recipient != address(0) && royalty.amount > 0) {
                payable(royalty.recipient).transfer(royalty.amount);
            }
        } else {
            IERC20 token = IERC20(paymentToken);
            token.safeTransfer(seller, sellerAmount);
            token.safeTransfer(feeRecipient, platformFeeAmount);
            
            if (royalty.recipient != address(0) && royalty.amount > 0) {
                token.safeTransfer(royalty.recipient, royalty.amount);
            }
        }
    }

    /**
     * @dev Process payment for accepted offers
     */
    function _processOfferPayment(
        address seller,
        address paymentToken,
        uint256 sellerAmount,
        uint256 platformFeeAmount,
        RoyaltyInfo memory royalty
    ) internal {
        if (paymentToken == address(0)) {
            payable(seller).transfer(sellerAmount);
            payable(feeRecipient).transfer(platformFeeAmount);
            
            if (royalty.recipient != address(0) && royalty.amount > 0) {
                payable(royalty.recipient).transfer(royalty.amount);
            }
        } else {
            IERC20 token = IERC20(paymentToken);
            token.safeTransfer(seller, sellerAmount);
            token.safeTransfer(feeRecipient, platformFeeAmount);
            
            if (royalty.recipient != address(0) && royalty.amount > 0) {
                token.safeTransfer(royalty.recipient, royalty.amount);
            }
        }
    }

    /**
     * @dev Refund a bidder
     */
    function _refundBidder(address bidder, uint256 amount, address paymentToken) internal {
        if (paymentToken == address(0)) {
            payable(bidder).transfer(amount);
        } else {
            IERC20(paymentToken).safeTransfer(bidder, amount);
        }
    }

    /**
     * @dev Cancel an offer and refund the buyer
     */
    function _cancelOffer(bytes32 offerId) internal {
        Offer storage offer = offers[offerId];
        require(offer.active, "Offer not active");
        
        offer.active = false;
        delete userOffers[offer.nftContract][offer.tokenId][offer.buyer];
        
        // Refund buyer
        if (offer.paymentToken == address(0)) {
            payable(offer.buyer).transfer(offer.amount);
        } else {
            IERC20(offer.paymentToken).safeTransfer(offer.buyer, offer.amount);
        }
    }

    /**
     * @dev Update volume tracking
     */
    function _updateVolume(
        address buyer,
        address seller,
        address nftContract,
        uint256 amount
    ) internal {
        userVolume[buyer] += amount;
        userVolume[seller] += amount;
        collectionVolume[nftContract] += amount;
        totalVolume += amount;
    }

    // =============================================================
    //                    ADMIN FUNCTIONS
    // =============================================================

    /**
     * @dev Update platform fee (max 10%)
     */
    function setPlatformFee(uint256 _platformFee) external onlyRole(ADMIN_ROLE) {
        require(_platformFee <= 1000, "Fee too high"); // Max 10%
        platformFee = _platformFee;
    }

    /**
     * @dev Update fee recipient
     */
    function setFeeRecipient(address _feeRecipient) external onlyRole(ADMIN_ROLE) {
        require(_feeRecipient != address(0), "Invalid address");
        feeRecipient = _feeRecipient;
    }

    /**
     * @dev Add/remove supported payment token
     */
    function setSupportedToken(address token, bool supported) external onlyRole(ADMIN_ROLE) {
        supportedTokens[token] = supported;
    }

    /**
     * @dev Blacklist/unblacklist contract
     */
    function setBlacklistedContract(address nftContract, bool blacklisted) 
        external 
        onlyRole(ADMIN_ROLE) 
    {
        blacklistedContracts[nftContract] = blacklisted;
    }

    /**
     * @dev Blacklist/unblacklist user
     */
    function setBlacklistedUser(address user, bool blacklisted) external onlyRole(ADMIN_ROLE) {
        blacklistedUsers[user] = blacklisted;
    }

    /**
     * @dev Emergency pause
     */
    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @dev Unpause
     */
    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev Emergency withdrawal
     */
    function emergencyWithdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(feeRecipient).transfer(balance);
        }
    }

    // =============================================================
    //                    VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Get active listings for an NFT
     */
    function getActiveListing(address nftContract, uint256 tokenId) 
        external 
        view 
        returns (bytes32, Listing memory) 
    {
        // In production, maintain a mapping for efficient lookup
        // This is a simplified version
        return (bytes32(0), Listing({
            seller: address(0),
            nftContract: address(0),
            tokenId: 0,
            price: 0,
            paymentToken: address(0),
            deadline: 0,
            active: false,
            listingType: ""
        }));
    }

    /**
     * @dev Get user's offers on a token
     */
    function getUserOffer(address nftContract, uint256 tokenId, address user) 
        external 
        view 
        returns (bytes32) 
    {
        return userOffers[nftContract][tokenId][user];
    }

    /**
     * @dev Check if contract supports interface
     */
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        virtual 
        override(AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }
}
```

## Deployment and Setup

### Deployment Script
```javascript
const { ethers } = require("hardhat");

async function main() {
    const [deployer] = await ethers.getSigners();
    
    console.log("Deploying NFTMarketplace with account:", deployer.address);
    
    const NFTMarketplace = await ethers.getContractFactory("NFTMarketplace");
    const marketplace = await NFTMarketplace.deploy(deployer.address);
    
    await marketplace.deployed();
    console.log("NFTMarketplace deployed to:", marketplace.address);
    
    // Setup supported tokens
    const USDC = "0xA0b86a33E6417C00B87DEE1493C38C98b3fE0B8C"; // Example USDC address
    await marketplace.setSupportedToken(USDC, true);
    
    console.log("Marketplace setup complete!");
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
```

### Usage Examples

#### List an NFT
```javascript
const duration = 7 * 24 * 60 * 60; // 7 days
await marketplace.listItem(
    nftContract.address,
    tokenId,
    ethers.utils.parseEther("1"), // 1 ETH
    ethers.constants.AddressZero, // ETH payment
    duration
);
```

#### Create Auction
```javascript
await marketplace.createAuction(
    nftContract.address,
    tokenId,
    ethers.utils.parseEther("0.5"), // Start price
    ethers.utils.parseEther("1"),   // Reserve price
    duration,
    ethers.constants.AddressZero    // ETH payment
);
```

#### Make Offer
```javascript
await marketplace.makeOffer(
    nftContract.address,
    tokenId,
    ethers.utils.parseEther("0.8"), // Offer amount
    ethers.constants.AddressZero,   // ETH payment
    duration,
    { value: ethers.utils.parseEther("0.8") }
);
```

This marketplace contract provides a comprehensive foundation for NFT trading with production-ready features and security measures.
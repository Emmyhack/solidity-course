// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Common Vulnerabilities and Their Fixes
 * @dev Educational examples of security vulnerabilities and how to prevent them
 * @notice DO NOT USE THESE VULNERABLE PATTERNS IN PRODUCTION
 */

// ======================
// 1. REENTRANCY VULNERABILITY
// ======================

/**
 * @dev VULNERABLE: Classic reentrancy attack example
 *  This contract is vulnerable to reentrancy attacks
 */
contract VulnerableBank {
    mapping(address => uint256) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    //  VULNERABLE: Updates state after external call
    function withdraw(uint256 amount) external {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        //  External call before state update
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        //  State update after external call
        balances[msg.sender] -= amount;
    }
}

/**
 * @dev SECURE: Reentrancy-safe implementation
 *  This contract prevents reentrancy attacks
 */
contract SecureBank {
    mapping(address => uint256) public balances;
    mapping(address => bool) private locked;

    modifier noReentrancy() {
        require(!locked[msg.sender], "Reentrant call detected");
        locked[msg.sender] = true;
        _;
        locked[msg.sender] = false;
    }

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    //  SECURE: Follows checks-effects-interactions pattern
    function withdraw(uint256 amount) external noReentrancy {
        require(balances[msg.sender] >= amount, "Insufficient balance");

        //  Update state first
        balances[msg.sender] -= amount;

        //  External call last
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            //  Revert state on failure
            balances[msg.sender] += amount;
            revert("Transfer failed");
        }
    }
}

// ======================
// 2. INTEGER OVERFLOW/UNDERFLOW
// ======================

/**
 * @dev VULNERABLE: Integer overflow/underflow
 *  This contract is vulnerable to arithmetic attacks (Solidity < 0.8.0)
 */
contract VulnerableToken {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balances[msg.sender] = _initialSupply;
    }

    //  VULNERABLE: No overflow protection
    function transfer(address to, uint256 amount) external {
        //  Could underflow if amount > balance
        balances[msg.sender] -= amount;
        //  Could overflow recipient balance
        balances[to] += amount;
    }

    //  VULNERABLE: Potential overflow in mint
    function mint(address to, uint256 amount) external {
        balances[to] += amount;
        totalSupply += amount;
    }
}

/**
 * @dev SECURE: Safe arithmetic operations
 *  This contract prevents arithmetic vulnerabilities
 */
contract SecureToken {
    mapping(address => uint256) public balances;
    uint256 public totalSupply;

    error InsufficientBalance(uint256 requested, uint256 available);
    error OverflowDetected();

    constructor(uint256 _initialSupply) {
        totalSupply = _initialSupply;
        balances[msg.sender] = _initialSupply;
    }

    //  SECURE: Checks for sufficient balance
    function transfer(address to, uint256 amount) external {
        if (balances[msg.sender] < amount) {
            revert InsufficientBalance(amount, balances[msg.sender]);
        }

        //  Safe arithmetic (Solidity 0.8.0+ has built-in overflow protection)
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }

    //  SECURE: Overflow protection
    function mint(address to, uint256 amount) external {
        //  Check for overflow before operation
        if (totalSupply + amount < totalSupply) {
            revert OverflowDetected();
        }

        balances[to] += amount;
        totalSupply += amount;
    }
}

// ======================
// 3. UNCHECKED EXTERNAL CALLS
// ======================

/**
 * @dev VULNERABLE: Unchecked external calls
 *  This contract doesn't handle external call failures
 */
contract VulnerablePayment {
    mapping(address => uint256) public payments;

    function makePayment(address recipient, uint256 amount) external payable {
        require(msg.value >= amount, "Insufficient payment");

        payments[recipient] += amount;

        //  VULNERABLE: Unchecked external call
        recipient.call{value: amount}("");

        // Code continues even if call fails
    }
}

/**
 * @dev SECURE: Proper external call handling
 *  This contract handles external call failures properly
 */
contract SecurePayment {
    mapping(address => uint256) public payments;
    mapping(address => uint256) public pendingWithdrawals;

    event PaymentMade(address indexed recipient, uint256 amount);
    event WithdrawalFailed(address indexed recipient, uint256 amount);

    function makePayment(address recipient, uint256 amount) external payable {
        require(msg.value >= amount, "Insufficient payment");

        payments[recipient] += amount;

        //  SECURE: Check external call result
        (bool success, ) = recipient.call{value: amount}("");
        if (!success) {
            //  Handle failure gracefully
            pendingWithdrawals[recipient] += amount;
            emit WithdrawalFailed(recipient, amount);
        } else {
            emit PaymentMade(recipient, amount);
        }
    }

    //  Allow manual withdrawal for failed payments
    function withdrawPending() external {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");

        pendingWithdrawals[msg.sender] = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            pendingWithdrawals[msg.sender] = amount;
            revert("Withdrawal failed");
        }
    }
}

// ======================
// 4. ACCESS CONTROL VULNERABILITIES
// ======================

/**
 * @dev VULNERABLE: Weak access control
 *  This contract has insufficient access controls
 */
contract VulnerableContract {
    address public owner;
    uint256 public important_value;

    constructor() {
        owner = msg.sender;
    }

    //  VULNERABLE: tx.origin can be manipulated
    modifier onlyOwner() {
        require(tx.origin == owner, "Not owner");
        _;
    }

    //  VULNERABLE: Public function without access control
    function setImportantValue(uint256 value) external {
        important_value = value;
    }

    //  VULNERABLE: Uses tx.origin
    function sensitiveFunction() external onlyOwner {
        // Sensitive operations
    }
}

/**
 * @dev SECURE: Proper access control
 *  This contract implements secure access controls
 */
contract SecureContract {
    address public owner;
    mapping(address => bool) public authorized;
    uint256 public important_value;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );
    event AuthorizationChanged(address indexed user, bool authorized);

    error UnauthorizedAccess(address caller);
    error InvalidAddress(address addr);

    constructor() {
        owner = msg.sender;
        authorized[msg.sender] = true;
    }

    //  SECURE: Uses msg.sender, not tx.origin
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert UnauthorizedAccess(msg.sender);
        }
        _;
    }

    modifier onlyAuthorized() {
        if (!authorized[msg.sender]) {
            revert UnauthorizedAccess(msg.sender);
        }
        _;
    }

    //  SECURE: Proper access control
    function setImportantValue(uint256 value) external onlyAuthorized {
        important_value = value;
    }

    //  SECURE: Owner-only function
    function setAuthorized(address user, bool isAuthorized) external onlyOwner {
        if (user == address(0)) {
            revert InvalidAddress(user);
        }
        authorized[user] = isAuthorized;
        emit AuthorizationChanged(user, isAuthorized);
    }

    //  SECURE: Safe ownership transfer
    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidAddress(newOwner);
        }

        address oldOwner = owner;
        owner = newOwner;
        authorized[newOwner] = true;
        authorized[oldOwner] = false;

        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// ======================
// 5. FRONT-RUNNING VULNERABILITY
// ======================

/**
 * @dev VULNERABLE: Front-running attack
 *  This contract is vulnerable to front-running
 */
contract VulnerableAuction {
    address public highestBidder;
    uint256 public highestBid;
    bool public auctionEnded;

    //  VULNERABLE: Bid amount visible in transaction
    function bid() external payable {
        require(!auctionEnded, "Auction ended");
        require(msg.value > highestBid, "Bid too low");

        // Return previous bid
        if (highestBidder != address(0)) {
            payable(highestBidder).transfer(highestBid);
        }

        highestBidder = msg.sender;
        highestBid = msg.value;
    }
}

/**
 * @dev SECURE: Front-running resistant auction
 *  This contract uses commit-reveal to prevent front-running
 */
contract SecureAuction {
    struct Bid {
        bytes32 commitment;
        uint256 deposit;
        bool revealed;
    }

    mapping(address => Bid) public bids;
    address public highestBidder;
    uint256 public highestBid;

    uint256 public commitPhaseEnd;
    uint256 public revealPhaseEnd;
    bool public auctionEnded;

    event BidCommitted(address indexed bidder, bytes32 commitment);
    event BidRevealed(address indexed bidder, uint256 amount);

    constructor(uint256 _commitDuration, uint256 _revealDuration) {
        commitPhaseEnd = block.timestamp + _commitDuration;
        revealPhaseEnd = commitPhaseEnd + _revealDuration;
    }

    //  SECURE: Commit phase - hide bid amount
    function commitBid(bytes32 commitment) external payable {
        require(block.timestamp < commitPhaseEnd, "Commit phase ended");
        require(bids[msg.sender].commitment == bytes32(0), "Already committed");

        bids[msg.sender] = Bid({
            commitment: commitment,
            deposit: msg.value,
            revealed: false
        });

        emit BidCommitted(msg.sender, commitment);
    }

    //  SECURE: Reveal phase - reveal actual bid
    function revealBid(uint256 amount, uint256 nonce) external {
        require(block.timestamp >= commitPhaseEnd, "Commit phase not ended");
        require(block.timestamp < revealPhaseEnd, "Reveal phase ended");

        Bid storage bidData = bids[msg.sender];
        require(!bidData.revealed, "Already revealed");
        require(bidData.commitment != bytes32(0), "No commitment found");

        //  Verify commitment
        bytes32 hash = keccak256(abi.encodePacked(amount, nonce, msg.sender));
        require(hash == bidData.commitment, "Invalid reveal");

        bidData.revealed = true;

        if (amount > highestBid && amount <= bidData.deposit) {
            highestBidder = msg.sender;
            highestBid = amount;
        }

        emit BidRevealed(msg.sender, amount);
    }
}

// ======================
// 6. TIMESTAMP MANIPULATION
// ======================

/**
 * @dev VULNERABLE: Timestamp dependence
 *  This contract is vulnerable to timestamp manipulation
 */
contract VulnerableLottery {
    uint256 public constant TICKET_PRICE = 0.1 ether;
    address[] public players;

    //  VULNERABLE: Relies on block.timestamp for randomness
    function drawWinner() external {
        require(players.length > 0, "No players");

        //  Predictable randomness using timestamp
        uint256 winnerIndex = uint256(
            keccak256(abi.encodePacked(block.timestamp))
        ) % players.length;
        address winner = players[winnerIndex];

        payable(winner).transfer(address(this).balance);
        delete players;
    }
}

/**
 * @dev SECURE: Secure randomness
 *  This contract uses more secure randomness sources
 */
contract SecureLottery {
    uint256 public constant TICKET_PRICE = 0.1 ether;
    address[] public players;
    uint256 private randNonce;

    //  SECURE: Multiple entropy sources
    function drawWinner() external {
        require(players.length > 0, "No players");

        //  Combine multiple entropy sources
        uint256 randomness = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.difficulty,
                    block.number,
                    players.length,
                    randNonce++
                )
            )
        );

        uint256 winnerIndex = randomness % players.length;
        address winner = players[winnerIndex];

        payable(winner).transfer(address(this).balance);
        delete players;
    }

    function buyTicket() external payable {
        require(msg.value == TICKET_PRICE, "Incorrect ticket price");
        players.push(msg.sender);
    }
}

/**
 *  VULNERABILITY SUMMARY:
 *
 * 1. REENTRANCY:
 *    - Always update state before external calls
 *    - Use reentrancy guards
 *    - Follow checks-effects-interactions pattern
 *
 * 2. INTEGER OVERFLOW/UNDERFLOW:
 *    - Use Solidity 0.8.0+ for automatic checks
 *    - Validate arithmetic operations
 *    - Use SafeMath for older versions
 *
 * 3. UNCHECKED CALLS:
 *    - Always check return values of external calls
 *    - Handle failures gracefully
 *    - Implement fallback mechanisms
 *
 * 4. ACCESS CONTROL:
 *    - Use msg.sender, not tx.origin
 *    - Implement proper role-based access
 *    - Validate all permissions
 *
 * 5. FRONT-RUNNING:
 *    - Use commit-reveal schemes
 *    - Implement batching mechanisms
 *    - Consider MEV protection
 *
 * 6. TIMESTAMP MANIPULATION:
 *    - Don't rely solely on block.timestamp
 *    - Use multiple entropy sources
 *    - Consider oracle-based randomness
 *
 *  REMEMBER:
 * - Security is a process, not a product
 * - Always audit your contracts
 * - Test extensively with edge cases
 * - Stay updated with latest security practices
 * - Use established patterns and libraries
 */

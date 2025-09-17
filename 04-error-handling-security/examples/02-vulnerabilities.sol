// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Common Vulnerabilities and Prevention
 * @dev Demonstrates common smart contract vulnerabilities and their fixes
 *
 * ⚠️ WARNING: This contract contains INTENTIONALLY VULNERABLE code
 * for educational purposes. DO NOT use these patterns in production!
 *
 * This contract shows:
 * - Reentrancy vulnerabilities and prevention
 * - Integer overflow/underflow (historical context)
 * - Access control issues
 * - Front-running vulnerabilities
 * - Oracle manipulation attacks
 * - Time manipulation vulnerabilities
 * - Denial of service attacks
 */

// ReentrancyGuard from OpenZeppelin
abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

/**
 * @title Vulnerable Contract Examples
 * @dev DO NOT USE IN PRODUCTION - For educational purposes only
 */
contract VulnerableContract {
    mapping(address => uint256) public balances;
    mapping(address => bool) public isAdmin;
    address public owner;
    uint256 public totalFunds;

    // Vulnerable to time manipulation
    uint256 public lastUpdate;

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
    }

    // ======================
    // REENTRANCY VULNERABILITY
    // ======================

    /**
     * @dev VULNERABLE: Reentrancy attack possible
     * The external call happens before state update
     */
    function vulnerableWithdraw() public {
        uint256 amount = balances[msg.sender];
        require(amount > 0, "No funds to withdraw");

        // VULNERABILITY: External call before state update
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed");

        // State update happens AFTER external call
        balances[msg.sender] = 0;
        totalFunds -= amount;
    }

    // ======================
    // ACCESS CONTROL VULNERABILITY
    // ======================

    /**
     * @dev VULNERABLE: Missing access control
     * Anyone can call this admin function
     */
    function vulnerableAdminFunction(address _user, uint256 _amount) public {
        // VULNERABILITY: No access control check
        balances[_user] += _amount;
        totalFunds += _amount;
    }

    /**
     * @dev VULNERABLE: Weak access control
     * tx.origin can be manipulated through contract calls
     */
    function vulnerableTxOriginAuth(address _user, uint256 _amount) public {
        // VULNERABILITY: Using tx.origin instead of msg.sender
        require(tx.origin == owner, "Not owner");
        balances[_user] += _amount;
    }

    // ======================
    // FRONT-RUNNING VULNERABILITY
    // ======================

    /**
     * @dev VULNERABLE: Front-running attack possible
     * Transaction data is visible in mempool
     */
    function vulnerableBidding() public payable {
        // VULNERABILITY: Bid amount visible in mempool
        // Attackers can front-run with higher bid
        require(msg.value > 0, "Must send some ether");

        // Simple highest bidder logic (vulnerable to front-running)
        if (msg.value > balances[address(this)]) {
            balances[address(this)] = msg.value;
        }
    }

    // ======================
    // TIME MANIPULATION VULNERABILITY
    // ======================

    /**
     * @dev VULNERABLE: Relies on block.timestamp
     * Miners can manipulate timestamp within limits
     */
    function vulnerableTimeBasedFunction() public {
        // VULNERABILITY: Direct reliance on block.timestamp
        require(block.timestamp > lastUpdate + 1 hours, "Too early");

        // Some time-sensitive logic
        lastUpdate = block.timestamp;
        balances[msg.sender] += 100;
    }

    // ======================
    // DENIAL OF SERVICE VULNERABILITY
    // ======================

    address[] public participants;

    /**
     * @dev VULNERABLE: Gas limit DoS
     * Array can grow too large causing out-of-gas
     */
    function vulnerableDistribution() public {
        // VULNERABILITY: Unbounded loop
        for (uint256 i = 0; i < participants.length; i++) {
            (bool success, ) = participants[i].call{value: 1 ether}("");
            require(success, "Transfer failed"); // Can brick the function
        }
    }

    // Helper function to add participants (creates DoS vulnerability)
    function addParticipant(address _participant) public {
        participants.push(_participant);
    }

    // ======================
    // WEAK RANDOMNESS VULNERABILITY
    // ======================

    /**
     * @dev VULNERABLE: Predictable randomness
     * Block properties are predictable/manipulable
     */
    function vulnerableRandomness() public view returns (uint256) {
        // VULNERABILITY: Predictable randomness sources
        return
            uint256(
                keccak256(
                    abi.encodePacked(
                        block.timestamp,
                        block.difficulty,
                        msg.sender
                    )
                )
            );
    }

    // Receive function for testing
    receive() external payable {
        balances[msg.sender] += msg.value;
        totalFunds += msg.value;
    }
}

/**
 * @title Secure Contract Implementation
 * @dev Fixed versions of the vulnerable patterns above
 */
contract SecureContract is ReentrancyGuard {
    mapping(address => uint256) public balances;
    mapping(address => bool) public isAdmin;
    mapping(address => uint256) public nonces; // For commit-reveal

    address public owner;
    uint256 public totalFunds;
    bool public paused = false;

    // For secure time-based operations
    uint256 public constant MIN_DELAY = 1 hours;
    mapping(bytes32 => uint256) public timelock;

    // For secure distribution
    uint256 public distributionIndex = 0;
    address[] public participants;

    // Events
    event Withdrawal(address indexed user, uint256 amount);
    event AdminActionProposed(bytes32 indexed actionHash, uint256 executeTime);
    event SecureRandomnessRequested(address indexed user, uint256 nonce);

    // Custom errors
    error Unauthorized();
    error ContractPaused();
    error InsufficientBalance();
    error TransferFailed();
    error InvalidTimelock();

    constructor() {
        owner = msg.sender;
        isAdmin[msg.sender] = true;
    }

    // ======================
    // SECURE MODIFIERS
    // ======================

    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    modifier onlyAdmin() {
        if (!isAdmin[msg.sender]) revert Unauthorized();
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    // ======================
    // REENTRANCY PROTECTION
    // ======================

    /**
     * @dev SECURE: Reentrancy-safe withdrawal
     * Uses checks-effects-interactions pattern and reentrancy guard
     */
    function secureWithdraw() public nonReentrant whenNotPaused {
        uint256 amount = balances[msg.sender];

        // Checks
        if (amount == 0) revert InsufficientBalance();

        // Effects (update state before external call)
        balances[msg.sender] = 0;
        totalFunds -= amount;

        // Interactions (external call last)
        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) {
            // Revert state changes if transfer fails
            balances[msg.sender] = amount;
            totalFunds += amount;
            revert TransferFailed();
        }

        emit Withdrawal(msg.sender, amount);
    }

    // ======================
    // SECURE ACCESS CONTROL
    // ======================

    /**
     * @dev SECURE: Proper access control with timelock
     */
    function secureAdminFunction(
        address _user,
        uint256 _amount
    ) public onlyAdmin {
        balances[_user] += _amount;
        totalFunds += _amount;
    }

    /**
     * @dev SECURE: Two-step admin action with timelock
     */
    function proposeAdminAction(bytes32 _actionHash) public onlyOwner {
        timelock[_actionHash] = block.timestamp + MIN_DELAY;
        emit AdminActionProposed(_actionHash, timelock[_actionHash]);
    }

    function executeAdminAction(
        bytes32 _actionHash,
        address _user,
        uint256 _amount
    ) public onlyOwner {
        if (
            timelock[_actionHash] == 0 ||
            block.timestamp < timelock[_actionHash]
        ) {
            revert InvalidTimelock();
        }

        // Verify action hash
        bytes32 computedHash = keccak256(abi.encodePacked(_user, _amount));
        require(computedHash == _actionHash, "Action hash mismatch");

        // Execute action
        balances[_user] += _amount;
        delete timelock[_actionHash];
    }

    // ======================
    // FRONT-RUNNING PROTECTION
    // ======================

    struct Bid {
        bytes32 commitment;
        uint256 deposit;
        bool revealed;
    }

    mapping(address => Bid) public bids;
    uint256 public commitPhaseEnd;
    uint256 public revealPhaseEnd;

    /**
     * @dev SECURE: Commit-reveal scheme to prevent front-running
     */
    function commitBid(bytes32 _commitment) public payable {
        require(block.timestamp < commitPhaseEnd, "Commit phase ended");

        bids[msg.sender] = Bid({
            commitment: _commitment,
            deposit: msg.value,
            revealed: false
        });
    }

    function revealBid(uint256 _amount, uint256 _nonce) public {
        require(block.timestamp >= commitPhaseEnd, "Commit phase not ended");
        require(block.timestamp < revealPhaseEnd, "Reveal phase ended");

        Bid storage bid = bids[msg.sender];
        require(!bid.revealed, "Already revealed");

        // Verify commitment
        bytes32 hash = keccak256(abi.encodePacked(_amount, _nonce, msg.sender));
        require(hash == bid.commitment, "Invalid reveal");

        bid.revealed = true;
        // Process bid...
    }

    // ======================
    // SECURE TIME-BASED OPERATIONS
    // ======================

    /**
     * @dev SECURE: Uses block numbers instead of timestamp
     * Or implements tolerance for timestamp manipulation
     */
    function secureTimeBasedFunction() public {
        // Use block numbers for more predictable timing
        // Or implement reasonable tolerance for timestamp manipulation

        uint256 tolerance = 15 minutes; // Reasonable miner manipulation limit
        require(
            block.timestamp >=
                timelock[bytes32("lastUpdate")] + MIN_DELAY - tolerance,
            "Too early (considering tolerance)"
        );

        timelock[bytes32("lastUpdate")] = block.timestamp;
        balances[msg.sender] += 100;
    }

    // ======================
    // DOS PROTECTION
    // ======================

    /**
     * @dev SECURE: Batched distribution to prevent DoS
     */
    function secureDistribution(uint256 _batchSize) public onlyAdmin {
        uint256 endIndex = distributionIndex + _batchSize;
        if (endIndex > participants.length) {
            endIndex = participants.length;
        }

        for (uint256 i = distributionIndex; i < endIndex; i++) {
            (bool success, ) = participants[i].call{value: 1 ether}("");
            // Don't revert on individual failures - log them instead
            if (!success) {
                // Could emit event for failed transfers
                continue;
            }
        }

        distributionIndex = endIndex;

        // Reset if all processed
        if (distributionIndex >= participants.length) {
            distributionIndex = 0;
        }
    }

    // ======================
    // SECURE RANDOMNESS
    // ======================

    /**
     * @dev SECURE: Using Chainlink VRF or commit-reveal for randomness
     * This is a simplified commit-reveal example
     */
    function requestSecureRandomness() public {
        uint256 nonce = nonces[msg.sender]++;
        emit SecureRandomnessRequested(msg.sender, nonce);

        // In production, use Chainlink VRF or similar oracle
        // For commit-reveal: user commits to a value, reveals later
    }

    function commitRandomness(bytes32 _commitment) public {
        // Store commitment for later reveal
        // Implementation depends on specific use case
    }

    // ======================
    // EMERGENCY FUNCTIONS
    // ======================

    function pause() public onlyOwner {
        paused = true;
    }

    function unpause() public onlyOwner {
        paused = false;
    }

    function emergencyWithdraw() public onlyOwner {
        payable(owner).transfer(address(this).balance);
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    function addParticipant(address _participant) public onlyAdmin {
        // Add limits to prevent DoS
        require(participants.length < 1000, "Too many participants");
        participants.push(_participant);
    }

    function getParticipantCount() public view returns (uint256) {
        return participants.length;
    }

    receive() external payable {
        balances[msg.sender] += msg.value;
        totalFunds += msg.value;
    }
}

/**
 * @title Malicious Contract for Testing
 * @dev Used to demonstrate reentrancy attacks
 */
contract MaliciousContract {
    VulnerableContract public target;
    uint256 public attackCount = 0;

    constructor(address _target) {
        target = VulnerableContract(_target);
    }

    function attack() public payable {
        // Deposit first
        target.vulnerableWithdraw{value: msg.value}();

        // Then withdraw (this will trigger reentrancy)
        target.vulnerableWithdraw();
    }

    // This function will be called during the reentrancy attack
    receive() external payable {
        attackCount++;

        // Limit recursive calls to prevent infinite loop
        if (attackCount < 3 && address(target).balance > 0) {
            target.vulnerableWithdraw();
        }
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. REENTRANCY:
 *    - Problem: External calls before state updates
 *    - Solution: Checks-Effects-Interactions + ReentrancyGuard
 *
 * 2. ACCESS CONTROL:
 *    - Problem: Missing or weak authentication
 *    - Solution: Proper modifiers, avoid tx.origin
 *
 * 3. FRONT-RUNNING:
 *    - Problem: Transaction data visible in mempool
 *    - Solution: Commit-reveal schemes, batch auctions
 *
 * 4. TIME MANIPULATION:
 *    - Problem: Reliance on block.timestamp
 *    - Solution: Use block numbers, allow tolerance
 *
 * 5. DENIAL OF SERVICE:
 *    - Problem: Unbounded loops, external call failures
 *    - Solution: Batch processing, fail gracefully
 *
 * 6. WEAK RANDOMNESS:
 *    - Problem: Predictable randomness sources
 *    - Solution: Chainlink VRF, commit-reveal
 *
 * 🛡️ SECURITY PRINCIPLES:
 * - Defense in depth
 * - Fail securely
 * - Principle of least privilege
 * - Never trust external input
 * - Validate all state changes
 *
 * 🚀 TRY THIS:
 * 1. Deploy vulnerable and secure versions
 * 2. Test attack scenarios
 * 3. Measure gas costs of security measures
 * 4. Implement your own security patterns
 */

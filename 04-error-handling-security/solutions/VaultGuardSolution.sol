// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title VaultGuard
 * @dev Advanced security implementation for a multi-asset vault
 * @notice This contract demonstrates comprehensive security patterns including:
 *         - Multi-layered access control
 *         - Reentrancy protection
 *         - Rate limiting and withdrawal caps
 *         - Emergency controls and circuit breakers
 *         - Multi-signature requirements for critical operations
 *         - Time-locked withdrawals for large amounts
 *         - Comprehensive audit trails and monitoring
 */
contract VaultGuard is ReentrancyGuard, AccessControl, Pausable {
    using SafeERC20 for IERC20;

    // ============ Constants ============
    bytes32 public constant VAULT_MANAGER_ROLE =
        keccak256("VAULT_MANAGER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    uint256 public constant MAX_WITHDRAWAL_PERCENTAGE = 5000; // 50%
    uint256 public constant LARGE_WITHDRAWAL_THRESHOLD = 100 ether;
    uint256 public constant TIME_LOCK_DURATION = 24 hours;
    uint256 public constant RATE_LIMIT_DURATION = 1 hours;
    uint256 public constant RATE_LIMIT_AMOUNT = 10 ether;

    // ============ Structs ============
    struct UserInfo {
        uint256 balance;
        uint256 lastWithdrawal;
        uint256 withdrawnInPeriod;
        uint256 lockedAmount;
        uint256 unlockTime;
        bool isBlacklisted;
    }

    struct WithdrawalRequest {
        address user;
        uint256 amount;
        uint256 requestTime;
        bool executed;
        bool cancelled;
        uint256 approvals;
        mapping(address => bool) hasApproved;
    }

    struct VaultStats {
        uint256 totalDeposits;
        uint256 totalWithdrawals;
        uint256 totalUsers;
        uint256 maxTotalValue;
        bool emergencyMode;
        uint256 lastAudit;
    }

    // ============ State Variables ============
    mapping(address => UserInfo) public users;
    mapping(uint256 => WithdrawalRequest) public withdrawalRequests;
    mapping(address => bool) public supportedTokens;
    mapping(address => uint256) public tokenBalances;

    VaultStats public vaultStats;

    uint256 public nextRequestId;
    uint256 public requiredApprovals = 2;
    uint256 public emergencyWithdrawalFee = 500; // 5%

    address[] public managers;

    // ============ Events ============
    event Deposit(
        address indexed user,
        address indexed token,
        uint256 amount,
        uint256 timestamp
    );

    event WithdrawalRequested(
        uint256 indexed requestId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event WithdrawalExecuted(
        uint256 indexed requestId,
        address indexed user,
        uint256 amount,
        uint256 timestamp
    );

    event WithdrawalApproved(
        uint256 indexed requestId,
        address indexed approver,
        uint256 timestamp
    );

    event EmergencyWithdrawal(
        address indexed user,
        uint256 amount,
        uint256 fee,
        uint256 timestamp
    );

    event SecurityAlert(
        string alertType,
        address indexed user,
        uint256 amount,
        string description,
        uint256 timestamp
    );

    event VaultConfigChanged(
        string parameter,
        uint256 oldValue,
        uint256 newValue,
        address indexed changer
    );

    // ============ Modifiers ============
    modifier onlyManager() {
        require(
            hasRole(VAULT_MANAGER_ROLE, msg.sender),
            "VaultGuard: Not a manager"
        );
        _;
    }

    modifier onlyEmergency() {
        require(
            hasRole(EMERGENCY_ROLE, msg.sender),
            "VaultGuard: Not emergency role"
        );
        _;
    }

    modifier notBlacklisted(address user) {
        require(!users[user].isBlacklisted, "VaultGuard: User is blacklisted");
        _;
    }

    modifier validToken(address token) {
        require(supportedTokens[token], "VaultGuard: Token not supported");
        _;
    }

    modifier rateLimited(address user, uint256 amount) {
        UserInfo storage userInfo = users[user];

        // Reset rate limit if period has passed
        if (block.timestamp > userInfo.lastWithdrawal + RATE_LIMIT_DURATION) {
            userInfo.withdrawnInPeriod = 0;
        }

        require(
            userInfo.withdrawnInPeriod + amount <= RATE_LIMIT_AMOUNT,
            "VaultGuard: Rate limit exceeded"
        );
        _;
    }

    modifier notInEmergencyMode() {
        require(!vaultStats.emergencyMode, "VaultGuard: Emergency mode active");
        _;
    }

    // ============ Constructor ============
    constructor(address[] memory _initialManagers) {
        require(
            _initialManagers.length >= 2,
            "VaultGuard: Need at least 2 managers"
        );

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);

        for (uint256 i = 0; i < _initialManagers.length; i++) {
            _grantRole(VAULT_MANAGER_ROLE, _initialManagers[i]);
            managers.push(_initialManagers[i]);
        }

        vaultStats.maxTotalValue = 1000 ether; // Initial max vault value
        vaultStats.lastAudit = block.timestamp;
    }

    // ============ Deposit Functions ============

    /**
     * @dev Deposit ETH into the vault
     */
    function depositETH()
        external
        payable
        nonReentrant
        whenNotPaused
        notBlacklisted(msg.sender)
        notInEmergencyMode
    {
        require(msg.value > 0, "VaultGuard: Cannot deposit 0");
        require(
            address(this).balance <= vaultStats.maxTotalValue,
            "VaultGuard: Vault capacity exceeded"
        );

        UserInfo storage userInfo = users[msg.sender];

        // First-time user
        if (userInfo.balance == 0) {
            vaultStats.totalUsers++;
        }

        userInfo.balance += msg.value;
        vaultStats.totalDeposits += msg.value;
        tokenBalances[address(0)] += msg.value; // ETH represented as address(0)

        emit Deposit(msg.sender, address(0), msg.value, block.timestamp);

        // Security monitoring
        if (msg.value > LARGE_WITHDRAWAL_THRESHOLD) {
            emit SecurityAlert(
                "LARGE_DEPOSIT",
                msg.sender,
                msg.value,
                "Large deposit detected",
                block.timestamp
            );
        }
    }

    /**
     * @dev Deposit ERC20 tokens into the vault
     * @param token The ERC20 token address
     * @param amount The amount to deposit
     */
    function depositToken(
        address token,
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        notBlacklisted(msg.sender)
        validToken(token)
        notInEmergencyMode
    {
        require(amount > 0, "VaultGuard: Cannot deposit 0");

        UserInfo storage userInfo = users[msg.sender];

        // First-time user
        if (userInfo.balance == 0) {
            vaultStats.totalUsers++;
        }

        // Transfer tokens from user
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        userInfo.balance += amount;
        vaultStats.totalDeposits += amount;
        tokenBalances[token] += amount;

        emit Deposit(msg.sender, token, amount, block.timestamp);
    }

    // ============ Withdrawal Functions ============

    /**
     * @dev Request a withdrawal (for amounts above threshold)
     * @param amount The amount to withdraw
     */
    function requestWithdrawal(
        uint256 amount
    )
        external
        nonReentrant
        whenNotPaused
        notBlacklisted(msg.sender)
        rateLimited(msg.sender, amount)
        returns (uint256 requestId)
    {
        UserInfo storage userInfo = users[msg.sender];
        require(userInfo.balance >= amount, "VaultGuard: Insufficient balance");
        require(amount > 0, "VaultGuard: Cannot withdraw 0");

        // Large withdrawals require multi-sig approval
        if (amount >= LARGE_WITHDRAWAL_THRESHOLD) {
            requestId = nextRequestId++;
            WithdrawalRequest storage request = withdrawalRequests[requestId];

            request.user = msg.sender;
            request.amount = amount;
            request.requestTime = block.timestamp;

            // Lock the funds
            userInfo.lockedAmount += amount;
            userInfo.unlockTime = block.timestamp + TIME_LOCK_DURATION;

            emit WithdrawalRequested(
                requestId,
                msg.sender,
                amount,
                block.timestamp
            );

            emit SecurityAlert(
                "LARGE_WITHDRAWAL_REQUEST",
                msg.sender,
                amount,
                "Large withdrawal request requires approval",
                block.timestamp
            );

            return requestId;
        } else {
            // Small withdrawals can be executed immediately
            _executeWithdrawal(msg.sender, amount);
            return type(uint256).max; // Indicate immediate execution
        }
    }

    /**
     * @dev Approve a withdrawal request
     * @param requestId The withdrawal request ID
     */
    function approveWithdrawal(
        uint256 requestId
    ) external onlyManager nonReentrant {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        require(request.user != address(0), "VaultGuard: Invalid request");
        require(!request.executed, "VaultGuard: Already executed");
        require(!request.cancelled, "VaultGuard: Request cancelled");
        require(
            !request.hasApproved[msg.sender],
            "VaultGuard: Already approved"
        );

        request.hasApproved[msg.sender] = true;
        request.approvals++;

        emit WithdrawalApproved(requestId, msg.sender, block.timestamp);

        // Execute if enough approvals
        if (request.approvals >= requiredApprovals) {
            _executeWithdrawalRequest(requestId);
        }
    }

    /**
     * @dev Execute an approved withdrawal request
     * @param requestId The withdrawal request ID
     */
    function executeWithdrawal(
        uint256 requestId
    ) external nonReentrant whenNotPaused {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        require(request.user == msg.sender, "VaultGuard: Not your request");
        require(
            request.approvals >= requiredApprovals,
            "VaultGuard: Not enough approvals"
        );
        require(
            block.timestamp >= request.requestTime + TIME_LOCK_DURATION,
            "VaultGuard: Time lock not expired"
        );

        _executeWithdrawalRequest(requestId);
    }

    /**
     * @dev Emergency withdrawal with fee
     * @param amount The amount to withdraw
     */
    function emergencyWithdraw(
        uint256 amount
    ) external nonReentrant notBlacklisted(msg.sender) {
        UserInfo storage userInfo = users[msg.sender];
        require(userInfo.balance >= amount, "VaultGuard: Insufficient balance");
        require(amount > 0, "VaultGuard: Cannot withdraw 0");

        // Calculate emergency fee
        uint256 fee = (amount * emergencyWithdrawalFee) / 10000;
        uint256 withdrawAmount = amount - fee;

        userInfo.balance -= amount;
        vaultStats.totalWithdrawals += amount;

        // Transfer amount minus fee
        (bool success, ) = payable(msg.sender).call{value: withdrawAmount}("");
        require(success, "VaultGuard: Transfer failed");

        emit EmergencyWithdrawal(
            msg.sender,
            withdrawAmount,
            fee,
            block.timestamp
        );

        emit SecurityAlert(
            "EMERGENCY_WITHDRAWAL",
            msg.sender,
            amount,
            "Emergency withdrawal executed with fee",
            block.timestamp
        );
    }

    // ============ Internal Functions ============

    /**
     * @dev Internal function to execute a withdrawal
     * @param user The user address
     * @param amount The amount to withdraw
     */
    function _executeWithdrawal(address user, uint256 amount) internal {
        UserInfo storage userInfo = users[user];

        userInfo.balance -= amount;
        userInfo.lastWithdrawal = block.timestamp;
        userInfo.withdrawnInPeriod += amount;
        vaultStats.totalWithdrawals += amount;

        (bool success, ) = payable(user).call{value: amount}("");
        require(success, "VaultGuard: Transfer failed");

        emit WithdrawalExecuted(
            type(uint256).max,
            user,
            amount,
            block.timestamp
        );
    }

    /**
     * @dev Internal function to execute a withdrawal request
     * @param requestId The withdrawal request ID
     */
    function _executeWithdrawalRequest(uint256 requestId) internal {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        UserInfo storage userInfo = users[request.user];

        require(!request.executed, "VaultGuard: Already executed");

        request.executed = true;
        userInfo.balance -= request.amount;
        userInfo.lockedAmount -= request.amount;
        vaultStats.totalWithdrawals += request.amount;

        (bool success, ) = payable(request.user).call{value: request.amount}(
            ""
        );
        require(success, "VaultGuard: Transfer failed");

        emit WithdrawalExecuted(
            requestId,
            request.user,
            request.amount,
            block.timestamp
        );
    }

    // ============ Management Functions ============

    /**
     * @dev Add support for a new token
     * @param token The token address to add
     */
    function addSupportedToken(address token) external onlyManager {
        require(token != address(0), "VaultGuard: Invalid token address");
        require(!supportedTokens[token], "VaultGuard: Token already supported");

        supportedTokens[token] = true;

        emit VaultConfigChanged("SUPPORTED_TOKEN_ADDED", 0, 1, msg.sender);
    }

    /**
     * @dev Remove support for a token
     * @param token The token address to remove
     */
    function removeSupportedToken(address token) external onlyManager {
        require(supportedTokens[token], "VaultGuard: Token not supported");
        require(
            tokenBalances[token] == 0,
            "VaultGuard: Token balance not zero"
        );

        supportedTokens[token] = false;

        emit VaultConfigChanged("SUPPORTED_TOKEN_REMOVED", 1, 0, msg.sender);
    }

    /**
     * @dev Set required approvals for large withdrawals
     * @param _requiredApprovals The new required approval count
     */
    function setRequiredApprovals(
        uint256 _requiredApprovals
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_requiredApprovals > 0, "VaultGuard: Invalid approval count");
        require(
            _requiredApprovals <= managers.length,
            "VaultGuard: Too many required approvals"
        );

        uint256 oldValue = requiredApprovals;
        requiredApprovals = _requiredApprovals;

        emit VaultConfigChanged(
            "REQUIRED_APPROVALS",
            oldValue,
            _requiredApprovals,
            msg.sender
        );
    }

    /**
     * @dev Blacklist a user
     * @param user The user to blacklist
     */
    function blacklistUser(address user) external onlyManager {
        require(!users[user].isBlacklisted, "VaultGuard: Already blacklisted");

        users[user].isBlacklisted = true;

        emit SecurityAlert(
            "USER_BLACKLISTED",
            user,
            0,
            "User has been blacklisted",
            block.timestamp
        );
    }

    /**
     * @dev Remove user from blacklist
     * @param user The user to remove from blacklist
     */
    function removeFromBlacklist(
        address user
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(users[user].isBlacklisted, "VaultGuard: Not blacklisted");

        users[user].isBlacklisted = false;

        emit SecurityAlert(
            "USER_REMOVED_FROM_BLACKLIST",
            user,
            0,
            "User removed from blacklist",
            block.timestamp
        );
    }

    // ============ Emergency Functions ============

    /**
     * @dev Activate emergency mode
     */
    function activateEmergencyMode() external onlyEmergency {
        vaultStats.emergencyMode = true;
        _pause();

        emit SecurityAlert(
            "EMERGENCY_MODE_ACTIVATED",
            msg.sender,
            0,
            "Emergency mode has been activated",
            block.timestamp
        );
    }

    /**
     * @dev Deactivate emergency mode
     */
    function deactivateEmergencyMode() external onlyRole(DEFAULT_ADMIN_ROLE) {
        vaultStats.emergencyMode = false;
        _unpause();

        emit SecurityAlert(
            "EMERGENCY_MODE_DEACTIVATED",
            msg.sender,
            0,
            "Emergency mode has been deactivated",
            block.timestamp
        );
    }

    /**
     * @dev Emergency drain function (only in extreme circumstances)
     * @param token The token to drain (address(0) for ETH)
     * @param to The address to send funds to
     */
    function emergencyDrain(
        address token,
        address to
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(vaultStats.emergencyMode, "VaultGuard: Not in emergency mode");
        require(to != address(0), "VaultGuard: Invalid recipient");

        if (token == address(0)) {
            // Drain ETH
            uint256 balance = address(this).balance;
            (bool success, ) = payable(to).call{value: balance}("");
            require(success, "VaultGuard: ETH transfer failed");
        } else {
            // Drain ERC20
            uint256 balance = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(to, balance);
        }

        emit SecurityAlert(
            "EMERGENCY_DRAIN",
            to,
            token == address(0)
                ? address(this).balance
                : IERC20(token).balanceOf(address(this)),
            "Emergency drain executed",
            block.timestamp
        );
    }

    // ============ View Functions ============

    /**
     * @dev Get user information
     * @param user The user address
     * @return User information struct
     */
    function getUserInfo(address user) external view returns (UserInfo memory) {
        return users[user];
    }

    /**
     * @dev Get withdrawal request information
     * @param requestId The request ID
     * @return Basic request information
     */
    function getWithdrawalRequest(
        uint256 requestId
    )
        external
        view
        returns (
            address user,
            uint256 amount,
            uint256 requestTime,
            bool executed,
            bool cancelled,
            uint256 approvals
        )
    {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        return (
            request.user,
            request.amount,
            request.requestTime,
            request.executed,
            request.cancelled,
            request.approvals
        );
    }

    /**
     * @dev Get vault statistics
     * @return Vault statistics struct
     */
    function getVaultStats() external view returns (VaultStats memory) {
        return vaultStats;
    }

    /**
     * @dev Get total vault value
     * @return Total value in ETH equivalent
     */
    function getTotalVaultValue() external view returns (uint256) {
        return address(this).balance; // Simplified - in real implementation would include token values
    }

    /**
     * @dev Check if withdrawal request is ready for execution
     * @param requestId The request ID
     * @return Whether the request can be executed
     */
    function isWithdrawalReady(uint256 requestId) external view returns (bool) {
        WithdrawalRequest storage request = withdrawalRequests[requestId];
        return (!request.executed &&
            !request.cancelled &&
            request.approvals >= requiredApprovals &&
            block.timestamp >= request.requestTime + TIME_LOCK_DURATION);
    }

    // ============ Receive Function ============

    receive() external payable {
        // Allow direct ETH deposits
        if (msg.value > 0) {
            users[msg.sender].balance += msg.value;
            vaultStats.totalDeposits += msg.value;
            emit Deposit(msg.sender, address(0), msg.value, block.timestamp);
        }
    }
}

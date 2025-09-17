// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Custom Modifiers & Access Control
 * @dev Advanced patterns for access control and custom modifiers
 *
 * This contract demonstrates:
 * - Custom modifier creation
 * - Modifier parameters and logic
 * - Role-based access control
 * - Time-based restrictions
 * - Reentrancy protection
 * - Conditional modifiers
 */

contract ModifiersAndAccessControl {
    // ======================
    // STATE VARIABLES
    // ======================

    address public owner;
    uint256 public contractCreationTime;
    bool private _locked = false;

    // Role-based access control
    mapping(address => bool) public admins;
    mapping(address => bool) public moderators;
    mapping(address => bool) public users;

    // Time-based restrictions
    mapping(address => uint256) public lastAction;
    uint256 public constant COOLDOWN_PERIOD = 1 hours;

    // Feature flags
    bool public emergencyPaused = false;
    bool public maintenanceMode = false;

    // ======================
    // EVENTS
    // ======================

    event RoleGranted(address indexed account, string role);
    event RoleRevoked(address indexed account, string role);
    event EmergencyPauseToggled(bool paused);
    event MaintenanceModeToggled(bool enabled);
    event ActionPerformed(address indexed user, string action);

    // ======================
    // BASIC MODIFIERS
    // ======================

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyAdmin() {
        require(
            admins[msg.sender] || msg.sender == owner,
            "Only admin can call this function"
        );
        _;
    }

    modifier onlyModerator() {
        require(
            moderators[msg.sender] || admins[msg.sender] || msg.sender == owner,
            "Only moderator or higher can call this function"
        );
        _;
    }

    modifier onlyUser() {
        require(
            users[msg.sender] ||
                moderators[msg.sender] ||
                admins[msg.sender] ||
                msg.sender == owner,
            "Only registered user can call this function"
        );
        _;
    }

    // ======================
    // CONDITIONAL MODIFIERS
    // ======================

    modifier whenNotPaused() {
        require(!emergencyPaused, "Contract is paused");
        _;
    }

    modifier whenNotInMaintenance() {
        require(!maintenanceMode, "Contract is in maintenance mode");
        _;
    }

    modifier onlyAfterTime(uint256 _time) {
        require(block.timestamp >= _time, "Function called too early");
        _;
    }

    modifier onlyBeforeTime(uint256 _time) {
        require(block.timestamp <= _time, "Function called too late");
        _;
    }

    // ======================
    // PARAMETRIC MODIFIERS
    // ======================

    modifier minimumAmount(uint256 _amount, uint256 _minimum) {
        require(_amount >= _minimum, "Amount below minimum required");
        _;
    }

    modifier maximumAmount(uint256 _amount, uint256 _maximum) {
        require(_amount <= _maximum, "Amount above maximum allowed");
        _;
    }

    modifier validAddress(address _addr) {
        require(_addr != address(0), "Invalid address: zero address");
        require(_addr != address(this), "Invalid address: contract address");
        _;
    }

    modifier onlyEOA() {
        require(
            msg.sender == tx.origin,
            "Only externally owned accounts allowed"
        );
        _;
    }

    // ======================
    // TIME-BASED MODIFIERS
    // ======================

    modifier cooldownPassed() {
        require(
            block.timestamp >= lastAction[msg.sender] + COOLDOWN_PERIOD,
            "Cooldown period not passed"
        );
        _;
        lastAction[msg.sender] = block.timestamp;
    }

    modifier onlyDuringBusinessHours() {
        uint256 hour = (block.timestamp / 3600) % 24;
        require(
            hour >= 9 && hour <= 17,
            "Function only available during business hours (9-17 UTC)"
        );
        _;
    }

    modifier onlyOnWeekdays() {
        uint256 dayOfWeek = ((block.timestamp / 86400) + 4) % 7; // 0 = Monday
        require(dayOfWeek < 5, "Function only available on weekdays");
        _;
    }

    // ======================
    // REENTRANCY PROTECTION
    // ======================

    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ======================
    // ADVANCED MODIFIERS
    // ======================

    modifier costBasedAccess(uint256 _cost) {
        require(msg.value >= _cost, "Insufficient payment");
        _;

        // Refund excess payment
        if (msg.value > _cost) {
            payable(msg.sender).transfer(msg.value - _cost);
        }
    }

    modifier onlyIfBalanceAbove(uint256 _minBalance) {
        require(
            address(this).balance >= _minBalance,
            "Contract balance too low"
        );
        _;
    }

    modifier rateLimited(uint256 _maxCallsPerHour) {
        // Simplified rate limiting (in production, use more sophisticated tracking)
        require(
            block.timestamp >=
                lastAction[msg.sender] + (3600 / _maxCallsPerHour),
            "Rate limit exceeded"
        );
        _;
        lastAction[msg.sender] = block.timestamp;
    }

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor() {
        owner = msg.sender;
        contractCreationTime = block.timestamp;
        admins[msg.sender] = true;
        moderators[msg.sender] = true;
        users[msg.sender] = true;

        emit RoleGranted(msg.sender, "owner");
        emit RoleGranted(msg.sender, "admin");
        emit RoleGranted(msg.sender, "moderator");
        emit RoleGranted(msg.sender, "user");
    }

    // ======================
    // ROLE MANAGEMENT
    // ======================

    function grantAdminRole(
        address _account
    ) public onlyOwner validAddress(_account) {
        require(!admins[_account], "Account already has admin role");
        admins[_account] = true;
        moderators[_account] = true; // Admins are also moderators
        users[_account] = true; // Admins are also users

        emit RoleGranted(_account, "admin");
    }

    function revokeAdminRole(
        address _account
    ) public onlyOwner validAddress(_account) {
        require(_account != owner, "Cannot revoke owner's admin role");
        require(admins[_account], "Account does not have admin role");
        admins[_account] = false;

        emit RoleRevoked(_account, "admin");
    }

    function grantModeratorRole(
        address _account
    ) public onlyAdmin validAddress(_account) {
        require(!moderators[_account], "Account already has moderator role");
        moderators[_account] = true;
        users[_account] = true; // Moderators are also users

        emit RoleGranted(_account, "moderator");
    }

    function revokeModeratorRole(
        address _account
    ) public onlyAdmin validAddress(_account) {
        require(moderators[_account], "Account does not have moderator role");
        require(!admins[_account], "Cannot revoke admin's moderator role");
        moderators[_account] = false;

        emit RoleRevoked(_account, "moderator");
    }

    function grantUserRole(
        address _account
    ) public onlyModerator validAddress(_account) {
        require(!users[_account], "Account already has user role");
        users[_account] = true;

        emit RoleGranted(_account, "user");
    }

    function revokeUserRole(
        address _account
    ) public onlyModerator validAddress(_account) {
        require(users[_account], "Account does not have user role");
        require(!moderators[_account], "Cannot revoke moderator's user role");
        users[_account] = false;

        emit RoleRevoked(_account, "user");
    }

    // ======================
    // EXAMPLE FUNCTIONS USING MODIFIERS
    // ======================

    function adminFunction()
        public
        onlyAdmin
        whenNotPaused
        whenNotInMaintenance
    {
        emit ActionPerformed(msg.sender, "admin function");
    }

    function userFunction()
        public
        onlyUser
        whenNotPaused
        cooldownPassed
        onlyEOA
    {
        emit ActionPerformed(msg.sender, "user function");
    }

    function expensiveFunction()
        public
        payable
        onlyUser
        costBasedAccess(0.1 ether)
        rateLimited(5) // Max 5 calls per hour
    {
        emit ActionPerformed(msg.sender, "expensive function");
    }

    function businessHoursFunction()
        public
        onlyUser
        onlyDuringBusinessHours
        onlyOnWeekdays
    {
        emit ActionPerformed(msg.sender, "business hours function");
    }

    function timeRestrictedFunction()
        public
        onlyAdmin
        onlyAfterTime(contractCreationTime + 1 days)
        onlyBeforeTime(contractCreationTime + 30 days)
    {
        emit ActionPerformed(msg.sender, "time restricted function");
    }

    function amountRestrictedFunction(
        uint256 _amount
    )
        public
        onlyUser
        minimumAmount(_amount, 100)
        maximumAmount(_amount, 10000)
    {
        emit ActionPerformed(msg.sender, "amount restricted function");
    }

    function reentrancyProtectedFunction()
        public
        onlyUser
        nonReentrant
        onlyIfBalanceAbove(1 ether)
    {
        // Simulate external call that could cause reentrancy
        payable(msg.sender).transfer(0.1 ether);
        emit ActionPerformed(msg.sender, "reentrancy protected function");
    }

    // ======================
    // EMERGENCY CONTROLS
    // ======================

    function toggleEmergencyPause() public onlyOwner {
        emergencyPaused = !emergencyPaused;
        emit EmergencyPauseToggled(emergencyPaused);
    }

    function toggleMaintenanceMode() public onlyOwner {
        maintenanceMode = !maintenanceMode;
        emit MaintenanceModeToggled(maintenanceMode);
    }

    // ======================
    // UTILITY FUNCTIONS
    // ======================

    function getUserRoles(
        address _account
    )
        public
        view
        returns (bool isOwner, bool isAdmin, bool isModerator, bool isUser)
    {
        return (
            _account == owner,
            admins[_account],
            moderators[_account],
            users[_account]
        );
    }

    function getContractStatus()
        public
        view
        returns (
            bool isPaused,
            bool inMaintenance,
            uint256 creationTime,
            uint256 currentTime
        )
    {
        return (
            emergencyPaused,
            maintenanceMode,
            contractCreationTime,
            block.timestamp
        );
    }

    // Function to receive Ether
    receive() external payable {}

    // Withdraw function for owner
    function withdraw(uint256 _amount) public onlyOwner {
        require(
            address(this).balance >= _amount,
            "Insufficient contract balance"
        );
        payable(owner).transfer(_amount);
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. MODIFIER STRUCTURE:
 *    - Code before _; executes before function
 *    - Code after _; executes after function
 *    - Multiple modifiers execute in order
 *
 * 2. PARAMETRIC MODIFIERS:
 *    - Can accept parameters for dynamic behavior
 *    - Useful for validation and conditional logic
 *    - Keep logic simple for gas efficiency
 *
 * 3. ROLE-BASED ACCESS:
 *    - Hierarchical permissions (Owner > Admin > Moderator > User)
 *    - Granular control over function access
 *    - Easy to manage and audit
 *
 * 4. TIME-BASED CONTROLS:
 *    - Cooldowns prevent spam
 *    - Business hours restrict operation times
 *    - Time windows for specific actions
 *
 * 5. SECURITY PATTERNS:
 *    - Reentrancy protection with locks
 *    - Emergency pause for crisis management
 *    - EOA-only restrictions for sensitive functions
 *
 * 🚀 TRY THIS:
 * 1. Create custom modifiers for your use case
 * 2. Combine multiple modifiers on functions
 * 3. Test time-based restrictions
 * 4. Implement your own access control system
 */

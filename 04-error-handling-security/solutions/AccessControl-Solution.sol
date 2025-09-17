// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title AccessControl Implementation - Complete Solution
 * @dev Comprehensive access control system with multiple roles and permissions
 * @notice This demonstrates production-ready access control patterns
 *
 * Features Implemented:
 * - Hierarchical role system
 * - Time-based role assignments
 * - Role delegation and voting
 * - Emergency role management
 * - Audit trail and logging
 * - Role-specific function restrictions
 */
contract AccessControlSolution is AccessControl, Pausable, ReentrancyGuard {
    using Address for address;

    // ======================
    // ROLES DEFINITION
    // ======================

    bytes32 public constant SUPER_ADMIN_ROLE = keccak256("SUPER_ADMIN_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    bytes32 public constant MODERATOR_ROLE = keccak256("MODERATOR_ROLE");
    bytes32 public constant USER_ROLE = keccak256("USER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");

    // ======================
    // STRUCTS
    // ======================

    struct RoleAssignment {
        address account;
        bytes32 role;
        uint256 assignedAt;
        uint256 expiresAt;
        address assignedBy;
        bool isActive;
        string reason;
    }

    struct RoleVoting {
        bytes32 role;
        address candidate;
        address[] voters;
        mapping(address => bool) hasVoted;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 startTime;
        uint256 endTime;
        bool executed;
        bool approved;
    }

    struct UserProfile {
        string name;
        string email;
        uint256 joinedAt;
        uint256 lastActivity;
        bool isActive;
        bytes32[] roles;
        uint256 actionsCount;
        uint256 reputation;
    }

    // ======================
    // STATE VARIABLES
    // ======================

    mapping(bytes32 => mapping(address => RoleAssignment))
        public roleAssignments;
    mapping(address => UserProfile) public userProfiles;
    mapping(uint256 => RoleVoting) public roleVotings;
    mapping(bytes32 => uint256) public roleVotingThreshold;
    mapping(bytes32 => uint256) public roleMaxDuration;
    mapping(address => uint256[]) public userVotings;

    uint256 public nextVotingId = 1;
    uint256 public defaultVotingDuration = 7 days;
    uint256 public emergencyVotingDuration = 24 hours;

    bool public emergencyMode;
    uint256 public emergencyActivatedAt;
    address public emergencyActivator;

    // Audit trail
    struct AuditLog {
        address actor;
        bytes32 action;
        bytes32 role;
        address target;
        uint256 timestamp;
        string details;
    }

    AuditLog[] public auditLogs;
    mapping(address => uint256[]) public userAuditLogs;

    // ======================
    // EVENTS
    // ======================

    event RoleAssignmentCreated(
        bytes32 indexed role,
        address indexed account,
        address indexed assignedBy,
        uint256 expiresAt,
        string reason
    );

    event RoleVotingStarted(
        uint256 indexed votingId,
        bytes32 indexed role,
        address indexed candidate,
        uint256 endTime
    );

    event RoleVoteCast(
        uint256 indexed votingId,
        address indexed voter,
        bool support,
        string reason
    );

    event RoleVotingExecuted(
        uint256 indexed votingId,
        bool approved,
        uint256 votesFor,
        uint256 votesAgainst
    );

    event EmergencyModeToggled(
        bool active,
        address indexed activator,
        uint256 timestamp
    );

    event UserProfileUpdated(address indexed user, string name, string email);

    event ActionLogged(
        address indexed actor,
        bytes32 action,
        bytes32 role,
        address target,
        string details
    );

    // ======================
    // ERRORS
    // ======================

    error RoleAlreadyAssigned();
    error RoleNotAssigned();
    error RoleExpired();
    error InsufficientPermissions();
    error VotingNotFound();
    error VotingAlreadyExecuted();
    error VotingStillActive();
    error AlreadyVoted();
    error EmergencyModeActive();
    error InvalidDuration();

    // ======================
    // MODIFIERS
    // ======================

    modifier onlyActiveRole(bytes32 role) {
        require(hasActiveRole(role, msg.sender), "Role not active");
        _;
    }

    modifier notEmergencyMode() {
        if (emergencyMode) revert EmergencyModeActive();
        _;
    }

    modifier validAddress(address _address) {
        require(_address != address(0), "Invalid address");
        require(
            _address.code.length == 0 || _address.isContract(),
            "Invalid address type"
        );
        _;
    }

    modifier logAction(
        bytes32 action,
        bytes32 role,
        address target,
        string memory details
    ) {
        _;
        _logAction(action, role, target, details);
        _updateUserActivity(msg.sender);
    }

    // ======================
    // CONSTRUCTOR
    // ======================

    constructor() {
        // Set up role hierarchy
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SUPER_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(EMERGENCY_ROLE, msg.sender);

        // Set role admin relationships
        _setRoleAdmin(ADMIN_ROLE, SUPER_ADMIN_ROLE);
        _setRoleAdmin(OPERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(MODERATOR_ROLE, ADMIN_ROLE);
        _setRoleAdmin(USER_ROLE, MODERATOR_ROLE);

        // Set voting thresholds (in percentage)
        roleVotingThreshold[ADMIN_ROLE] = 66; // 66% approval required
        roleVotingThreshold[OPERATOR_ROLE] = 51; // 51% approval required
        roleVotingThreshold[MODERATOR_ROLE] = 51;

        // Set maximum role durations
        roleMaxDuration[ADMIN_ROLE] = 365 days;
        roleMaxDuration[OPERATOR_ROLE] = 180 days;
        roleMaxDuration[MODERATOR_ROLE] = 90 days;
        roleMaxDuration[USER_ROLE] = 0; // No limit

        // Initialize creator profile
        userProfiles[msg.sender] = UserProfile({
            name: "System Creator",
            email: "",
            joinedAt: block.timestamp,
            lastActivity: block.timestamp,
            isActive: true,
            roles: new bytes32[](0),
            actionsCount: 0,
            reputation: 100
        });
    }

    // ======================
    // ROLE MANAGEMENT
    // ======================

    /**
     * @dev Assign role with expiration time
     */
    function assignRoleWithExpiration(
        bytes32 role,
        address account,
        uint256 duration,
        string calldata reason
    )
        external
        onlyRole(getRoleAdmin(role))
        validAddress(account)
        logAction("ASSIGN_ROLE", role, account, reason)
    {
        require(
            duration <= roleMaxDuration[role] || roleMaxDuration[role] == 0,
            "Duration exceeds maximum"
        );

        if (hasRole(role, account)) revert RoleAlreadyAssigned();

        uint256 expiresAt = duration > 0 ? block.timestamp + duration : 0;

        roleAssignments[role][account] = RoleAssignment({
            account: account,
            role: role,
            assignedAt: block.timestamp,
            expiresAt: expiresAt,
            assignedBy: msg.sender,
            isActive: true,
            reason: reason
        });

        _grantRole(role, account);
        _addRoleToUserProfile(account, role);

        emit RoleAssignmentCreated(
            role,
            account,
            msg.sender,
            expiresAt,
            reason
        );
    }

    /**
     * @dev Revoke role assignment
     */
    function revokeRoleAssignment(
        bytes32 role,
        address account,
        string calldata reason
    )
        external
        onlyRole(getRoleAdmin(role))
        logAction("REVOKE_ROLE", role, account, reason)
    {
        if (!hasRole(role, account)) revert RoleNotAssigned();

        roleAssignments[role][account].isActive = false;
        _revokeRole(role, account);
        _removeRoleFromUserProfile(account, role);
    }

    /**
     * @dev Start voting process for role assignment
     */
    function startRoleVoting(
        bytes32 role,
        address candidate,
        uint256 duration
    )
        external
        onlyActiveRole(ADMIN_ROLE)
        validAddress(candidate)
        returns (uint256 votingId)
    {
        if (duration == 0) duration = defaultVotingDuration;
        if (duration > 30 days) revert InvalidDuration();

        votingId = nextVotingId++;

        RoleVoting storage voting = roleVotings[votingId];
        voting.role = role;
        voting.candidate = candidate;
        voting.startTime = block.timestamp;
        voting.endTime = block.timestamp + duration;

        userVotings[candidate].push(votingId);

        emit RoleVotingStarted(votingId, role, candidate, voting.endTime);
    }

    /**
     * @dev Cast vote for role assignment
     */
    function voteForRole(
        uint256 votingId,
        bool support,
        string calldata reason
    )
        external
        onlyActiveRole(ADMIN_ROLE)
        logAction("VOTE_ROLE", bytes32(0), address(0), reason)
    {
        RoleVoting storage voting = roleVotings[votingId];

        if (voting.candidate == address(0)) revert VotingNotFound();
        if (voting.executed) revert VotingAlreadyExecuted();
        if (block.timestamp > voting.endTime) revert VotingStillActive();
        if (voting.hasVoted[msg.sender]) revert AlreadyVoted();

        voting.hasVoted[msg.sender] = true;
        voting.voters.push(msg.sender);

        if (support) {
            voting.votesFor++;
        } else {
            voting.votesAgainst++;
        }

        emit RoleVoteCast(votingId, msg.sender, support, reason);
    }

    /**
     * @dev Execute role voting result
     */
    function executeRoleVoting(
        uint256 votingId
    ) external onlyActiveRole(ADMIN_ROLE) {
        RoleVoting storage voting = roleVotings[votingId];

        if (voting.candidate == address(0)) revert VotingNotFound();
        if (voting.executed) revert VotingAlreadyExecuted();
        if (block.timestamp <= voting.endTime) revert VotingStillActive();

        voting.executed = true;

        uint256 totalVotes = voting.votesFor + voting.votesAgainst;
        uint256 threshold = roleVotingThreshold[voting.role];

        if (
            totalVotes > 0 && (voting.votesFor * 100) / totalVotes >= threshold
        ) {
            voting.approved = true;
            _grantRole(voting.role, voting.candidate);
            _addRoleToUserProfile(voting.candidate, voting.role);
        }

        emit RoleVotingExecuted(
            votingId,
            voting.approved,
            voting.votesFor,
            voting.votesAgainst
        );
    }

    // ======================
    // USER PROFILE MANAGEMENT
    // ======================

    /**
     * @dev Update user profile
     */
    function updateUserProfile(
        string calldata name,
        string calldata email
    )
        external
        logAction("UPDATE_PROFILE", bytes32(0), msg.sender, "Profile updated")
    {
        UserProfile storage profile = userProfiles[msg.sender];

        if (profile.joinedAt == 0) {
            profile.joinedAt = block.timestamp;
            profile.isActive = true;
            profile.reputation = 10; // Starting reputation
        }

        profile.name = name;
        profile.email = email;
        profile.lastActivity = block.timestamp;

        emit UserProfileUpdated(msg.sender, name, email);
    }

    /**
     * @dev Activate/deactivate user
     */
    function setUserActive(
        address user,
        bool active
    )
        external
        onlyActiveRole(MODERATOR_ROLE)
        validAddress(user)
        logAction(
            "SET_USER_ACTIVE",
            bytes32(0),
            user,
            active ? "Activated" : "Deactivated"
        )
    {
        userProfiles[user].isActive = active;
        userProfiles[user].lastActivity = block.timestamp;
    }

    // ======================
    // EMERGENCY FUNCTIONS
    // ======================

    /**
     * @dev Toggle emergency mode
     */
    function toggleEmergencyMode()
        external
        onlyRole(EMERGENCY_ROLE)
        logAction(
            "TOGGLE_EMERGENCY",
            EMERGENCY_ROLE,
            address(0),
            emergencyMode ? "Deactivated" : "Activated"
        )
    {
        emergencyMode = !emergencyMode;
        emergencyActivatedAt = block.timestamp;
        emergencyActivator = msg.sender;

        emit EmergencyModeToggled(emergencyMode, msg.sender, block.timestamp);
    }

    /**
     * @dev Emergency role assignment (bypasses voting)
     */
    function emergencyRoleAssignment(
        bytes32 role,
        address account,
        string calldata reason
    )
        external
        onlyRole(EMERGENCY_ROLE)
        logAction("EMERGENCY_ASSIGN", role, account, reason)
    {
        require(emergencyMode, "Emergency mode not active");

        _grantRole(role, account);
        _addRoleToUserProfile(account, role);

        roleAssignments[role][account] = RoleAssignment({
            account: account,
            role: role,
            assignedAt: block.timestamp,
            expiresAt: block.timestamp + emergencyVotingDuration,
            assignedBy: msg.sender,
            isActive: true,
            reason: string(abi.encodePacked("EMERGENCY: ", reason))
        });
    }

    // ======================
    // PROTECTED FUNCTIONS
    // ======================

    /**
     * @dev Admin-only function example
     */
    function adminOnlyFunction()
        external
        onlyActiveRole(ADMIN_ROLE)
        notEmergencyMode
        logAction(
            "ADMIN_FUNCTION",
            ADMIN_ROLE,
            address(0),
            "Admin function called"
        )
    {
        // Admin-specific logic here
        userProfiles[msg.sender].actionsCount++;
    }

    /**
     * @dev Operator-only function example
     */
    function operatorOnlyFunction()
        external
        onlyActiveRole(OPERATOR_ROLE)
        logAction(
            "OPERATOR_FUNCTION",
            OPERATOR_ROLE,
            address(0),
            "Operator function called"
        )
    {
        // Operator-specific logic here
        userProfiles[msg.sender].actionsCount++;
    }

    /**
     * @dev Moderator-only function example
     */
    function moderatorOnlyFunction()
        external
        onlyActiveRole(MODERATOR_ROLE)
        logAction(
            "MODERATOR_FUNCTION",
            MODERATOR_ROLE,
            address(0),
            "Moderator function called"
        )
    {
        // Moderator-specific logic here
        userProfiles[msg.sender].actionsCount++;
    }

    /**
     * @dev User-only function example
     */
    function userOnlyFunction()
        external
        onlyActiveRole(USER_ROLE)
        logAction(
            "USER_FUNCTION",
            USER_ROLE,
            address(0),
            "User function called"
        )
    {
        // User-specific logic here
        userProfiles[msg.sender].actionsCount++;
    }

    // ======================
    // VIEW FUNCTIONS
    // ======================

    /**
     * @dev Check if user has active role (considering expiration)
     */
    function hasActiveRole(
        bytes32 role,
        address account
    ) public view returns (bool) {
        if (!hasRole(role, account)) return false;

        RoleAssignment storage assignment = roleAssignments[role][account];
        if (!assignment.isActive) return false;

        if (
            assignment.expiresAt > 0 && block.timestamp > assignment.expiresAt
        ) {
            return false;
        }

        return userProfiles[account].isActive;
    }

    /**
     * @dev Get user roles
     */
    function getUserRoles(
        address user
    ) external view returns (bytes32[] memory) {
        return userProfiles[user].roles;
    }

    /**
     * @dev Get role assignment details
     */
    function getRoleAssignment(
        bytes32 role,
        address account
    )
        external
        view
        returns (
            uint256 assignedAt,
            uint256 expiresAt,
            address assignedBy,
            bool isActive,
            string memory reason
        )
    {
        RoleAssignment storage assignment = roleAssignments[role][account];
        return (
            assignment.assignedAt,
            assignment.expiresAt,
            assignment.assignedBy,
            assignment.isActive,
            assignment.reason
        );
    }

    /**
     * @dev Get voting details
     */
    function getRoleVoting(
        uint256 votingId
    )
        external
        view
        returns (
            bytes32 role,
            address candidate,
            uint256 votesFor,
            uint256 votesAgainst,
            uint256 startTime,
            uint256 endTime,
            bool executed,
            bool approved
        )
    {
        RoleVoting storage voting = roleVotings[votingId];
        return (
            voting.role,
            voting.candidate,
            voting.votesFor,
            voting.votesAgainst,
            voting.startTime,
            voting.endTime,
            voting.executed,
            voting.approved
        );
    }

    /**
     * @dev Get audit logs count
     */
    function getAuditLogsCount() external view returns (uint256) {
        return auditLogs.length;
    }

    /**
     * @dev Get user audit logs
     */
    function getUserAuditLogs(
        address user
    ) external view returns (uint256[] memory) {
        return userAuditLogs[user];
    }

    // ======================
    // INTERNAL FUNCTIONS
    // ======================

    function _addRoleToUserProfile(address user, bytes32 role) internal {
        UserProfile storage profile = userProfiles[user];

        // Check if role already exists
        for (uint256 i = 0; i < profile.roles.length; i++) {
            if (profile.roles[i] == role) return;
        }

        profile.roles.push(role);
        profile.reputation += 10; // Increase reputation for new role
    }

    function _removeRoleFromUserProfile(address user, bytes32 role) internal {
        UserProfile storage profile = userProfiles[user];

        for (uint256 i = 0; i < profile.roles.length; i++) {
            if (profile.roles[i] == role) {
                profile.roles[i] = profile.roles[profile.roles.length - 1];
                profile.roles.pop();
                break;
            }
        }
    }

    function _logAction(
        bytes32 action,
        bytes32 role,
        address target,
        string memory details
    ) internal {
        AuditLog memory log = AuditLog({
            actor: msg.sender,
            action: action,
            role: role,
            target: target,
            timestamp: block.timestamp,
            details: details
        });

        auditLogs.push(log);
        userAuditLogs[msg.sender].push(auditLogs.length - 1);

        emit ActionLogged(msg.sender, action, role, target, details);
    }

    function _updateUserActivity(address user) internal {
        UserProfile storage profile = userProfiles[user];
        profile.lastActivity = block.timestamp;
        profile.actionsCount++;

        // Increase reputation for activity
        if (profile.actionsCount % 10 == 0) {
            profile.reputation += 1;
        }
    }

    // ======================
    // ADMIN FUNCTIONS
    // ======================

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }
}

/**
 *  ACCESS CONTROL SOLUTION FEATURES:
 *
 * 1. HIERARCHICAL ROLE SYSTEM:
 *    - Multiple role levels with inheritance
 *    - Role admin relationships
 *    - Time-based role assignments
 *    - Automatic role expiration
 *
 * 2. DEMOCRATIC ROLE ASSIGNMENT:
 *    - Voting-based role assignments
 *    - Configurable voting thresholds
 *    - Voting duration management
 *    - Vote tracking and execution
 *
 * 3. USER PROFILE MANAGEMENT:
 *    - Comprehensive user profiles
 *    - Activity tracking
 *    - Reputation system
 *    - User activation/deactivation
 *
 * 4. EMERGENCY CONTROLS:
 *    - Emergency mode toggle
 *    - Emergency role assignments
 *    - Override mechanisms
 *    - Emergency duration limits
 *
 * 5. AUDIT AND TRANSPARENCY:
 *    - Complete audit trail
 *    - Action logging
 *    - User activity tracking
 *    - Historical data access
 *
 * This solution demonstrates enterprise-grade access control
 * patterns suitable for production systems requiring
 * sophisticated permission management.
 */

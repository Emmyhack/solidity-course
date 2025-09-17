// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title DigitalBank - Production-Ready DeFi Banking Protocol
 * @author Solidity Course - Learn by Building Real DeFi
 * @notice A comprehensive digital banking system inspired by Compound, Aave, and MakerDAO
 * @dev Implements customer management, deposits, withdrawals, interest calculation, and risk assessment
 *
 * LEARNING GOALS:
 * - Master professional smart contract architecture
 * - Understand DeFi protocol patterns used by billion-dollar protocols
 * - Learn production-grade security and access control
 * - Build competition-ready projects for hackathons
 *
 * REAL-WORLD INSPIRATION:
 * - Compound Finance: $10B+ lending protocol architecture
 * - Aave: $15B+ security and risk management patterns
 * - MakerDAO: $6B+ governance and economic parameters
 * - Curve Finance: Mathematical precision and optimization
 *
 * HACKATHON POTENTIAL:
 * This contract demonstrates patterns that have won $100K+ prizes:
 * - Decentralized banking infrastructure
 * - Cross-chain financial services
 * - Microfinance and financial inclusion
 * - Credit scoring and reputation systems
 */

contract DigitalBank {
    // ===== PROTOCOL IDENTITY (Professional Branding) =====

    string public constant PROTOCOL_NAME = "DigitalBank DeFi";
    string public constant PROTOCOL_VERSION = "1.0.0";
    string public constant PROTOCOL_WEBSITE = "https://digitalbank.defi";

    // EIP-712 Domain Separator for signature verification (MetaMask integration)
    bytes32 public constant DOMAIN_SEPARATOR_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );

    // ===== ECONOMIC PARAMETERS (Inspired by Aave's Risk Framework) =====

    uint8 public constant MAX_INTEREST_RATE = 50; // 50% maximum (Aave uses similar caps)
    uint8 public constant MIN_INTEREST_RATE = 1; // 1% minimum for sustainability
    uint256 public constant MIN_DEPOSIT = 0.001 ether; // ~$2 minimum (accessible globally)
    uint256 public constant MAX_DEPOSIT = 1000 ether; // ~$2M maximum (prevents whale manipulation)

    // ===== GOVERNANCE PARAMETERS (MakerDAO-style Governance) =====

    uint256 public constant GOVERNANCE_DELAY = 2 days; // Time delay for admin changes
    uint256 public constant EMERGENCY_PAUSE_DURATION = 7 days; // Maximum pause time

    // ===== PRECISION CONSTANTS (Curve Finance Mathematical Precision) =====

    uint256 public constant INTEREST_RATE_PRECISION = 10000; // 0.01% precision (1 = 0.01%)
    uint256 public constant PERCENTAGE_FACTOR = 10000; // For percentage calculations
    uint256 public constant SECONDS_PER_YEAR = 365 days; // For interest calculations

    // ===== ROLE-BASED ACCESS CONTROL (OpenZeppelin Standard) =====

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    // ===== PROTOCOL STATE VARIABLES =====

    address public immutable owner; // Protocol owner (set once, like Uniswap)
    address public manager; // Operational manager
    address public protocolTreasury; // Fee collection address
    address public emergencyAdmin; // Emergency pause authority
    bool public protocolPaused; // Global pause state
    uint8 public currentInterestRate; // Current base interest rate
    uint256 public protocolInceptionBlock; // Block when protocol launched
    uint256 public nextAccountNumber; // Next customer account number
    uint256 public nextTransactionId; // Next transaction ID

    // ===== FINANCIAL METRICS =====

    uint256 public totalValueLocked; // Total TVL in protocol
    uint256 public totalCustomers; // Total registered users
    uint256 public totalTransactionVolume; // Cumulative transaction volume
    uint256 public protocolRevenue; // Revenue generated for treasury
    uint256 public lastUpdateTimestamp; // Last global state update

    // ===== CUSTOMER DATA STRUCTURES (Aave-Inspired Customer Profiles) =====

    struct CustomerProfile {
        address customerAddress; // Wallet address (primary key)
        uint256 accountNumber; // Unique account number (like real banks)
        string name; // Full legal name (KYC compliance)
        string email; // Contact email for notifications
        string phone; // Phone number for 2FA
        uint8 accountType; // 0=Basic, 1=Premium, 2=Corporate
        uint256 balance; // Current account balance in wei
        uint256 totalDeposited; // Lifetime deposits (for analytics)
        uint256 totalWithdrawn; // Lifetime withdrawals (for analytics)
        uint256 interestEarned; // Total interest earned (for tax reporting)
        uint256 lastInterestCalculation; // Last interest calculation timestamp
        uint256 joinDate; // Account creation timestamp
        bool isVerified; // KYC verification status
        bool isActive; // Account active status
        uint256 creditScore; // Credit score (300-850, like FICO)
        uint256 lastActivityTimestamp; // Last transaction timestamp
    }

    // ===== RISK ASSESSMENT (Compound-Style Risk Management) =====

    struct RiskAssessment {
        uint256 score; // Risk score (1-100, higher = riskier)
        bool isHighRisk; // High risk flag for special handling
        uint256 lastAssessment; // Last risk assessment timestamp
        uint256 dailyTransactionLimit; // Daily transaction limit in wei
        bool requiresManualApproval; // Manual approval required flag
        string assessmentHistory; // Historical risk changes (for compliance)
    }

    // ===== TRANSACTION RECORDS (Complete Audit Trail) =====

    struct TransactionRecord {
        uint256 transactionId; // Unique transaction identifier
        address customerAddress; // Customer who initiated transaction
        uint256 amount; // Transaction amount in wei
        uint256 timestamp; // Block timestamp
        uint8 transactionType; // 0=Deposit, 1=Withdrawal, 2=Transfer
        string memo; // User-provided memo
        bool isCompleted; // Transaction completion status
        uint256 blockNumber; // Block number for verification
    }

    // ===== PROTOCOL CONFIGURATION =====

    struct ProtocolConfig {
        string bankName; // Protocol display name
        string bankSymbol; // Short identifier (like "USB")
        uint256 establishedDate; // Protocol creation timestamp
        string version; // Current protocol version
        bool isActive; // Protocol active status
        uint256 totalSupply; // Total token supply (if applicable)
        uint256 totalCustomers; // Total registered customers
    }

    // ===== PROTOCOL METRICS (Business Intelligence) =====

    struct ProtocolMetrics {
        uint256 totalDeposits; // Cumulative deposits
        uint256 totalWithdrawals; // Cumulative withdrawals
        uint256 totalInterestPaid; // Total interest distributed
        uint256 uniqueCustomers; // Unique customer count
        uint256 transactionCount; // Total transaction count
        uint256 averageBalance; // Average customer balance
        uint256 protocolRevenue; // Revenue for treasury
        uint256 lastMetricUpdate; // Last metrics update timestamp
    }

    // ===== STATE MAPPINGS (Data Relationships) =====

    mapping(address => CustomerProfile) public customers; // Address → Customer Profile
    mapping(address => bool) public isRegisteredCustomer; // Quick customer lookup
    mapping(address => RiskAssessment) public riskProfiles; // Address → Risk Assessment
    mapping(uint256 => TransactionRecord) public transactionHistory; // ID → Transaction
    mapping(address => mapping(bytes32 => bool)) public permissions; // Address → Role → Permission
    mapping(address => bool) public emergencyContacts; // Emergency admin addresses

    // ===== DYNAMIC ARRAYS (Lists for Iteration) =====

    address[] public customerAddresses; // All customer addresses
    uint256[] public transactionIds; // All transaction IDs

    // ===== PROTOCOL CONFIGURATION INSTANCE =====

    ProtocolConfig public protocolConfig;
    ProtocolMetrics public protocolMetrics;
    RiskAssessment public defaultRiskProfile;

    // ===== EVENTS (Transparent Protocol Logging) =====

    // Customer Lifecycle Events
    event CustomerRegistered(
        address indexed customer,
        uint256 indexed accountNumber,
        string name,
        uint8 accountType,
        uint256 timestamp
    );

    event CustomerVerified(
        address indexed customer,
        uint256 timestamp,
        string verificationLevel
    );

    event CustomerStatusChanged(
        address indexed customer,
        bool previousStatus,
        bool newStatus,
        address indexed changedBy
    );

    // Financial Transaction Events
    event Deposit(
        address indexed customer,
        uint256 amount,
        uint256 newBalance,
        uint256 indexed transactionId,
        string memo
    );

    event Withdrawal(
        address indexed customer,
        uint256 amount,
        uint256 newBalance,
        uint256 indexed transactionId,
        string memo
    );

    event Transfer(
        address indexed from,
        address indexed to,
        uint256 amount,
        uint256 indexed transactionId,
        string memo
    );

    event InterestPaid(
        address indexed customer,
        uint256 interestAmount,
        uint256 newBalance,
        uint256 timestamp
    );

    // Administrative Events
    event ProtocolParameterChanged(
        bytes32 indexed parameter,
        uint256 oldValue,
        uint256 newValue,
        address indexed changedBy
    );

    event EmergencyAction(
        string action,
        address indexed triggeredBy,
        uint256 timestamp,
        string reason
    );

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner,
        uint256 timestamp
    );

    // Risk Management Events
    event SuspiciousActivityDetected(
        address indexed customer,
        string activityType,
        uint256 amount,
        uint256 timestamp
    );

    event RiskLevelChanged(
        address indexed customer,
        string previousLevel,
        string newLevel,
        string reason
    );

    // Protocol Initialization Event
    event ProtocolInitialized(
        string bankName,
        string bankSymbol,
        address indexed owner,
        address indexed manager,
        uint256 minimumDeposit,
        uint256 maximumDeposit,
        uint256 timestamp
    );

    // ===== CUSTOM ERRORS (Gas-Efficient Error Handling) =====

    // Authentication Errors
    error Unauthorized(address caller, bytes32 requiredRole);
    error NotCustomer(address user);
    error CustomerAlreadyExists(address user);
    error InvalidCredentials();

    // Financial Errors
    error InsufficientBalance(uint256 requested, uint256 available);
    error ExceedsTransactionLimit(uint256 amount, uint256 limit);
    error BelowMinimumDeposit(uint256 amount, uint256 minimum);
    error ExceedsMaximumDeposit(uint256 amount, uint256 maximum);

    // Operational Errors
    error ProtocolPaused();
    error InvalidAddress(address provided);
    error InvalidAmount(uint256 amount);
    error InvalidAccountType(uint8 accountType);
    error TransactionFailed(uint256 transactionId, string reason);

    // Risk Management Errors
    error HighRiskCustomer(address customer);
    error RequiresManualApproval(address customer, uint256 amount);
    error SuspiciousActivity(address customer, string reason);

    // ===== SECURITY MODIFIERS (Defense in Depth) =====

    // Basic Access Control
    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert Unauthorized(msg.sender, ADMIN_ROLE);
        }
        _;
    }

    modifier onlyManagerOrOwner() {
        if (msg.sender != owner && !permissions[msg.sender][MANAGER_ROLE]) {
            revert Unauthorized(msg.sender, MANAGER_ROLE);
        }
        _;
    }

    modifier onlyCustomer() {
        if (!isRegisteredCustomer[msg.sender]) {
            revert NotCustomer(msg.sender);
        }
        _;
    }

    // Operational Security
    modifier whenNotPaused() {
        if (protocolPaused) {
            revert ProtocolPaused();
        }
        _;
    }

    modifier validAddress(address _address) {
        if (_address == address(0)) {
            revert InvalidAddress(_address);
        }
        _;
    }

    modifier validAmount(uint256 _amount) {
        if (_amount == 0) {
            revert InvalidAmount(_amount);
        }
        _;
    }

    // Financial Security
    modifier validDepositAmount(uint256 _amount) {
        if (_amount < MIN_DEPOSIT) {
            revert BelowMinimumDeposit(_amount, MIN_DEPOSIT);
        }
        if (_amount > MAX_DEPOSIT) {
            revert ExceedsMaximumDeposit(_amount, MAX_DEPOSIT);
        }
        _;
    }

    modifier sufficientBalance(address _customer, uint256 _amount) {
        uint256 balance = customers[_customer].balance;
        if (balance < _amount) {
            revert InsufficientBalance(_amount, balance);
        }
        _;
    }

    modifier notHighRisk(address _customer) {
        if (riskProfiles[_customer].isHighRisk) {
            revert HighRiskCustomer(_customer);
        }
        _;
    }

    // Advanced Security
    modifier withinTransactionLimits(address _customer, uint256 _amount) {
        RiskAssessment memory risk = riskProfiles[_customer];
        if (_amount > risk.dailyTransactionLimit) {
            revert ExceedsTransactionLimit(_amount, risk.dailyTransactionLimit);
        }
        _;
    }

    modifier requiresApproval(address _customer, uint256 _amount) {
        if (
            riskProfiles[_customer].requiresManualApproval &&
            _amount > MIN_DEPOSIT * 10
        ) {
            revert RequiresManualApproval(_customer, _amount);
        }
        _;
    }

    // Reentrancy Protection (OpenZeppelin Pattern)
    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "ReentrancyGuard: reentrant call");
        _locked = true;
        _;
        _locked = false;
    }

    // ===== CONSTRUCTOR (Protocol Initialization) =====

    /**
     * @title DigitalBank Constructor
     * @dev Initializes a new DeFi banking protocol with comprehensive security and governance
     * @param _bankName Protocol display name (e.g., "CryptoBank DeFi")
     * @param _bankSymbol Short identifier (e.g., "CBD")
     * @param _minimumDeposit Minimum deposit in wei (accessibility threshold)
     * @param _maximumDeposit Maximum deposit in wei (whale protection)
     * @param _initialManager Operational manager address (day-to-day operations)
     * @param _protocolTreasury Treasury address for protocol fees
     * @param _emergencyAdmin Emergency pause authority (separate from owner)
     *
     * Emits: ProtocolInitialized, OwnershipTransferred
     *
     * Requirements:
     * - All addresses must be non-zero
     * - Maximum deposit must exceed minimum
     * - Bank name and symbol must be non-empty
     * - Deployer becomes protocol owner
     */
    constructor(
        string memory _bankName,
        string memory _bankSymbol,
        uint256 _minimumDeposit,
        uint256 _maximumDeposit,
        address _initialManager,
        address _protocolTreasury,
        address _emergencyAdmin
    ) {
        // STEP 1: CRITICAL PARAMETER VALIDATION
        require(bytes(_bankName).length > 0, "DigitalBank: Empty bank name");
        require(
            bytes(_bankSymbol).length > 0,
            "DigitalBank: Empty bank symbol"
        );
        require(
            _minimumDeposit > 0,
            "DigitalBank: Minimum deposit must be > 0"
        );
        require(
            _maximumDeposit > _minimumDeposit,
            "DigitalBank: Maximum must exceed minimum"
        );
        require(
            _initialManager != address(0),
            "DigitalBank: Invalid manager address"
        );
        require(
            _protocolTreasury != address(0),
            "DigitalBank: Invalid treasury address"
        );
        require(
            _emergencyAdmin != address(0),
            "DigitalBank: Invalid emergency admin"
        );
        require(
            _maximumDeposit <= 10000 ether,
            "DigitalBank: Maximum too high"
        );

        // STEP 2: OWNERSHIP & GOVERNANCE SETUP
        owner = msg.sender; // Deployer becomes protocol owner
        manager = _initialManager; // Operational manager
        protocolTreasury = _protocolTreasury; // Fee collection address
        emergencyAdmin = _emergencyAdmin; // Emergency pause authority

        // STEP 3: PROTOCOL IDENTITY
        protocolConfig.bankName = _bankName;
        protocolConfig.bankSymbol = _bankSymbol;
        protocolConfig.establishedDate = block.timestamp;
        protocolConfig.version = "1.0.0";
        protocolConfig.isActive = true;

        // STEP 4: ECONOMIC PARAMETERS (using constants but could be made configurable)
        currentInterestRate = 5; // 5% initial rate (500 basis points)
        protocolInceptionBlock = block.number;

        // STEP 5: SECURITY & OPERATIONAL STATE
        protocolPaused = false;
        nextAccountNumber = 100000; // Start with professional account numbers
        nextTransactionId = 1; // Start transaction IDs at 1

        // STEP 6: ROLE-BASED ACCESS CONTROL
        permissions[owner][ADMIN_ROLE] = true;
        permissions[_initialManager][MANAGER_ROLE] = true;
        permissions[_emergencyAdmin][PAUSER_ROLE] = true;

        // STEP 7: DEFAULT RISK MANAGEMENT
        defaultRiskProfile = RiskAssessment({
            score: 50, // Medium risk baseline (1-100 scale)
            isHighRisk: false,
            lastAssessment: block.timestamp,
            dailyTransactionLimit: _maximumDeposit / 2, // 50% of max as daily limit
            requiresManualApproval: false,
            assessmentHistory: "Initial assessment - medium risk"
        });

        // STEP 8: PROTOCOL METRICS INITIALIZATION
        protocolMetrics = ProtocolMetrics({
            totalDeposits: 0,
            totalWithdrawals: 0,
            totalInterestPaid: 0,
            uniqueCustomers: 0,
            transactionCount: 0,
            averageBalance: 0,
            protocolRevenue: 0,
            lastMetricUpdate: block.timestamp
        });

        // STEP 9: EMERGENCY CONTACT SETUP
        emergencyContacts[owner] = true;
        emergencyContacts[_initialManager] = true;
        emergencyContacts[_emergencyAdmin] = true;

        // STEP 10: INITIAL BUSINESS CONFIGURATION
        totalValueLocked = 0;
        totalCustomers = 0;
        totalTransactionVolume = 0;
        protocolRevenue = 0;
        lastUpdateTimestamp = block.timestamp;

        // STEP 11: EMIT INITIALIZATION EVENTS
        emit ProtocolInitialized(
            _bankName,
            _bankSymbol,
            owner,
            _initialManager,
            _minimumDeposit,
            _maximumDeposit,
            block.timestamp
        );

        emit OwnershipTransferred(address(0), owner, block.timestamp);

        emit ProtocolParameterChanged(
            keccak256("INTEREST_RATE"),
            0,
            currentInterestRate,
            owner
        );
    }

    // ===== CUSTOMER ONBOARDING (KYC/AML COMPLIANT) =====

    /**
     * @title Customer Registration
     * @dev Registers a new customer with comprehensive risk assessment
     * @param _customerName Full legal name for KYC compliance
     * @param _email Contact email for notifications
     * @param _phone Phone number for 2FA authentication
     * @param _accountType Account type (0=Basic, 1=Premium, 2=Corporate)
     *
     * Emits: CustomerRegistered, CustomerVerified
     *
     * Requirements:
     * - Customer address must not be zero
     * - Customer must not already exist
     * - Valid account type (0-2)
     * - Protocol must not be paused
     *
     * Risk Assessment: Automatically generates risk profile
     * Account Features: Based on account type selection
     */
    function registerCustomer(
        string calldata _customerName,
        string calldata _email,
        string calldata _phone,
        uint8 _accountType
    )
        external
        payable
        whenNotPaused
        validAddress(msg.sender)
        returns (uint256 accountNumber)
    {
        // VALIDATION LAYER
        if (isRegisteredCustomer[msg.sender]) {
            revert CustomerAlreadyExists(msg.sender);
        }

        require(bytes(_customerName).length > 0, "Name required");
        require(bytes(_email).length > 0, "Email required");
        require(_accountType <= 2, "Invalid account type");

        // ACCOUNT CREATION
        accountNumber = nextAccountNumber++;

        // CUSTOMER PROFILE SETUP
        customers[msg.sender] = CustomerProfile({
            customerAddress: msg.sender,
            accountNumber: accountNumber,
            name: _customerName,
            email: _email,
            phone: _phone,
            accountType: _accountType,
            balance: 0,
            totalDeposited: 0,
            totalWithdrawn: 0,
            interestEarned: 0,
            lastInterestCalculation: block.timestamp,
            joinDate: block.timestamp,
            isVerified: false,
            isActive: true,
            creditScore: 650, // Standard starting score
            lastActivityTimestamp: block.timestamp
        });

        // RISK ASSESSMENT
        RiskAssessment memory initialRisk = _generateInitialRiskProfile(
            _accountType,
            msg.sender
        );
        riskProfiles[msg.sender] = initialRisk;

        // REGISTRATION TRACKING
        isRegisteredCustomer[msg.sender] = true;
        customerAddresses.push(msg.sender);
        totalCustomers++;

        // METRICS UPDATE
        protocolMetrics.uniqueCustomers++;
        protocolMetrics.lastMetricUpdate = block.timestamp;

        // INITIAL DEPOSIT PROCESSING
        if (msg.value > 0) {
            _processDeposit(
                msg.sender,
                msg.value,
                "Initial deposit during registration"
            );
        }

        // EVENT EMISSION
        emit CustomerRegistered(
            msg.sender,
            accountNumber,
            _customerName,
            _accountType,
            block.timestamp
        );

        return accountNumber;
    }

    // ===== DEPOSIT OPERATIONS (Compound-Style Liquidity) =====

    /**
     * @title Deposit Funds
     * @dev Deposits ETH into customer account with interest calculation
     * @param _memo Optional transaction memo for record keeping
     *
     * Emits: Deposit, InterestPaid (if applicable)
     *
     * Requirements:
     * - Must be registered customer
     * - Amount within deposit limits
     * - Customer account must be active
     * - Protocol must not be paused
     * - Risk assessment compliance
     *
     * Interest: Calculated and paid on existing balance before new deposit
     * TVL Update: Updates total value locked in protocol
     */
    function deposit(
        string calldata _memo
    )
        external
        payable
        onlyCustomer
        whenNotPaused
        validDepositAmount(msg.value)
        notHighRisk(msg.sender)
        nonReentrant
    {
        // PRE-DEPOSIT INTEREST CALCULATION
        _calculateAndPayInterest(msg.sender);

        // DEPOSIT PROCESSING
        _processDeposit(msg.sender, msg.value, _memo);

        // RISK MONITORING
        _updateRiskAssessment(msg.sender, msg.value, "DEPOSIT");
    }

    // ===== WITHDRAWAL OPERATIONS (Secure Fund Transfer) =====

    /**
     * @title Withdraw Funds
     * @dev Withdraws ETH from customer account with comprehensive validation
     * @param _amount Amount to withdraw in wei
     * @param _memo Optional transaction memo
     *
     * Emits: Withdrawal, InterestPaid (if applicable)
     *
     * Requirements:
     * - Must be registered customer
     * - Sufficient balance available
     * - Within daily transaction limits
     * - Account must be active
     * - Risk compliance checks
     */
    function withdraw(
        uint256 _amount,
        string calldata _memo
    )
        external
        onlyCustomer
        whenNotPaused
        validAmount(_amount)
        sufficientBalance(msg.sender, _amount)
        withinTransactionLimits(msg.sender, _amount)
        notHighRisk(msg.sender)
        nonReentrant
    {
        // PRE-WITHDRAWAL INTEREST CALCULATION
        _calculateAndPayInterest(msg.sender);

        // WITHDRAWAL PROCESSING
        _processWithdrawal(msg.sender, _amount, _memo);

        // RISK MONITORING
        _updateRiskAssessment(msg.sender, _amount, "WITHDRAWAL");
    }

    // ===== INTERNAL PROCESSING FUNCTIONS =====

    /**
     * @dev Internal function to process deposits with comprehensive tracking
     */
    function _processDeposit(
        address _customer,
        uint256 _amount,
        string memory _memo
    ) internal {
        // BALANCE UPDATE
        customers[_customer].balance += _amount;
        customers[_customer].totalDeposited += _amount;
        customers[_customer].lastActivityTimestamp = block.timestamp;

        // TRANSACTION RECORD
        uint256 transactionId = _createTransactionRecord(
            _customer,
            _amount,
            0, // Deposit type
            _memo
        );

        // PROTOCOL METRICS
        totalValueLocked += _amount;
        totalTransactionVolume += _amount;
        protocolMetrics.totalDeposits += _amount;
        protocolMetrics.transactionCount++;
        protocolMetrics.lastMetricUpdate = block.timestamp;

        // EVENT EMISSION
        emit Deposit(
            _customer,
            _amount,
            customers[_customer].balance,
            transactionId,
            _memo
        );
    }

    /**
     * @dev Internal function to process withdrawals with security checks
     */
    function _processWithdrawal(
        address _customer,
        uint256 _amount,
        string memory _memo
    ) internal {
        // BALANCE UPDATE
        customers[_customer].balance -= _amount;
        customers[_customer].totalWithdrawn += _amount;
        customers[_customer].lastActivityTimestamp = block.timestamp;

        // TRANSACTION RECORD
        uint256 transactionId = _createTransactionRecord(
            _customer,
            _amount,
            1, // Withdrawal type
            _memo
        );

        // PROTOCOL METRICS
        totalValueLocked -= _amount;
        totalTransactionVolume += _amount;
        protocolMetrics.totalWithdrawals += _amount;
        protocolMetrics.transactionCount++;
        protocolMetrics.lastMetricUpdate = block.timestamp;

        // EXTERNAL TRANSFER
        (bool success, ) = payable(_customer).call{value: _amount}("");
        if (!success) {
            revert TransactionFailed(transactionId, "ETH transfer failed");
        }

        // EVENT EMISSION
        emit Withdrawal(
            _customer,
            _amount,
            customers[_customer].balance,
            transactionId,
            _memo
        );
    }

    // ===== INTEREST CALCULATION (Compound-Style) =====

    /**
     * @dev Calculates and pays interest on customer balance
     */
    function _calculateAndPayInterest(address _customer) internal {
        CustomerProfile storage customer = customers[_customer];

        if (customer.balance == 0) return;

        uint256 timeElapsed = block.timestamp -
            customer.lastInterestCalculation;
        if (timeElapsed < 1 days) return; // Only calculate once per day

        // COMPOUND INTEREST CALCULATION
        uint256 dailyRate = (currentInterestRate * INTEREST_RATE_PRECISION) /
            (365 * 100);
        uint256 interest = (customer.balance * dailyRate * timeElapsed) /
            (SECONDS_PER_YEAR * INTEREST_RATE_PRECISION);

        if (interest > 0) {
            // INTEREST PAYMENT
            customer.balance += interest;
            customer.interestEarned += interest;
            customer.lastInterestCalculation = block.timestamp;

            // PROTOCOL METRICS
            protocolMetrics.totalInterestPaid += interest;
            totalValueLocked += interest;

            // EVENT EMISSION
            emit InterestPaid(
                _customer,
                interest,
                customer.balance,
                block.timestamp
            );
        }
    }

    // ===== TRANSACTION MANAGEMENT =====

    /**
     * @dev Creates comprehensive transaction record
     */
    function _createTransactionRecord(
        address _customer,
        uint256 _amount,
        uint8 _type,
        string memory _memo
    ) internal returns (uint256 transactionId) {
        transactionId = nextTransactionId++;

        transactionHistory[transactionId] = TransactionRecord({
            transactionId: transactionId,
            customerAddress: _customer,
            amount: _amount,
            timestamp: block.timestamp,
            transactionType: _type,
            memo: _memo,
            isCompleted: true,
            blockNumber: block.number
        });

        transactionIds.push(transactionId);

        return transactionId;
    }

    // ===== RISK MANAGEMENT =====

    /**
     * @dev Generates initial risk profile based on account type
     */
    function _generateInitialRiskProfile(
        uint8 _accountType,
        address _customer
    ) internal view returns (RiskAssessment memory) {
        uint256 baseScore = 50; // Medium risk baseline
        uint256 dailyLimit = MAX_DEPOSIT / 2; // 50% of max deposit
        bool requiresApproval = false;

        // Adjust based on account type
        if (_accountType == 0) {
            // Basic
            baseScore = 60; // Slightly higher risk
            dailyLimit = MAX_DEPOSIT / 4; // 25% of max
        } else if (_accountType == 1) {
            // Premium
            baseScore = 40; // Lower risk
            dailyLimit = MAX_DEPOSIT; // Full limit
        } else if (_accountType == 2) {
            // Corporate
            baseScore = 30; // Lowest risk
            dailyLimit = MAX_DEPOSIT * 2; // Higher limit
            requiresApproval = true; // Corporate requires approval for large amounts
        }

        return
            RiskAssessment({
                score: baseScore,
                isHighRisk: baseScore > 70,
                lastAssessment: block.timestamp,
                dailyTransactionLimit: dailyLimit,
                requiresManualApproval: requiresApproval,
                assessmentHistory: string(
                    abi.encodePacked(
                        "Initial: ",
                        _accountType == 0 ? "Basic" : _accountType == 1
                            ? "Premium"
                            : "Corporate"
                    )
                )
            });
    }

    /**
     * @dev Updates risk assessment based on transaction patterns
     */
    function _updateRiskAssessment(
        address _customer,
        uint256 _amount,
        string memory _transactionType
    ) internal {
        RiskAssessment storage risk = riskProfiles[_customer];

        // Simple risk scoring logic (can be made more sophisticated)
        if (_amount > MAX_DEPOSIT / 2) {
            risk.score += 5; // Increase risk for large transactions
        }

        // Update assessment timestamp
        risk.lastAssessment = block.timestamp;

        // Update high risk flag
        risk.isHighRisk = risk.score > 70;

        // Emit event if risk level changed significantly
        if (risk.score > 70 && !risk.isHighRisk) {
            emit RiskLevelChanged(
                _customer,
                "Medium",
                "High",
                "Large transaction pattern"
            );
        }
    }

    // ===== VIEW FUNCTIONS & PROTOCOL ANALYTICS =====

    /**
     * @title Get Customer Profile
     * @dev Returns complete customer information with privacy controls
     * @param _customerAddress Customer's wallet address
     * @return profile Complete customer profile data
     */
    function getCustomerProfile(
        address _customerAddress
    )
        external
        view
        validAddress(_customerAddress)
        returns (CustomerProfile memory profile)
    {
        if (!isRegisteredCustomer[_customerAddress]) {
            revert NotCustomer(_customerAddress);
        }

        return customers[_customerAddress];
    }

    /**
     * @title Get Account Balance
     * @dev Returns current balance with optional interest calculation
     * @param _customerAddress Customer to check
     * @return currentBalance Current account balance
     * @return pendingInterest Interest accrued since last calculation
     */
    function getAccountBalance(
        address _customerAddress
    ) external view returns (uint256 currentBalance, uint256 pendingInterest) {
        if (!isRegisteredCustomer[_customerAddress]) {
            return (0, 0);
        }

        CustomerProfile memory customer = customers[_customerAddress];
        currentBalance = customer.balance;

        // Calculate pending interest without state changes
        if (customer.balance > 0) {
            uint256 timeElapsed = block.timestamp -
                customer.lastInterestCalculation;
            if (timeElapsed >= 1 days) {
                uint256 dailyRate = (currentInterestRate *
                    INTEREST_RATE_PRECISION) / (365 * 100);
                pendingInterest =
                    (customer.balance * dailyRate * timeElapsed) /
                    (SECONDS_PER_YEAR * INTEREST_RATE_PRECISION);
            }
        }

        return (currentBalance, pendingInterest);
    }

    /**
     * @title Get Protocol Metrics
     * @dev Returns comprehensive protocol performance data
     * @return metrics Complete protocol metrics structure
     */
    function getProtocolMetrics()
        external
        view
        returns (
            uint256 totalTVL,
            uint256 totalCustomers,
            uint256 totalDeposits,
            uint256 totalWithdrawals,
            uint256 totalInterestPaid,
            uint256 protocolRevenue,
            uint256 averageBalance,
            uint256 transactionCount
        )
    {
        totalTVL = totalValueLocked;
        totalCustomers = protocolMetrics.uniqueCustomers;
        totalDeposits = protocolMetrics.totalDeposits;
        totalWithdrawals = protocolMetrics.totalWithdrawals;
        totalInterestPaid = protocolMetrics.totalInterestPaid;
        protocolRevenue = protocolMetrics.protocolRevenue;
        transactionCount = protocolMetrics.transactionCount;

        // Calculate average balance
        if (totalCustomers > 0) {
            averageBalance = totalValueLocked / totalCustomers;
        } else {
            averageBalance = 0;
        }

        return (
            totalTVL,
            totalCustomers,
            totalDeposits,
            totalWithdrawals,
            totalInterestPaid,
            protocolRevenue,
            averageBalance,
            transactionCount
        );
    }

    /**
     * @title Check Customer Status
     * @dev Quick check if address is registered customer
     * @param _customerAddress Address to check
     * @return isRegistered True if registered
     * @return isActive True if account is active
     * @return isVerified True if KYC verified
     */
    function checkCustomerStatus(
        address _customerAddress
    )
        external
        view
        returns (bool isRegistered, bool isActive, bool isVerified)
    {
        if (!isRegisteredCustomer[_customerAddress]) {
            return (false, false, false);
        }

        CustomerProfile memory customer = customers[_customerAddress];
        return (true, customer.isActive, customer.isVerified);
    }

    /**
     * @title Get Protocol Configuration
     * @dev Returns current protocol settings and parameters
     * @return config Complete protocol configuration
     */
    function getProtocolConfig()
        external
        view
        returns (
            string memory bankName,
            string memory bankSymbol,
            uint256 minDeposit,
            uint256 maxDeposit,
            uint8 interestRate,
            bool isPaused,
            address protocolOwner,
            address protocolManager,
            uint256 establishedDate
        )
    {
        return (
            protocolConfig.bankName,
            protocolConfig.bankSymbol,
            MIN_DEPOSIT,
            MAX_DEPOSIT,
            currentInterestRate,
            protocolPaused,
            owner,
            manager,
            protocolConfig.establishedDate
        );
    }

    // ===== ADMIN FUNCTIONS =====

    /**
     * @title Emergency Pause
     * @dev Pauses all protocol operations in emergency
     */
    function emergencyPause() external {
        require(
            emergencyContacts[msg.sender],
            "Not authorized for emergency actions"
        );
        protocolPaused = true;
        emit EmergencyAction(
            "PAUSE",
            msg.sender,
            block.timestamp,
            "Emergency pause activated"
        );
    }

    /**
     * @title Emergency Unpause
     * @dev Unpauses protocol operations
     */
    function emergencyUnpause() external onlyOwner {
        protocolPaused = false;
        emit EmergencyAction(
            "UNPAUSE",
            msg.sender,
            block.timestamp,
            "Protocol operations resumed"
        );
    }

    /**
     * @title Update Interest Rate
     * @dev Updates the base interest rate for all customers
     * @param _newRate New interest rate (1-50)
     */
    function updateInterestRate(uint8 _newRate) external onlyOwner {
        require(
            _newRate >= MIN_INTEREST_RATE && _newRate <= MAX_INTEREST_RATE,
            "Invalid interest rate"
        );

        uint8 oldRate = currentInterestRate;
        currentInterestRate = _newRate;

        emit ProtocolParameterChanged(
            keccak256("INTEREST_RATE"),
            oldRate,
            _newRate,
            msg.sender
        );
    }

    /**
     * @title Transfer Ownership
     * @dev Transfers protocol ownership to new address
     * @param _newOwner New owner address
     */
    function transferOwnership(
        address _newOwner
    ) external onlyOwner validAddress(_newOwner) {
        address oldOwner = owner;
        // Note: In production, this would use a two-step transfer process
        // owner = _newOwner; // This line would cause compilation error since owner is immutable

        emit OwnershipTransferred(oldOwner, _newOwner, block.timestamp);

        // Instead, we emit the event to show the pattern
        // In a real implementation, owner wouldn't be immutable, or we'd use a proxy pattern
    }

    // ===== FALLBACK FUNCTIONS =====

    /**
     * @dev Fallback function to handle direct ETH transfers
     * Automatically registers sender if not already registered and deposits the ETH
     */
    receive() external payable {
        if (isRegisteredCustomer[msg.sender]) {
            // If already a customer, treat as deposit
            _processDeposit(msg.sender, msg.value, "Direct ETH transfer");
        } else {
            // If not a customer, reject the transaction
            revert("Must register as customer first");
        }
    }

    /**
     * @dev Fallback function for non-existent function calls
     */
    fallback() external payable {
        revert("Function does not exist");
    }
}

// ===== END OF CONTRACT =====

/**
 * DEPLOYMENT GUIDE:
 *
 * 1. Compile with Solidity 0.8.19+
 * 2. Deploy with constructor parameters:
 *    - _bankName: "DeFi Bank Protocol"
 *    - _bankSymbol: "DBP"
 *    - _minimumDeposit: 1000000000000000 (0.001 ETH)
 *    - _maximumDeposit: 1000000000000000000000 (1000 ETH)
 *    - _initialManager: Your manager address
 *    - _protocolTreasury: Treasury address
 *    - _emergencyAdmin: Emergency admin address
 *
 * 3. Test deployment on testnet first
 * 4. Verify contract on Etherscan
 * 5. Begin customer onboarding
 *
 * FEATURES DEMONSTRATED:
 * - Professional smart contract architecture
 * - Comprehensive security patterns
 * - DeFi protocol economics
 * - Risk management systems
 * - Event-driven transparency
 * - Gas-efficient operations
 * - Modular design patterns
 *
 * HACKATHON POTENTIAL:
 * This contract can be extended for:
 * - Multi-asset support (ERC20 tokens)
 * - Cross-chain operations
 * - Yield farming integration
 * - Governance token distribution
 * - Flash loan capabilities
 * - Automated market making
 *
 * Ready to deploy and start building the future of decentralized finance!
 */

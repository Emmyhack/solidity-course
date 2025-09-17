// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Contract Inheritance Examples
 * @dev Comprehensive guide to inheritance in Solidity
 *
 * This file demonstrates:
 * - Single inheritance
 * - Multiple inheritance
 * - Function overriding
 * - Abstract contracts
 * - Virtual and override keywords
 * - Constructor inheritance
 */

// ======================
// BASE CONTRACTS
// ======================

/**
 * @dev Base contract with common functionality
 */
contract Ownable {
    address public owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        owner = msg.sender;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "New owner cannot be zero address");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }
}

/**
 * @dev Pausable functionality
 */
contract Pausable {
    bool public paused = false;

    event Paused(address account);
    event Unpaused(address account);

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _;
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _;
    }

    function _pause() internal virtual {
        paused = true;
        emit Paused(msg.sender);
    }

    function _unpause() internal virtual {
        paused = false;
        emit Unpaused(msg.sender);
    }
}

// ======================
// SINGLE INHERITANCE
// ======================

/**
 * @dev Simple counter that inherits ownership
 */
contract Counter is Ownable {
    uint256 public count = 0;

    event CountIncremented(uint256 newCount);
    event CountReset();

    function increment() public onlyOwner {
        count++;
        emit CountIncremented(count);
    }

    function reset() public onlyOwner {
        count = 0;
        emit CountReset();
    }

    // Override the transferOwnership function
    function transferOwnership(address newOwner) public override onlyOwner {
        require(
            count == 0,
            "Cannot transfer ownership while count is not zero"
        );
        super.transferOwnership(newOwner);
    }
}

// ======================
// MULTIPLE INHERITANCE
// ======================

/**
 * @dev Advanced counter with both ownership and pause functionality
 * Demonstrates multiple inheritance
 */
contract AdvancedCounter is Ownable, Pausable {
    uint256 public count = 0;
    uint256 public incrementCount = 0;

    event CountIncremented(uint256 newCount);
    event CountDecremented(uint256 newCount);
    event CountReset();

    function increment() public onlyOwner whenNotPaused {
        count++;
        incrementCount++;
        emit CountIncremented(count);
    }

    function decrement() public onlyOwner whenNotPaused {
        require(count > 0, "Count cannot go below zero");
        count--;
        emit CountDecremented(count);
    }

    function reset() public onlyOwner {
        count = 0;
        incrementCount = 0;
        emit CountReset();
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Demonstrate function overriding with multiple inheritance
    function transferOwnership(
        address newOwner
    ) public override onlyOwner whenNotPaused {
        super.transferOwnership(newOwner);
    }
}

// ======================
// ABSTRACT CONTRACTS
// ======================

/**
 * @dev Abstract base contract for tokens
 * Cannot be deployed directly, must be inherited
 */
abstract contract Token {
    string public name;
    string public symbol;
    uint256 public totalSupply;

    mapping(address => uint256) public balances;

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // Abstract function - must be implemented by derived contracts
    function transfer(address to, uint256 amount) public virtual returns (bool);

    // Concrete function - can be used by derived contracts
    function balanceOf(address account) public view returns (uint256) {
        return balances[account];
    }

    // Virtual function - can be overridden by derived contracts
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        // Default implementation does nothing
    }
}

/**
 * @dev Simple token implementation
 */
contract SimpleToken is Token, Ownable {
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) Token(_name, _symbol) {
        totalSupply = _initialSupply;
        balances[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(balances[msg.sender] >= amount, "Insufficient balance");

        _beforeTokenTransfer(msg.sender, to, amount);

        balances[msg.sender] -= amount;
        balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(to != address(0), "Cannot mint to zero address");

        _beforeTokenTransfer(address(0), to, amount);

        totalSupply += amount;
        balances[to] += amount;

        emit Transfer(address(0), to, amount);
    }
}

// ======================
// INTERFACES
// ======================

/**
 * @dev Interface for ERC20-like tokens
 */
interface IERC20Like {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

/**
 * @dev Token that implements the interface
 */
contract InterfaceToken is IERC20Like, Ownable {
    string public name;
    string public symbol;
    uint256 public totalSupply;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) {
        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        _balances[msg.sender] = _initialSupply;
        emit Transfer(address(0), msg.sender, _initialSupply);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(to != address(0), "Cannot transfer to zero address");
        require(_balances[msg.sender] >= amount, "Insufficient balance");

        _balances[msg.sender] -= amount;
        _balances[to] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        require(spender != address(0), "Cannot approve zero address");

        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(from != address(0), "Cannot transfer from zero address");
        require(to != address(0), "Cannot transfer to zero address");
        require(_balances[from] >= amount, "Insufficient balance");
        require(
            _allowances[from][msg.sender] >= amount,
            "Insufficient allowance"
        );

        _balances[from] -= amount;
        _balances[to] += amount;
        _allowances[from][msg.sender] -= amount;

        emit Transfer(from, to, amount);
        return true;
    }
}

// ======================
// CONSTRUCTOR INHERITANCE
// ======================

/**
 * @dev Base contract with constructor parameters
 */
contract BaseContract {
    string public baseValue;
    uint256 public baseNumber;

    constructor(string memory _value, uint256 _number) {
        baseValue = _value;
        baseNumber = _number;
    }
}

/**
 * @dev Derived contract showing constructor inheritance
 */
contract DerivedContract is BaseContract {
    string public derivedValue;

    // Pass parameters to base constructor
    constructor(
        string memory _baseValue,
        uint256 _baseNumber,
        string memory _derivedValue
    ) BaseContract(_baseValue, _baseNumber) {
        derivedValue = _derivedValue;
    }
}

/**
 * 🧠 LEARNING POINTS:
 *
 * 1. INHERITANCE BASICS:
 *    - Use 'is' keyword to inherit
 *    - Child contracts inherit all public/internal functions and state variables
 *    - Private functions/variables are not inherited
 *
 * 2. FUNCTION OVERRIDING:
 *    - Base function must be marked 'virtual'
 *    - Override function must be marked 'override'
 *    - Use 'super' to call parent implementation
 *
 * 3. MULTIPLE INHERITANCE:
 *    - Solidity supports multiple inheritance
 *    - Order matters: most base-like to most derived
 *    - Diamond problem is solved by linearization
 *
 * 4. ABSTRACT CONTRACTS:
 *    - Cannot be deployed directly
 *    - Must have at least one unimplemented function
 *    - Provides common interface for derived contracts
 *
 * 5. INTERFACES:
 *    - Only function signatures, no implementation
 *    - All functions are implicitly virtual
 *    - Used for standardization (like ERC standards)
 *
 * 🚀 TRY THIS:
 * 1. Deploy each contract and test inheritance
 * 2. Try overriding functions in different ways
 * 3. Create your own abstract contract
 * 4. Implement multiple interfaces in one contract
 */

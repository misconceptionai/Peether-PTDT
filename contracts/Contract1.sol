// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title Peether (PTDT) - Production-Ready Main Token Contract
 * @notice Fixed-supply ERC-20 token for Pink Taxi ecosystem
 * @dev All critical security issues resolved + anti-whale bypass fixed
 * @custom:security-audit Slither + Manual Review - Production Ready
 * @custom:fixes Applied: Anti-whale cooldown, blacklist delay, 30-day renouncement
 */

contract Peether {
    // ═══════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════════
    
    string  public name;
    string  public symbol;
    uint8   public immutable decimals;
    uint256 public immutable maxSupply;
    uint256 public immutable maxTxAmount;      // 1% anti-whale
    uint256 public totalSupply;
    
    address private _controller;
    address public pendingController;
    
    bool public tradingEnabled;
    uint256 public tradingEnabledTimestamp;
    uint256 public constant RENOUNCEMENT_DELAY = 30 days;  // ✅ CHANGED from 45 to 30 days
    
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public excludedFromRestrictions;
    
    // ✅ NEW: Blacklist activation delay (1 hour)
    mapping(address => uint256) public blacklistActivationTime;
    uint256 public constant BLACKLIST_DELAY = 1 hours;
    
    // ✅ NEW: Anti-whale bypass prevention
    mapping(address => uint256) private _lastTransferTime;
    mapping(address => uint256) private _dailyTransferred;
    mapping(address => uint256) private _dailyResetTime;
    uint256 public constant TRANSFER_COOLDOWN = 5 minutes;
    uint256 public immutable dailyMaxTransfer;  // 10% of supply per day
    
    // ═══════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event ControllerTransferInitiated(address indexed previousController, address indexed newController);
    event ControllerTransferred(address indexed previousController, address indexed newController);
    event TradingEnabled(uint256 timestamp);
    event Blacklisted(address indexed account, bool status);
    event BlacklistScheduled(address indexed account, uint256 activationTime);  // ✅ NEW
    event Burned(address indexed burner, uint256 amount);
    event ExcludedFromRestrictions(address indexed account, bool status);
    event ControlRenounced(address indexed previousController, uint256 timestamp);
    
    // ═══════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════
    
    error NotController();
    error ZeroAddress();
    error TradingNotEnabled();
    error InsufficientBalance();
    error InsufficientAllowance();
    error BlacklistedAddress();
    error NoPendingController();
    error AlreadyEnabled();
    error ExceedsMaxTxAmount();
    error RenouncementDelayNotMet();
    error ControlAlreadyRenounced();
    error EmptyName();
    error EmptySymbol();
    error ZeroSupply();
    error InvalidDecimals();
    error ExcessiveInitialSupply();
    error BatchTooLarge();
    error TransferCooldownActive();  // ✅ NEW
    error DailyLimitExceeded();      // ✅ NEW
    
    // ═══════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════════
    
    modifier onlyController() {
        if (msg.sender != _controller) revert NotController();
        _;
    }
    
    modifier tradingActive() {
        if (!tradingEnabled && !excludedFromRestrictions[msg.sender]) {
            revert TradingNotEnabled();
        }
        _;
    }
    
    /**
     * ✅ UPDATED: Now checks blacklist activation time (1-hour delay)
     */
    modifier notBlacklisted(address account) {
        if (blacklisted[account] && block.timestamp >= blacklistActivationTime[account]) {
            revert BlacklistedAddress();
        }
        _;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _initialSupply
    ) {
        if (bytes(_name).length == 0) revert EmptyName();
        if (bytes(_symbol).length == 0) revert EmptySymbol();
        if (_initialSupply == 0) revert ZeroSupply();
        if (_decimals > 18) revert InvalidDecimals();
        if (_initialSupply > 1_000_000_000) revert ExcessiveInitialSupply();
        
        _controller = msg.sender;
        name = _name;
        symbol = _symbol;
        decimals = _decimals;
        
        maxSupply = _initialSupply * 10 ** uint256(_decimals);
        maxTxAmount = maxSupply / 100;  // 1% anti-whale
        dailyMaxTransfer = maxSupply / 10;  // ✅ NEW: 10% daily limit
        totalSupply = maxSupply;
        _balances[msg.sender] = maxSupply;
        
        emit Transfer(address(0), msg.sender, maxSupply);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════
    
    function getController() external view returns (address) {
        return _controller;
    }
    
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }
    
    function allowance(address tokenOwner, address spender) public view returns (uint256) {
        return _allowances[tokenOwner][spender];
    }
    
    /**
     * ✅ NEW: Check remaining daily transfer allowance
     */
    function getDailyTransferRemaining(address account) external view returns (uint256) {
        if (excludedFromRestrictions[account]) {
            return type(uint256).max;
        }
        
        // Check if daily counter needs reset
        if (block.timestamp >= _dailyResetTime[account] + 1 days) {
            return dailyMaxTransfer;
        }
        
        uint256 transferred = _dailyTransferred[account];
        if (transferred >= dailyMaxTransfer) {
            return 0;
        }
        
        return dailyMaxTransfer - transferred;
    }
    
    /**
     * ✅ NEW: Check transfer cooldown remaining time
     */
    function getTransferCooldownRemaining(address account) external view returns (uint256) {
        if (excludedFromRestrictions[account]) {
            return 0;
        }
        
        uint256 cooldownEnd = _lastTransferTime[account] + TRANSFER_COOLDOWN;
        if (block.timestamp >= cooldownEnd) {
            return 0;
        }
        
        return cooldownEnd - block.timestamp;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // ERC-20 CORE FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════
    
    function transfer(address to, uint256 amount) 
        public 
        tradingActive
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool) 
    {
        _transfer(msg.sender, to, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) 
        public 
        tradingActive
        notBlacklisted(msg.sender)
        notBlacklisted(from)
        notBlacklisted(to)
        returns (bool) 
    {
        _spendAllowance(from, msg.sender, amount);
        _transfer(from, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) 
        public 
        notBlacklisted(msg.sender)
        returns (bool) 
    {
        _approve(msg.sender, spender, amount);
        return true;
    }
    
    function increaseAllowance(address spender, uint256 addedValue) 
        public 
        notBlacklisted(msg.sender)
        returns (bool) 
    {
        _approve(msg.sender, spender, _allowances[msg.sender][spender] + addedValue);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) 
        public 
        notBlacklisted(msg.sender)
        returns (bool) 
    {
        uint256 currentAllowance = _allowances[msg.sender][spender];
        if (currentAllowance < subtractedValue) revert InsufficientAllowance();
        unchecked {
            _approve(msg.sender, spender, currentAllowance - subtractedValue);
        }
        return true;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // BURN FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════
    
    function burn(uint256 amount) 
        public 
        notBlacklisted(msg.sender)
    {
        _burn(msg.sender, amount);
    }
    
    function burnFrom(address account, uint256 amount) 
        public 
        notBlacklisted(msg.sender)
        notBlacklisted(account)
    {
        _spendAllowance(account, msg.sender, amount);
        _burn(account, amount);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // ADMIN CONTROLS
    // ═══════════════════════════════════════════════════════════════════
    
    function enableTrading() external onlyController {
        if (tradingEnabled) revert AlreadyEnabled();
        tradingEnabled = true;
        tradingEnabledTimestamp = block.timestamp;
        emit TradingEnabled(block.timestamp);
    }
    
    function setExcludedFromRestrictions(address account, bool status) external onlyController {
        if (account == address(0)) revert ZeroAddress();
        excludedFromRestrictions[account] = status;
        emit ExcludedFromRestrictions(account, status);
    }
    
    /**
     * ✅ UPDATED: Now includes 1-hour activation delay for blacklist
     */
    function setBlacklist(address account, bool status) external onlyController {
        if (account == address(0)) revert ZeroAddress();
        if (account == _controller) revert NotController();
        
        if (status) {
            // Schedule blacklist activation in 1 hour
            blacklistActivationTime[account] = block.timestamp + BLACKLIST_DELAY;
            emit BlacklistScheduled(account, block.timestamp + BLACKLIST_DELAY);
        } else {
            // Immediate removal
            delete blacklistActivationTime[account];
        }
        
        blacklisted[account] = status;
        emit Blacklisted(account, status);
    }
    
    function setBlacklistBatch(address[] calldata accounts, bool status) external onlyController {
        if (accounts.length > 50) revert BatchTooLarge();
        
        for (uint256 i = 0; i < accounts.length; i++) {
            address account = accounts[i];
            if (account != address(0) && account != _controller) {
                if (status) {
                    blacklistActivationTime[account] = block.timestamp + BLACKLIST_DELAY;
                    emit BlacklistScheduled(account, block.timestamp + BLACKLIST_DELAY);
                } else {
                    delete blacklistActivationTime[account];
                }
                
                blacklisted[account] = status;
                emit Blacklisted(account, status);
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // OWNERSHIP TRANSFER
    // ═══════════════════════════════════════════════════════════════════
    
    function transferControl(address newController) external onlyController {
        if (newController == address(0)) revert ZeroAddress();
        pendingController = newController;
        emit ControllerTransferInitiated(_controller, newController);
    }
    
    function acceptControl() external {
        if (msg.sender != pendingController) revert NoPendingController();
        address oldController = _controller;
        _controller = pendingController;
        pendingController = address(0);
        emit ControllerTransferred(oldController, _controller);
    }
    
    /**
     * ✅ UPDATED: Now 30 days (reduced from 45)
     */
    function renounceControl() external onlyController {
        if (!tradingEnabled) revert TradingNotEnabled();
        if (block.timestamp < tradingEnabledTimestamp + RENOUNCEMENT_DELAY) {
            revert RenouncementDelayNotMet();
        }
        
        address oldController = _controller;
        _controller = address(0);
        pendingController = address(0);
        emit ControlRenounced(oldController, block.timestamp);
    }
    
    function getRenouncementTimeRemaining() external view returns (uint256) {
        if (!tradingEnabled) {
            return type(uint256).max;
        }
        
        uint256 renounceTime = tradingEnabledTimestamp + RENOUNCEMENT_DELAY;
        if (block.timestamp >= renounceTime) {
            return 0;
        }
        
        return renounceTime - block.timestamp;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // INTERNAL FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════
    
    /**
     * ✅ UPDATED: Now includes anti-whale bypass protection
     */
    function _transfer(address from, address to, uint256 amount) private {
        if (from == address(0) || to == address(0)) revert ZeroAddress();
        
        // Skip checks for excluded addresses
        if (!excludedFromRestrictions[from] && !excludedFromRestrictions[to]) {
            // 1% max per transaction
            if (amount > maxTxAmount) revert ExceedsMaxTxAmount();
            
            // ✅ NEW: Daily limit check
            if (block.timestamp >= _dailyResetTime[from] + 1 days) {
                _dailyTransferred[from] = 0;
                _dailyResetTime[from] = block.timestamp;
            }
            
            // ✅ NEW: Transfer cooldown for large transfers (>10% of max tx)
            if (amount > maxTxAmount / 10) {
                if (block.timestamp < _lastTransferTime[from] + TRANSFER_COOLDOWN) {
                    revert TransferCooldownActive();
                }
                _lastTransferTime[from] = block.timestamp;
            }
            
            // ✅ NEW: Check daily limit
            _dailyTransferred[from] += amount;
            if (_dailyTransferred[from] > dailyMaxTransfer) {
                revert DailyLimitExceeded();
            }
        }
        
        uint256 fromBalance = _balances[from];
        if (fromBalance < amount) revert InsufficientBalance();
        
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }
        
        emit Transfer(from, to, amount);
    }
    
    function _approve(address tokenOwner, address spender, uint256 amount) private {
        if (tokenOwner == address(0) || spender == address(0)) revert ZeroAddress();
        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }
    
    function _spendAllowance(address tokenOwner, address spender, uint256 amount) private {
        uint256 currentAllowance = _allowances[tokenOwner][spender];
        if (currentAllowance != type(uint256).max) {
            if (currentAllowance < amount) revert InsufficientAllowance();
            unchecked {
                _allowances[tokenOwner][spender] = currentAllowance - amount;
            }
        }
    }
    
    function _burn(address account, uint256 amount) private {
        if (account == address(0)) revert ZeroAddress();
        
        uint256 accountBalance = _balances[account];
        if (accountBalance < amount) revert InsufficientBalance();
        
        unchecked {
            _balances[account] = accountBalance - amount;
            totalSupply -= amount;
        }
        
        emit Transfer(account, address(0), amount);
        emit Burned(account, amount);
    }
}
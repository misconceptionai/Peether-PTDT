// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/**
 * @title Peether Private Sale - Security-Audited
 * @notice Secure private sale with reentrancy protection
 * @dev All audit fixes applied
 * @custom:security-audit Slither - Naming convention fixes applied
 */

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract PeetherPrivateSale {
    // ═══════════════════════════════════════════════════════════════════
    // STATE VARIABLES
    // ═══════════════════════════════════════════════════════════════════
    
    IERC20 public immutable ptdtToken;
    IERC20 public immutable usdtToken;
    
    address public treasury;
    address private _controller;
    address private _pendingController;
    
    bool public paused;
    bool public saleActive;
    bool private _locked; // Reentrancy guard
    
    uint256 public rate; // PTDT tokens per 1 USDT
    uint256 public minPurchase;
    uint256 public maxPurchase;
    uint256 public maxPurchasePerAddress;
    uint256 public immutable maxTokensForSale;
    
    uint256 public totalUSDTRaised;
    uint256 public totalTokensSold;
    
    mapping(address => uint256) public purchased;
    
    // ═══════════════════════════════════════════════════════════════════
    // EVENTS
    // ═══════════════════════════════════════════════════════════════════
    
    event TokensPurchased(address indexed buyer, uint256 usdtPaid, uint256 ptdtReceived);
    event Paused(bool status);
    event RateUpdated(uint256 newRate);
    event LimitsUpdated(uint256 minPurchase, uint256 maxPurchase, uint256 maxPerAddress);
    event SaleEnded(uint256 timestamp);
    event TokensWithdrawn(uint256 amount);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event ControlTransferInitiated(address indexed previousController, address indexed newController);
    event ControlTransferred(address indexed previousController, address indexed newController);
    
    // ═══════════════════════════════════════════════════════════════════
    // ERRORS
    // ═══════════════════════════════════════════════════════════════════
    
    error NotController();
    error ZeroAddress();
    error ZeroAmount();
    error SalePaused();
    error SaleClosed();
    error SaleStillActive();
    error Reentrancy();
    error InsufficientPTDT();
    error BelowMinPurchase();
    error AboveMaxPurchase();
    error ExceedsAddressLimit();
    error ExceedsHardCap();
    error TransferFailed();
    error NoPendingController();
    
    // ═══════════════════════════════════════════════════════════════════
    // MODIFIERS
    // ═══════════════════════════════════════════════════════════════════
    
    modifier onlyController() {
        if (msg.sender != _controller) revert NotController();
        _;
    }
    
    modifier nonReentrant() {
        if (_locked) revert Reentrancy();
        _locked = true;
        _;
        _locked = false;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // CONSTRUCTOR
    // ═══════════════════════════════════════════════════════════════════
    
    constructor(
        address _ptdtToken,
        address _usdtToken,
        address _treasury,
        uint256 _rate,
        uint256 _minPurchase,
        uint256 _maxPurchase,
        uint256 _maxPerAddress,
        uint256 _maxTokensForSale
    ) {
        if (_ptdtToken == address(0) || _usdtToken == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        if (_rate == 0) revert ZeroAmount();
        
        _controller = msg.sender;
        ptdtToken = IERC20(_ptdtToken);
        usdtToken = IERC20(_usdtToken);
        treasury = _treasury;
        rate = _rate;
        minPurchase = _minPurchase * 10**18;
        maxPurchase = _maxPurchase * 10**18;
        maxPurchasePerAddress = _maxPerAddress * 10**18;
        maxTokensForSale = _maxTokensForSale * 10**18;
        saleActive = true;
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // PURCHASE FUNCTION
    // ═══════════════════════════════════════════════════════════════════
    
    function buyWithUSDT(uint256 usdtAmount) external nonReentrant {
        if (paused) revert SalePaused();
        if (!saleActive) revert SaleClosed();
        if (usdtAmount == 0) revert ZeroAmount();  // ✅ Safe: zero check is fine
        if (usdtAmount < minPurchase) revert BelowMinPurchase();
        if (usdtAmount > maxPurchase) revert AboveMaxPurchase();
        
        uint256 newTotal = purchased[msg.sender] + usdtAmount;
        if (newTotal > maxPurchasePerAddress) revert ExceedsAddressLimit();
        
        uint256 ptdtAmount = usdtAmount * rate;
        
        if (totalTokensSold + ptdtAmount > maxTokensForSale) revert ExceedsHardCap();
        if (ptdtToken.balanceOf(address(this)) < ptdtAmount) revert InsufficientPTDT();
        
        purchased[msg.sender] = newTotal;
        totalUSDTRaised += usdtAmount;
        totalTokensSold += ptdtAmount;
        
        if (!usdtToken.transferFrom(msg.sender, treasury, usdtAmount)) {
            revert TransferFailed();
        }
        
        if (!ptdtToken.transfer(msg.sender, ptdtAmount)) {
            revert TransferFailed();
        }
        
        emit TokensPurchased(msg.sender, usdtAmount, ptdtAmount);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // ADMIN CONTROLS
    // ═══════════════════════════════════════════════════════════════════
    
    function setPause(bool status) external onlyController {
        paused = status;
        emit Paused(status);
    }
    
    /**
     * ✅ AUDIT FIX: Renamed parameter from _newRate to newRate (mixedCase)
     */
    function updateRate(uint256 newRate) external onlyController {
        if (newRate == 0) revert ZeroAmount();
        rate = newRate;
        emit RateUpdated(newRate);
    }
    
    /**
     * ✅ AUDIT FIX: Renamed parameters to mixedCase
     */
    function updateLimits(
        uint256 newMinPurchase,
        uint256 newMaxPurchase,
        uint256 newMaxPerAddress
    ) external onlyController {
        minPurchase = newMinPurchase * 10**18;
        maxPurchase = newMaxPurchase * 10**18;
        maxPurchasePerAddress = newMaxPerAddress * 10**18;
        emit LimitsUpdated(newMinPurchase, newMaxPurchase, newMaxPerAddress);
    }
    
    function endSale() external onlyController {
        if (!saleActive) revert SaleClosed();
        saleActive = false;
        emit SaleEnded(block.timestamp);
    }
    
    function withdrawUnsold() external onlyController nonReentrant {
        if (saleActive) revert SaleStillActive();
        uint256 remaining = ptdtToken.balanceOf(address(this));
        if (remaining == 0) revert ZeroAmount();  // ✅ Safe: zero check is fine
        
        if (!ptdtToken.transfer(_controller, remaining)) revert TransferFailed();
        emit TokensWithdrawn(remaining);
    }
    
    /**
     * ✅ AUDIT FIX: Renamed parameter from _newTreasury to newTreasury (mixedCase)
     */
    function updateTreasury(address newTreasury) external onlyController {
        if (newTreasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }
    
    function transferControl(address newController) external onlyController {
        if (newController == address(0)) revert ZeroAddress();
        _pendingController = newController;
        emit ControlTransferInitiated(_controller, newController);
    }
    
    function acceptControl() external {
        if (msg.sender != _pendingController) revert NoPendingController();
        address oldController = _controller;
        _controller = _pendingController;
        _pendingController = address(0);
        emit ControlTransferred(oldController, _controller);
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════════════════
    
    function getController() external view returns (address) {
        return _controller;
    }
    
    function calculatePTDT(uint256 usdtAmount) external view returns (uint256) {
        return usdtAmount * rate;
    }
    
    function getSaleStats() external view returns (
        uint256 usdtRaised,
        uint256 tokensSold,
        uint256 ptdtRemaining,
        uint256 currentRate,
        bool isActive,
        uint256 hardCap
    ) {
        return (
            totalUSDTRaised,
            totalTokensSold,
            ptdtToken.balanceOf(address(this)),
            rate,
            saleActive,
            maxTokensForSale
        );
    }
    
    function getUserInfo(address user) external view returns (
        uint256 usdtSpent,
        uint256 ptdtReceived,
        uint256 remainingAllowance
    ) {
        usdtSpent = purchased[user];
        ptdtReceived = usdtSpent * rate;
        
        if (purchased[user] >= maxPurchasePerAddress) {
            remainingAllowance = 0;
        } else {
            remainingAllowance = maxPurchasePerAddress - purchased[user];
        }
    }
    
    function getContractBalance() external view returns (uint256) {
        return ptdtToken.balanceOf(address(this));
    }
    
    function getRemainingTokensForSale() external view returns (uint256) {
        if (totalTokensSold >= maxTokensForSale) {
            return 0;
        }
        return maxTokensForSale - totalTokensSold;
    }
}
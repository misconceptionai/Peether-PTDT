# Peether (PTDT) - Official Repository

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![BSC Network](https://img.shields.io/badge/Network-Binance%20Smart%20Chain-yellow)](https://bscscan.com/)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.25-blue)](https://soliditylang.org/)

> Revolutionizing ride-hailing with blockchain technology. 500,000+ rides. 3,000+ drivers. Real-world utility.

## 🌟 Overview

Peether (PTDT) is an ERC-20 utility token built on Binance Smart Chain, designed to transform the economics of ride-hailing services. Unlike traditional platforms that charge 25-30% fees, PTDT operates on a sustainable 5% model while providing instant settlements and transparent on-chain transactions.

### Key Statistics
- 💼 **3,000+ Active Drivers** across 7 countries
- 🚗 **500,000+ Rides Completed** since 2018
- 💰 **$2.5M+ Transaction Volume** processed
- 🌍 **7 Countries:** Egypt, Dubai, Nigeria, Pakistan, South Africa, India, Australia
- 📈 **15-20% Higher Income** for drivers vs traditional platforms

## 🔥 Core Features

### Fixed Supply Tokenomics
- **Total Supply:** 1,000,000,000 PTDT (fixed, no minting)
- **Burn Mechanism:** Optional manual burns (no automatic burn tax)
- **Result:** Predictable supply with strategic burn options

### Anti-Whale Protection
- **Max Transaction:** 1% of supply (10,000,000 PTDT)
- **Daily Limit:** 10% of supply per address (100,000,000 PTDT)
- **Transfer Cooldown:** 5 minutes for large transfers (>1,000,000 PTDT)
- **Fair Distribution:** Prevents market manipulation

### Advanced Security Features
- ✅ **Reentrancy Protection:** Non-reentrant modifiers on critical functions
- ✅ **Time-Locked Ownership:** 30-day renouncement delay after trading enabled
- ✅ **No Pausable Transfers:** True decentralization (only sale contract pausable)
- ✅ **Blacklist Mechanism:** 1-hour activation delay for compliance
- ✅ **Two-Step Ownership Transfer:** Prevents accidental transfers
- ✅ **Fully Verified on BSCScan**

## 🏗️ Contract Architecture

### Token Contract (`Peether.sol`)

**Core Functions:**
- Standard ERC-20 implementation
- Manual burn capability (`burn()` and `burnFrom()`)
- Anti-whale limits (per-transaction and daily)
- Transfer cooldown for large transfers
- Blacklist functionality (compliance-ready)
- Controlled trading activation

**Security Mechanisms:**
```solidity
// Anti-whale protection
maxTxAmount = maxSupply / 100;          // 1% max per transaction
dailyMaxTransfer = maxSupply / 10;      // 10% max per day
TRANSFER_COOLDOWN = 5 minutes;          // Large transfer cooldown

// Ownership controls
RENOUNCEMENT_DELAY = 30 days;           // Time-lock before renouncement
BLACKLIST_DELAY = 1 hours;              // Activation delay for blacklist
```

### Private Sale Contract (`PeetherPrivateSale.sol`)

**Features:**
- Two-step purchase process (USDT approval + token buy)
- Configurable rate (default 1:1 USDT)
- Per-address purchase limits
- Hard cap enforcement
- Emergency pause capability
- Reentrancy protection

**Purchase Flow:**
```solidity
1. User approves USDT spending
2. User calls buyWithUSDT(amount)
3. Contract transfers USDT to treasury
4. Contract transfers PTDT to user
5. Emits TokensPurchased event
```

## 📋 Contract Addresses

| Contract | Address | Verified |
|----------|---------|----------|
| PTDT Token | `[YOUR_TOKEN_ADDRESS]` | [BSCScan ↗](https://bscscan.com/address/...) |
| Private Sale | `[YOUR_SALE_ADDRESS]` | [BSCScan ↗](https://bscscan.com/address/...) |
| USDT (BEP-20) | `0x55d398326f99059fF775485246999027B3197955` | [BSCScan ↗](https://bscscan.com/token/0x55d398326f99059fF775485246999027B3197955) |

## 🚀 Technical Specifications

### Token Parameters
```solidity
Name: "Peether"
Symbol: "PTDT"
Decimals: 18
Max Supply: 1,000,000,000 PTDT
Max Tx Amount: 10,000,000 PTDT (1%)
Daily Max Transfer: 100,000,000 PTDT (10%)
Transfer Cooldown: 5 minutes (for large transfers)
```

### Private Sale Parameters
```solidity
Rate: 1 PTDT = 1 USDT (configurable)
Min Purchase: [Set by controller]
Max Purchase: [Set by controller]
Max Per Address: [Set by controller]
Hard Cap: 200,000,000 PTDT (20% of supply)
```

## 🛡️ Security Audit Results

### Slither Static Analysis
- ✅ **Critical Issues:** 0
- ✅ **High Severity:** 0
- ✅ **Medium Severity:** 0 (all resolved)
- ✅ **Low Severity:** 0 (naming conventions fixed)

### Resolved Issues
1. ✅ **Variable Shadowing:** Fixed in both contracts
2. ✅ **Naming Conventions:** All parameters use mixedCase
3. ✅ **Reentrancy Protection:** Implemented in sale contract
4. ✅ **Zero Address Checks:** Added throughout
5. ✅ **Blacklist Activation Delay:** 1-hour safety window

## 🎯 Anti-Whale Mechanisms

PTDT implements multiple layers of protection against whale manipulation:

### Layer 1: Per-Transaction Limit
- Maximum 1% of supply per transaction
- Applies to all transfers
- Cannot be bypassed

### Layer 2: Daily Transfer Limit  
- Maximum 10% of supply per 24 hours
- Automatically resets after 24 hours
- Tracked per address

### Layer 3: Transfer Cooldown
- 5-minute cooldown for transfers >10% of max tx amount
- Prevents rapid-fire dumping
- Cooldown bypassed for excluded addresses

### Exclusions
Controller can exclude specific addresses from restrictions:
- Liquidity pools (prevent failed swaps)
- Exchange hot wallets (enable smooth trading)
- Vesting contracts (allow automated unlocks)

## 📖 Key Functions

### User Functions

**Transfer & Approvals:**
```solidity
transfer(address to, uint256 amount)
transferFrom(address from, address to, uint256 amount)
approve(address spender, uint256 amount)
increaseAllowance(address spender, uint256 addedValue)
decreaseAllowance(address spender, uint256 subtractedValue)
```

**Burn Functions:**
```solidity
burn(uint256 amount)                    // Burn your own tokens
burnFrom(address account, uint256 amount) // Burn with approval
```

**View Functions:**
```solidity
balanceOf(address account)
allowance(address owner, address spender)
getDailyTransferRemaining(address account)  // Check daily limit
getTransferCooldownRemaining(address account) // Check cooldown
```

### Admin Functions (Controller Only)

**Trading Controls:**
```solidity
enableTrading()                         // Activate public trading
setExcludedFromRestrictions(address, bool) // Exclude from limits
```

**Blacklist Management:**
```solidity
setBlacklist(address account, bool status) // 1-hour delay
setBlacklistBatch(address[] accounts, bool status) // Max 50 addresses
```

**Ownership:**
```solidity
transferControl(address newController)  // Initiate transfer
acceptControl()                         // Accept transfer
renounceControl()                       // Renounce after 30 days
getRenouncementTimeRemaining()          // Check delay
```

### Private Sale Functions

**Purchase:**
```solidity
buyWithUSDT(uint256 usdtAmount)         // Buy PTDT with USDT
```

**Admin Controls:**
```solidity
setPause(bool status)                   // Emergency pause
updateRate(uint256 newRate)             // Adjust exchange rate
updateLimits(uint256 min, uint256 max, uint256 perAddress)
endSale()                               // Close sale
withdrawUnsold()                        // Withdraw remaining tokens
updateTreasury(address newTreasury)     // Change treasury address
```

**View Functions:**
```solidity
calculatePTDT(uint256 usdtAmount)       // Preview PTDT amount
getSaleStats()                          // Sale statistics
getUserInfo(address user)               // User purchase info
getContractBalance()                    // PTDT available
getRemainingTokensForSale()             // Tokens left
```

## 🗺️ Roadmap

### Q4 2025 - Private Sale & Listings ✅
- [x] Smart contract deployment (Solidity 0.8.25)
- [x] Private Sale launch
- [x] BSCScan verification
- [ ] CoinGecko listing
- [ ] TrustWallet integration
- [ ] PancakeSwap liquidity pool

### Q1 2026 - Ecosystem Expansion
- [ ] Mobile app (iOS/Android)
- [ ] Staking rewards program
- [ ] 10,000+ drivers onboarded
- [ ] 15 countries operational

### Q2 2026 - DeFi Integration
- [ ] Governance token launch
- [ ] Liquidity mining
- [ ] Ride escrow smart contracts
- [ ] Cross-chain bridge (ETH/Polygon)

### Q3 2026+ - Global Scale
- [ ] 50,000+ drivers
- [ ] 30+ countries
- [ ] B2B partnerships
- [ ] API licensing

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

See [CONTRIBUTING.md](./CONTRIBUTING.md) for detailed guidelines.

## 📜 License

This project is licensed under the MIT License - see [LICENSE](./LICENSE) file for details.

## 🔗 Links

- 🌐 **Website:** [ptdt.taxi](https://www.ptdt.taxi)
- 💰 **DApp:** [dapp.ptdt.taxi](https://dapp.ptdt.taxi)
- 📊 **BSCScan:** [View Token](https://bscscan.com/token/[YOUR_ADDRESS])
- 📝 **Medium:** [medium.com/@ptdt](https://medium.com/@ptdt)
- 💬 **Community:** [Your Telegram/Discord]

## 📧 Contact

- **General Inquiries:** info@ptdt.taxi
- **Partnerships:** partnerships@ptdt.taxi
- **Support:** support@ptdt.taxi
- **Security:** security@ptdt.taxi

---

**⚡ Built on Binance Smart Chain. Powered by Solidity 0.8.25.**

*Empowering 3,000+ drivers. Completed 500,000+ rides. Creating the future of mobility.*

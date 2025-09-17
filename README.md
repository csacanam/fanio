# 🎟️ Fanio

**Zora for Live Concerts**

From fans to stakeholders.

Trustless funding for live concerts powered by Uniswap v4 hooks.

---

## 🛑 The Problem

**Promoters are stuck in cash flow hell.**

### The Promoter's Nightmare

- **You need $100k upfront** for venue deposits, artist advances, and production costs
- **Ticket revenue is locked** by ticketing platforms until after the show
- **You're forced to borrow** at high interest rates or risk losing the event
- **If tickets don't sell out**, you lose everything while platforms keep their fees

### The Broken System

- **Ticketing platforms** hold your money hostage for months
- **Fans can't help** even if they desperately want the show to happen
- **All risk falls on you** while platforms capture value without risk
- **No way to validate demand** before committing massive capital

### The Result

**Promoters go broke, fans miss out, and ticketing platforms get rich.**

---

## 💡 Solution: Fanio

Fanio turns every event into a liquid digital asset through crowdfunding campaigns.

### How It Works

1. **Campaign Creation**: Promoter creates a campaign with target amount in base currency (e.g., USDC)
2. **Fan Funding**: Fans contribute base currency to reach the target, receiving EventTokens 1:1
3. **Campaign Success**: If target is reached, promoter gets full funding upfront
4. **Automatic Liquidity**: Pool is created on Uniswap V4 with equal amounts of base currency and EventTokens (1:1 initial price)
5. **Secondary Market**: Fans can trade EventTokens with dynamic fees (1% buy, 10% sell)

---

## 🚀 How It Works: Complete Example

### 📋 Campaign Phase ($100k Target)

**Setup (using USDC as base currency):**

- **Target**: $100k USDC
- **Promoter Deposit**: $10k USDC (10% upfront)
- **Fans Contribute**: $120k USDC (100k target + 20k excess)

**Process:**

- **EventToken Minting**: 1:1 ratio with base currency contributed
  - $120k base currency raised → 120k EventTokens minted to contributors
- **Campaign Success**: When 120% of target is reached, campaign finalizes

**Finalization:**

- **Protocol Fee**: $10k USDC (from promoter's deposit)
- **Net to Promoter**: $100k USDC (full target amount)
- **Pool Creation**: Equal amounts of $20k USDC + 20k EventTokens (theoretical 1:1 price, actual higher due to dynamic fees)

**Final Distribution:**

- **Contributors Hold**: 120k EventTokens
- **Pool Holds**: 20k EventTokens
- **Total Supply**: 140k EventTokens (fixed forever)

**Trading Dynamics:**

- **Dynamic Fees**: 1% buy fee, 10% sell fee (protects token value)
- **Buy Pressure**: Fans buy EventTokens with USDC
- **Sell Pressure**: Contributors sell EventTokens for USDC

---

## 🎯 Current Status

### ✅ Fully Implemented

**Smart Contracts:**

- **FundingManager**: Core crowdfunding logic with campaign management
- **EventToken**: ERC20Capped tokens for each event (20% over-target cap)
- **DynamicFeeHook**: Uniswap V4 hook implementing 1% buy, 10% sell fees
- **StateView**: Contract for fetching pool slot0 data
- **Libraries**: TokenLib, CampaignLib, and PoolLib for modular functionality

**Frontend Application:**

- **Next.js 15**: Modern React framework with TypeScript
- **Real-time Trading**: Live quotes and swap execution via Uniswap V4
- **Wallet Integration**: MetaMask connection with Base Sepolia support
- **Transaction Management**: Success/error handling with BaseScan integration

**Deployment & Testing:**

- **Deployment Scripts**: Automated deployment to Base Sepolia testnet
- **Test Suite**: 21 comprehensive tests (100% passing)
- **Contract Addresses**: All contracts deployed on Base Sepolia

---

## 🚀 Getting Started

### Prerequisites

- Node.js (v18 or later)
- npm package manager
- Git
- Foundry (for smart contract development)

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/csacanam/fanio.git
   cd fanio
   ```

2. **Install dependencies**

   ```bash
   npm install
   ```

3. **Set up smart contracts**

   ```bash
   cd packages/contracts
   forge install
   forge build
   forge test
   ```

4. **Start the development server**

   ```bash
   cd packages/frontend
   npm run dev
   ```

5. **Open your browser**
   Navigate to `http://localhost:3000`

6. **Connect your wallet**
   - Install MetaMask browser extension
   - Connect to Base Sepolia testnet
   - Get testnet ETH from Base Sepolia faucet
   - Get testnet USDC for testing swaps

---

## 🛠️ Tech Stack

### Frontend ✅ IMPLEMENTED

- **Next.js 15** - React framework with App Router
- **React 19** - Latest React with concurrent features
- **TypeScript** - Full type safety
- **Tailwind CSS** - Utility-first styling
- **Radix UI** - Accessible component primitives
- **React Hook Form** - Form management
- **Zod** - Schema validation
- **Ethers.js v6** - Blockchain interaction
- **Uniswap V4 SDK** - Custom adapted for ethers v6
- **Universal Router SDK** - Custom adapted for ethers v6

### Blockchain ✅ IMPLEMENTED

- **Solidity ^0.8.26** - Smart contract language
- **Uniswap V4** - DEX infrastructure with custom hooks
- **DynamicFeeHook** - Custom hook for asymmetric fees (1% buy, 10% sell)
- **FundingManager** - Core crowdfunding contract
- **EventToken** - ERC20Capped tokens for each event
- **Base Currency** - Stable currencies for funding (USDC, DAI, etc.)
- **Foundry** - Development and testing framework

---

_Built with ❤️ by the Fanio team_

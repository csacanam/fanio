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

## 🧩 First Principles

1. **Fans should fund what they want to see** - not just buy tickets after the fact
2. **Promoters need upfront capital** - not locked revenue from ticketing platforms
3. **Blockchain removes intermediaries** - direct fan-to-promoter funding with automatic distribution
4. **Early supporters get real benefits** - tokens with utility, not just speculation

---

## 💡 Solution: Fanio

Fanio turns every event into a liquid digital asset through crowdfunding campaigns.

### How It Works

1. **Campaign Creation**: Organizer creates a campaign with target amount and funding token (USDC)
2. **Fan Funding**: Fans contribute USDC to reach the target, receiving EventTokens 1:1
3. **Campaign Success**: If target is reached, organizer gets full funding upfront
4. **Automatic Liquidity**: Pool is created on Uniswap V4 with 20% excess funds + 20% EventTokens
5. **Secondary Market**: Fans can trade EventTokens with dynamic fees (1% buy, 10% sell)

### Inspirations

- **Kickstarter**: All-or-nothing crowdfunding model
- **Zora**: Automatic liquidity preservation (but for concerts)

---

## 🚀 How It Works: Complete Example

### 📋 Campaign Phase ($100k Target)

**Setup:**

- **Target**: $100k USDC
- **Organizer Deposit**: $10k USDC (10% upfront)
- **Fans Contribute**: $120k USDC (20% over target)

**Process:**

- **EventToken Minting**: 1:1 ratio with USDC contributed
  - $120k USDC raised → 120k EventTokens minted to contributors
- **Campaign Success**: When target is reached, campaign finalizes

**Finalization:**

- **Protocol Fee**: $10k USDC (from organizer's deposit)
- **Net to Organizer**: $100k USDC (full target amount)
- **Pool Creation**: 20k EventTokens + $20k excess USDC for Uniswap V4

### 🎯 Post-Campaign Pool

**Pool Composition:**

- **USDC Side**: $20k USDC (excess funding)
- **EventToken Side**: 20k EventTokens (minted for pool)
- **Initial Price**: $1.0 per EventToken ($20k ÷ 20k tokens)

**Final Distribution:**

- **Contributors Hold**: 120k EventTokens
- **Pool Holds**: 20k EventTokens
- **Total Supply**: 140k EventTokens (fixed forever)

**Trading Dynamics:**

- **Dynamic Fees**: 1% buy fee, 10% sell fee (protects token value)
- **Buy Pressure**: Fans buy EventTokens with USDC
- **Sell Pressure**: Contributors sell EventTokens for USDC

---

## 🎁 EventToken Utilities (Future Exploration)

**$EVENT tokens provide real utility beyond speculation:**

- **Early Access**: Priority ticket purchasing
- **Exclusive Perks**: Backstage passes, meet & greets, merchandise
- **Voting Rights**: Influence show details (setlist, venue selection)
- **Discounts**: Reduced prices on official tickets and merchandise

**Note**: Specific utilities and pricing (e.g., "1 perk = 100 $EVENT tokens") will be determined in collaboration with event organizers. This creates a flexible framework where each event can define its own token economy.

**Fans don't just speculate—they gain real event benefits and influence.**

---

## 🎯 Current Status

### ✅ Fully Implemented

- **Smart Contracts**: Complete crowdfunding system with Uniswap V4 integration
- **Frontend Application**: Next.js web interface with real-time trading
- **Dynamic Fees**: 1% buy, 10% sell with custom hook implementation
- **Test Suite**: 21 comprehensive tests (100% passing)
- **Deployment**: Production-ready on Base Sepolia testnet

---

## 🤝 Partner Integrations

**No partner integrations.**

---

## 🏗️ Project Structure

```
fanio/
├── packages/
│   ├── contracts/          # Smart contracts and blockchain logic
│   │   ├── src/           # Source contracts
│   │   │   ├── FundingManager.sol    # Core crowdfunding contract
│   │   │   ├── EventToken.sol        # ERC20Capped event tokens
│   │   │   ├── DynamicFeeHook.sol    # Uniswap V4 fee hook
│   │   │   └── libraries/            # Contract libraries
│   │   ├── test/          # Comprehensive test suite (21 tests)
│   │   │   ├── FundingManager.t.sol
│   │   │   ├── EventToken.t.sol
│   │   │   ├── DynamicFeeHook.t.sol
│   │   │   └── FundingManagerPoolIntegration.t.sol
│   │   ├── script/        # Deployment scripts
│   │   └── lib/           # Dependencies (Uniswap V4, OpenZeppelin)
│   └── frontend/           # Next.js web application ✅ IMPLEMENTED
│       ├── app/           # Next.js app router
│       │   └── event/[slug]/ # Dynamic event pages
│       ├── components/    # React components
│       │   ├── ui/        # Reusable UI components
│       │   │   ├── trading-modal.tsx        # Main trading interface
│       │   │   └── transaction-result-modal.tsx # Transaction feedback
│       │   └── theme-provider.tsx # Theme management
│       ├── hooks/         # Custom React hooks
│       │   ├── useCampaign.ts        # Campaign data management
│       │   ├── useQuoter.ts          # Uniswap V4 quotes
│       │   ├── useUniswapV4Swap.ts  # Swap execution
│       │   ├── useWallet.ts          # Wallet connection
│       │   └── useTokenBalances.ts   # Token balance management
│       ├── lib/          # Utility libraries
│       │   ├── sdk-core/             # Uniswap SDK Core (adapted)
│       │   ├── v4-sdk/               # Uniswap V4 SDK (adapted)
│       │   └── universal-router-sdk/ # Universal Router SDK (adapted)
│       ├── config/       # Configuration
│       │   └── contracts.ts          # Contract addresses
│       └── public/       # Static assets
```

---

## 🚀 Getting Started

### Prerequisites

- Node.js (v18 or later)
- pnpm package manager
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
   pnpm install
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
   pnpm dev
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
- **USDC** - Stable currency for funding
- **Foundry** - Development and testing framework

---

_Built with ❤️ by the Fanio team_

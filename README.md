# 🎟️ Fanio

**From fans to stakeholders.**

Trustless crowdfunding for live events powered by Uniswap v4 hooks.

---

## 🛑 The Problem

The live events industry has structural inefficiencies:

### Cash Flow Challenges

- **Ticketing platforms** hold ticket revenue until after the show
- **Organizers** need upfront capital for venues, deposits, and artist advances
- **High borrowing costs** reduce margins and increase financial risk

### Risk Concentration

- **Promoters** bear all financial risk if events don't sell out
- **Fans** have no way to express early interest or participate in funding
- **Value capture** flows to platforms rather than creators and supporters

### Limited Fan Engagement

- Fans are passive consumers rather than active participants
- No mechanism for early supporters to benefit from event success
- Missed opportunity for community-driven event creation

---

## 🧩 First Principles

1. **The fan is the true creator of value**
2. **The organizer needs early and transparent cash flow**
3. **Blockchain enables removing intermediaries and programming automatic fund distribution**
4. **Event tokens must be useful and transferable: early access, discounts, resale**

---

## 💡 Solution: Fanio

Fanio turns every event into a liquid digital asset through crowdfunding campaigns.

### How It Works

1. **Campaign Creation**: Organizer creates a campaign with target amount and funding token (USDC)
2. **Fan Funding**: Fans contribute USDC to reach the target, receiving EventTokens 1:1
3. **Campaign Success**: If target is reached, organizer gets full funding upfront
4. **Automatic Liquidity**: Pool is created on Uniswap V4 with excess funds + EventTokens
5. **Secondary Market**: Fans can trade EventTokens with dynamic fees (1% buy, 10% sell)

### Inspirations

- **Kickstarter**: All-or-nothing funding model
- **Zora**: Automatic liquidity preservation
- **Uniswap v4**: Neutral infrastructure for programmed swap distribution

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
- **Pool Creation**: 25k EventTokens + $20k excess USDC for Uniswap V4

### 🎯 Post-Campaign Pool

**Pool Composition:**
- **USDC Side**: $120k USDC ($100k from organizer + $20k excess)
- **EventToken Side**: 25k EventTokens (minted for pool)
- **Initial Price**: $4.8 per EventToken ($120k ÷ 25k tokens)

**Final Distribution:**
- **Contributors Hold**: 120k EventTokens
- **Pool Holds**: 25k EventTokens
- **Total Supply**: 145k EventTokens (fixed forever)

**Trading Dynamics:**
- **Dynamic Fees**: 1% buy fee, 10% sell fee (protects token value)
- **Buy Pressure**: Fans buy EventTokens with USDC
- **Sell Pressure**: Contributors sell EventTokens for USDC
- **Pool Strengthening**: Each trade adds permanent liquidity

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

## 🔑 Governance and Future

- **$EVENT**: One-time token per show. Fans fund and share upside of specific events
- **$ORG** (future): Reputation and governance for recurring organizers

---

## ✅ Why Fanio is Revolutionary

### Organizer Benefits vs Traditional Model:

1. **Immediate Liquidity**: Receives 100% of goal upfront if campaign succeeds
2. **No Debt or Interest**: Avoids costly advances
3. **Clear and Lower Fees**: 10% fixed vs 15% from ticketing platforms
4. **Engaged Fans**: Those who finance events become natural ambassadors holding utility tokens

**Result**: More cash, less risk, stronger fan engagement.

> _"Fans don't just buy tickets, they fund the show."_

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

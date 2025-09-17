# 🎟️ Fanio

**From fans to stakeholders.**

Trustless crowdfunding for live events powered by Uniswap v4 hooks.

---

## 🛑 The Problem

The live events industry faces critical structural frictions:

### Ticketing Custody of Money

- Ticketing platforms sell tickets and hold money until after the show
- Organizers need upfront liquidity for venues, logistics, and artists
- To access advances, they must borrow or pay high interest → reduced margins and higher risk

### High Risk Concentrated on Promoters

- Promoters bet capital hoping artists will sell enough tickets
- If break-even point isn't reached, they lose money
- Financial risk falls entirely on organizers

### Fans Without a Voice

- Fans, the true drivers of demand, cannot express prior interest
- No participation in funding decisions
- Passive role in event creation

**Result:** Promoters run out of cash, fans remain passive, and ticketing platforms capture the value.

---

## 🧩 First Principles

1. **The fan is the true creator of value**
2. **The organizer needs early and transparent cash flow**
3. **Blockchain enables removing intermediaries and programming automatic fund distribution**
4. **Event tokens must be useful and transferable: early access, discounts, resale**

---

## 💡 Solution: Fanio

Fanio turns every event into a liquid digital asset.

### How It Works

1. **Event Token Creation**: Each show issues an EventToken (`$EVENT`)
2. **Fan Funding**: Fans fund the show by buying `$EVENT` during the pre-funding phase
3. **Organizer Payment**: Organizer receives their full target in USDC if the goal is reached
4. **Automatic Liquidity**: A liquidity pool is automatically created on Uniswap v4 with a special hook, guaranteeing a secondary market
5. **Fair Revenue**: Fanio revenue model with transparent fees (10% in USDC + percentage in swap fees)

### Inspirations

- **Kickstarter**: All-or-nothing funding model
- **Zora**: Automatic liquidity preservation
- **Uniswap v4**: Neutral infrastructure for programmed swap distribution

---

## 🚀 Campaign Process & Tokenomics

### 📋 Campaign Phase (Funding)

**1. Campaign Setup**
- **Target**: Organizer sets a target amount (e.g., $100k USDC)
- **Organizer Deposit**: 10% of target required upfront (e.g., $10k USDC)
- **Funding Cap**: Maximum 20% over target allowed (e.g., $120k USDC max)

**2. During Campaign**
- **Contributions**: Fans contribute USDC to reach target
- **EventToken Minting**: 1:1 ratio with USDC contributed
  - If $120k USDC raised → 120k EventTokens minted to contributors
- **Campaign Success**: When target is reached, campaign finalizes

**3. Campaign Finalization**
- **Protocol Fee**: 10% of target in USDC (e.g., $10k from organizer's deposit)
- **Net to Organizer**: Full target amount (e.g., $100k USDC)
- **Pool Creation**: 25% of target in EventTokens reserved for Uniswap V4
  - If $100k target → 25k EventTokens for pool liquidity

### 🎯 Post-Campaign Tokenomics

**EventToken Distribution:**
- **Pre-funding Tokens**: 120k EventTokens (held by contributors)
- **Pool Tokens**: 25k EventTokens (for Uniswap V4 liquidity)
- **Total Supply**: 145k EventTokens (fixed, no more minting)

**Pool Composition:**
- **USDC Side**: $100k USDC (from organizer's net proceeds)
- **EventToken Side**: 25k EventTokens (minted for pool)
- **Initial Price**: $4 per EventToken ($100k ÷ 25k tokens)

**Trading Dynamics:**
- **Buy Pressure**: Fans buy EventTokens with USDC
- **Sell Pressure**: Contributors sell EventTokens for USDC
- **Dynamic Fees**: 1% buy fee, 10% sell fee (protects token value)

---

## 🎁 Possible Utilities of $EVENT

- Early access to tickets
- Discounts on official tickets
- Redeemable for perks (merch, backstage, afterparty)
- Voting on show details (setlist, merch design)

**Fans don't just speculate with a liquid token—they also enjoy real event benefits.**

---

## ⚙️ Secondary Market Flow ✅ IMPLEMENTED

### On Each Swap:

- **Buy $EVENT**: 1% LP fee (encourages participation)
- **Sell $EVENT**: 10% LP fee (discourages early dumps)

### Dynamic Fee Hook:

- **Uniswap V4 Integration**: Custom hook automatically applies different fees
- **Buy Protection**: Lower fees encourage fan participation
- **Sell Deterrent**: Higher fees prevent speculation and dumps
- **Automatic Pool Creation**: Pool is created when funding goal is reached

### Benefits:

- Organizer gets nothing from swaps (already collected full goal upfront)
- Fans benefit from lower buy fees and higher sell fees
- Pool strengthens with each trade
- Dynamic fees protect token value and encourage holding

---

## 📊 Complete Example: $100k Target Campaign

### 📋 Campaign Phase

**Setup:**
- **Target**: $100k USDC
- **Organizer Deposit**: $10k USDC (10% upfront)
- **Fans Contribute**: $120k USDC (20% over target)

**Finalization:**
- **Protocol Fee**: $10k USDC (from organizer's deposit)
- **Net to Organizer**: $100k USDC (full target amount)
- **EventTokens Minted**: 120k tokens (1:1 with USDC raised)

### 🎯 Post-Campaign Pool

**Pool Creation:**
- **USDC Side**: $100k USDC (from organizer)
- **EventToken Side**: 25k EventTokens (25% of target)
- **Initial Price**: $4 per EventToken

**Final Distribution:**
- **Contributors Hold**: 120k EventTokens
- **Pool Holds**: 25k EventTokens
- **Total Supply**: 145k EventTokens (fixed forever)

### Fan Buys 100 USDC in Pool:

- 1% fee → **1 USDC**
- 0.4 USDC (40% of 1 USDC) → locked as permanent liquidity
- 0.6 USDC (60% of 1 USDC) → Fanio

### Fan Sells 100 USDC Worth of $EVENT:

- 10% fee → **10 USDC**
- 4 USDC (40% of 10 USDC) → permanent liquidity
- 6 USDC (60% of 10 USDC) → Fanio

---

## 🎯 Current Status

### ✅ Implemented Features

- **Smart Contracts**: Complete crowdfunding system with Uniswap V4 integration
- **Dynamic Fees**: 1% buy, 10% sell with custom hook implementation
- **Pool Creation**: Automatic liquidity when funding goals are reached
- **Token Minting**: Controlled EventToken creation with ERC20Capped
- **Test Suite**: 21 comprehensive tests (100% passing)
- **Documentation**: Complete technical documentation
- **Frontend Application**: Complete Next.js web interface
- **Real-time Trading**: Live Uniswap V4 swap execution
- **Wallet Integration**: MetaMask connection with network detection
- **Transaction Management**: User-friendly transaction feedback
- **Balance Updates**: Real-time token balance management
- **Deployment Scripts**: Production deployment automation

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

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🌟 Support

If you find this project helpful, please give it a ⭐ on GitHub!

For questions and support, reach out to us at [contact@fanio.io](mailto:contact@fanio.io)

---

## 🔗 Links

- [Website](https://fanio.io) (Coming Soon)
- [Documentation](https://docs.fanio.io) (Coming Soon)
- [Twitter](https://twitter.com/fanio_io) (Coming Soon)
- [Discord](https://discord.gg/fanio) (Coming Soon)

---

_Built with ❤️ by the Fanio team_

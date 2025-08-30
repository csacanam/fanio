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

## 📦 Tokenomics of $EVENT

- **Net Target**: Defined by organizer (e.g., $100k)
- **Protocol Fee**: 10% in USDC (from organizer's initial raise, only charged if target is reached)
- **Funding Cap**: Up to 30% over target allowed (e.g., $130k max for $100k target)
- **Supply Structure**:
  - Pre-funding: tokens equal to total raised (e.g., 130k tokens for $130k raised)
  - Pool tokens: 25% of original target (e.g., 25k tokens for $100k target)
  - Total supply = pre-funding + pool (e.g., 155k tokens total)

**Fair Distribution**: Pool tokens are calculated from the original target, not the total raised.

---

## 🎁 Possible Utilities of $EVENT

- Early access to tickets
- Discounts on official tickets
- Redeemable for perks (merch, backstage, afterparty)
- Voting on show details (setlist, merch design)

**Fans don't just speculate with a liquid token—they also enjoy real event benefits.**

---

## ⚙️ Secondary Market Flow

### On Each Swap:

- **Buy $EVENT**: 3% LP fee
- **Sell $EVENT**: Higher, dynamic LP fee (10%) to discourage dumps

### Fee Distribution:

- **40%** → Permanent liquidity (locked depth)
- **60%** → Fanio (sustainability)

### Benefits:

- Organizer gets nothing from swaps (already collected full goal upfront)
- Fans benefit indirectly through more liquid and stable pool
- Pool strengthens with each trade
- Fans have liquidity, but selling is costlier → encourages holding

**Note**: This section describes the planned Uniswap v4 integration. Currently, the system focuses on the crowdfunding phase.

---

## 📊 Numerical Example

**Target**: $100k

### Initial Setup:

- Organizer receives: **100k USDC** net
- Total raised: **130k USDC** (100k target + 30k extra)
- Pool tokens: **25k tokens** (25% of 100k target)
- Protocol receives: **10k USDC** (10% of 100k target)
- Total supply: **155k $EVENT** (130k pre-funding + 25k pool)

### Fan Buys 100 USDC in Pool:

- 3% fee → **3 USDC**
- 1.2 USDC (40% of 3 USDC) → locked as permanent liquidity
- 1.8 USDC (60% of 3 USDC) → Fanio

### Fan Sells 100 USDC Worth of $EVENT:

- 10% fee → **10 USDC**
- 4 USDC (40% of 10 USDC) → permanent liquidity
- 6 USDC (60% of 10 USDC) → Fanio

**Note**: These examples show the planned Uniswap v4 integration. The current MVP focuses on crowdfunding and campaign management.

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
│   └── frontend/           # Next.js web application
│       ├── app/           # Next.js app router
│       ├── components/    # React components
│       ├── hooks/         # Custom React hooks
│       ├── lib/          # Utility functions
│       └── public/       # Static assets
```

---

## 🚀 Getting Started

### Prerequisites

- Node.js (v18 or later)
- pnpm package manager
- Git

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/your-username/fanio.git
   cd fanio
   ```

2. **Install dependencies**

   ```bash
   pnpm install
   ```

3. **Start the development server**

   ```bash
   cd packages/frontend
   pnpm dev
   ```

4. **Open your browser**
   Navigate to `http://localhost:3000`

---

## 🛠️ Tech Stack

### Frontend

- **Next.js 15** - React framework
- **TypeScript** - Type safety
- **Tailwind CSS** - Styling
- **Radix UI** - Component primitives
- **React Hook Form** - Form management
- **Zod** - Schema validation

### Blockchain (Coming Soon)

- **Uniswap v4** - DEX infrastructure
- **Custom Hooks** - Automated liquidity management
- **USDC** - Stable currency for funding

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

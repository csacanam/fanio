# Fanio Frontend

Next.js web application for the Fanio crowdfunding platform with real-time Uniswap V4 trading integration.

## Overview

The Fanio frontend provides a complete user interface for event crowdfunding campaigns, featuring real-time quotes, live trading through Uniswap V4, and seamless wallet integration.

## ✅ Implemented Features

### Core Functionality

- **Campaign Management** - View and interact with crowdfunding campaigns
- **Real-time Quotes** - Live pricing from Uniswap V4 Quoter
- **Live Trading** - Execute real swaps using Universal Router
- **Wallet Integration** - MetaMask connection with network detection
- **Token Balances** - Real-time USDC and EventToken balance updates
- **Transaction Results** - User-friendly transaction feedback with BaseScan links

### Trading Features

- **Uniswap V4 Integration** - Direct integration with Uniswap V4 pools
- **Permit2 Approvals** - Seamless ERC20 token approvals
- **Dynamic Fees** - 1% buy, 10% sell fee structure
- **Slippage Protection** - Built-in slippage control
- **Gas Optimization** - Efficient transaction execution

### UI/UX Features

- **Responsive Design** - Mobile-first responsive layout
- **Dark/Light Mode** - Theme switching support
- **Loading States** - Comprehensive loading indicators
- **Error Handling** - User-friendly error messages
- **Transaction Feedback** - Real-time transaction status updates

## Tech Stack

### Core Framework

- **Next.js 15** - React framework with App Router
- **React 19** - Latest React with concurrent features
- **TypeScript** - Full type safety
- **Tailwind CSS** - Utility-first CSS framework

### UI Components

- **Radix UI** - Accessible component primitives
- **Lucide React** - Icon library
- **React Hook Form** - Form management
- **Zod** - Schema validation

### Blockchain Integration

- **Ethers.js v6** - Ethereum interaction
- **Uniswap V4 SDK** - Custom adapted for ethers v6
- **Universal Router SDK** - Custom adapted for ethers v6
- **SDK Core** - Custom adapted for ethers v6

### Development Tools

- **ESLint** - Code linting
- **Prettier** - Code formatting
- **TypeScript** - Type checking
- **PostCSS** - CSS processing

## Project Structure

```
packages/frontend/
├── app/                          # Next.js App Router
│   ├── event/[slug]/            # Dynamic event pages
│   ├── globals.css              # Global styles
│   ├── layout.tsx               # Root layout
│   └── page.tsx                 # Home page
├── components/                   # React components
│   ├── ui/                      # Reusable UI components
│   │   ├── trading-modal.tsx    # Main trading interface
│   │   ├── transaction-result-modal.tsx # Transaction feedback
│   │   └── ...                  # Other UI components
│   └── theme-provider.tsx       # Theme management
├── config/                      # Configuration
│   └── contracts.ts             # Contract addresses
├── hooks/                       # Custom React hooks
│   ├── useCampaign.ts           # Campaign data management
│   ├── useQuoter.ts             # Uniswap V4 quotes
│   ├── useUniswapV4Swap.ts     # Swap execution
│   ├── useWallet.ts             # Wallet connection
│   ├── useTokenBalances.ts      # Token balance management
│   └── ...                      # Other hooks
├── lib/                         # Utility libraries
│   ├── sdk-core/                # Uniswap SDK Core (adapted)
│   ├── v4-sdk/                  # Uniswap V4 SDK (adapted)
│   ├── universal-router-sdk/    # Universal Router SDK (adapted)
│   └── utils.ts                 # Utility functions
├── public/                      # Static assets
├── styles/                      # Global styles
└── types/                       # TypeScript type definitions
```

## Getting Started

### Prerequisites

- Node.js 18+
- pnpm package manager
- Git

### Installation

1. **Install dependencies**

   ```bash
   cd packages/frontend
   pnpm install
   ```

2. **Set up environment variables**

   Create `.env.local`:

   ```bash
   NEXT_PUBLIC_RPC_URL=https://sepolia.base.org
   NEXT_PUBLIC_CHAIN_ID=84532
   NEXT_PUBLIC_FUNDING_MANAGER_ADDRESS=0x...
   NEXT_PUBLIC_EVENT_TOKEN_ADDRESS=0x...
   NEXT_PUBLIC_USDC_ADDRESS=0x...
   NEXT_PUBLIC_QUOTER_ADDRESS=0x...
   NEXT_PUBLIC_UNIVERSAL_ROUTER_ADDRESS=0x...
   NEXT_PUBLIC_PERMIT2_ADDRESS=0x...
   ```

3. **Start development server**

   ```bash
   pnpm dev
   ```

4. **Open your browser**

   Navigate to `http://localhost:3000`

## Configuration

### Contract Addresses

Contract addresses are managed in `config/contracts.ts`:

```typescript
export const contracts = {
  baseSepolia: {
    fundingManager: "0x...",
    eventToken: "0x...",
    usdc: "0x...",
    quoter: "0x...",
    universalRouter: "0x...",
    permit2: "0x...",
  },
};
```

### Environment Variables

Required environment variables:

- `NEXT_PUBLIC_RPC_URL` - Base Sepolia RPC URL
- `NEXT_PUBLIC_CHAIN_ID` - Chain ID (84532 for Base Sepolia)
- `NEXT_PUBLIC_FUNDING_MANAGER_ADDRESS` - FundingManager contract address
- `NEXT_PUBLIC_EVENT_TOKEN_ADDRESS` - EventToken contract address
- `NEXT_PUBLIC_USDC_ADDRESS` - USDC contract address
- `NEXT_PUBLIC_QUOTER_ADDRESS` - Uniswap V4 Quoter address
- `NEXT_PUBLIC_UNIVERSAL_ROUTER_ADDRESS` - Universal Router address
- `NEXT_PUBLIC_PERMIT2_ADDRESS` - Permit2 contract address

## Key Components

### Trading Modal (`components/ui/trading-modal.tsx`)

Main interface for executing swaps:

- Real-time quote display
- Amount input with validation
- Buy/Sell toggle
- Transaction execution
- Error handling

### Transaction Result Modal (`components/ui/transaction-result-modal.tsx`)

User feedback for completed transactions:

- Success/error status
- Transaction hash display
- BaseScan explorer link
- Copy to clipboard functionality

### Hooks

#### `useCampaign.ts`

- Fetches campaign data from contracts
- Handles pool information
- Manages loading states

#### `useQuoter.ts`

- Gets real-time quotes from Uniswap V4
- Handles quote errors
- Manages quote loading states

#### `useUniswapV4Swap.ts`

- Executes swaps using Universal Router
- Handles Permit2 approvals
- Manages transaction states

#### `useWallet.ts`

- Manages wallet connection
- Handles network switching
- Provides signer for transactions

#### `useTokenBalances.ts`

- Fetches USDC and EventToken balances
- Handles balance updates
- Manages loading states

## Uniswap V4 Integration

### Custom SDK Adaptation

The frontend uses custom-adapted Uniswap SDKs in `lib/`:

- **SDK Core** - Basic types and utilities
- **V4 SDK** - Uniswap V4 specific functionality
- **Universal Router SDK** - Universal Router integration

All SDKs have been adapted to work with ethers.js v6.

### Swap Flow

1. **Quote Request** - Get real-time price from Quoter
2. **Permit2 Approval** - Approve token spending
3. **Universal Router Execution** - Execute swap transaction
4. **Result Display** - Show transaction result

### Dynamic Fees

The system implements dynamic fees:

- **Buy $EVENT**: 1% fee (encourages participation)
- **Sell $EVENT**: 10% fee (discourages early dumps)

## Development

### Available Scripts

```bash
# Development
pnpm dev          # Start development server
pnpm build        # Build for production
pnpm start        # Start production server
pnpm lint         # Run ESLint

# Type checking
npx tsc --noEmit  # Check TypeScript types
```

### Code Structure

- **Components** - Reusable UI components
- **Hooks** - Custom React hooks for data management
- **Lib** - Utility functions and adapted SDKs
- **Types** - TypeScript type definitions
- **Config** - Configuration and constants

### Styling

- **Tailwind CSS** - Utility-first CSS framework
- **CSS Variables** - Theme management
- **Responsive Design** - Mobile-first approach
- **Dark Mode** - Theme switching support

## Deployment

### Build Process

```bash
# Build the application
pnpm build

# Start production server
pnpm start
```

### Environment Setup

Ensure all environment variables are set for the target network:

- Production: Base Mainnet (Chain ID: 8453)
- Staging: Base Sepolia (Chain ID: 84532)
- Development: Local/Anvil (Chain ID: 31337)

### Vercel Deployment

The application is configured for Vercel deployment:

1. Connect repository to Vercel
2. Set environment variables
3. Deploy automatically on push

## Troubleshooting

### Common Issues

#### Wallet Connection Issues

- Ensure MetaMask is installed
- Check network configuration
- Verify RPC URL is correct

#### Transaction Failures

- Check token approvals
- Verify sufficient balance
- Check gas limits

#### Quote Errors

- Verify Quoter contract address
- Check token addresses
- Ensure pool exists

### Debug Mode

Enable debug logging by setting:

```bash
NEXT_PUBLIC_DEBUG=true
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.

## Support

For questions and support:

- Create an issue on GitHub
- Contact the development team
- Check the documentation

---

_Built with ❤️ by the Fanio team_

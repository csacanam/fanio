# Fanio Smart Contracts

Decentralized crowdfunding system for live events with Uniswap V4 integration and dynamic fees.

## Overview

Fanio enables event organizers to create crowdfunding campaigns where contributors receive unique ERC20 tokens that can be traded on Uniswap V4 pools with dynamic fees (1% buy, 10% sell).

### Key Features

- ✅ **Decentralized crowdfunding** with unique event tokens
- ✅ **Uniswap V4 integration** for automatic liquidity
- ✅ **Dynamic fees** (1% buy, 10% sell) via custom hooks
- ✅ **Automatic refund system** for expired campaigns
- ✅ **20% excess funding** for pool liquidity
- ✅ **Organizer deposit** (10% of target) as guarantee

## Architecture

### Core Contracts

- **`FundingManager.sol`** - Main contract for campaign management
- **`EventToken.sol`** - ERC20Capped tokens for each event
- **`DynamicFeeHook.sol`** - Uniswap V4 hook for dynamic fees
- **`PoolLib.sol`** - Library for pool operations
- **`CampaignLib.sol`** - Library for campaign logic
- **`TokenLib.sol`** - Library for token operations

### Libraries

- **`PoolLib.sol`** - Uniswap V4 pool creation and management
- **`CampaignLib.sol`** - Campaign validation and logic
- **`TokenLib.sol`** - Token operations and decimal handling

## Quick Start

### Prerequisites

```bash
# Install dependencies
npm install

# Set environment variables
export PRIVATE_KEY="your_private_key"
export ETHERSCAN_API_KEY="your_api_key"  # For verification
```

### Development

```bash
# Compile contracts
forge build

# Run tests
forge test

# Run specific tests
forge test --match-contract FundingManagerTest
forge test --match-contract DynamicFeeHookTest
forge test --match-contract FundingManagerPoolIntegrationTest
```

## Deployment Flow

### Step 1: Manual Configuration (Before First Deployment)

**Edit these files manually before deploying:**

#### 1. Update `script/Config.s.sol`

**For Base Sepolia and other networks:**

```solidity
// Update both funding token and protocol wallet addresses
function getBaseSepoliaConfig() external pure returns (address fundingToken, address protocolWallet) {
    fundingToken = address(0x036CbD53842c5426634e7929541eC2318f3dCF7e); // USDC on Base Sepolia
    protocolWallet = address(0xYOUR_WALLET_ADDRESS); // ⚠️ EDIT THIS
}
```

**For Local/Anvil (funding token is deployed automatically):**

```solidity
// Only update protocol wallet address (funding token is deployed as MockUSDC)
function getLocalConfig() external pure returns (address fundingToken, address protocolWallet) {
    fundingToken = address(0); // Will be deployed as MockUSDC automatically
    protocolWallet = address(0xYOUR_WALLET_ADDRESS); // ⚠️ EDIT THIS
}
```

#### 2. Update `script/DeployFundingManager.s.sol` (only for new networks)

**Only if you're adding a new network that's not in `Config.s.sol`:**

```solidity
// Add new network configuration in DeployFundingManager.s.sol
else if (block.chainid == YOUR_NEW_NETWORK_ID) {
    fundingToken = address(0xYOUR_USDC_ADDRESS); // USDC on your new network
    protocolWallet = address(0xYOUR_WALLET_ADDRESS); // Your wallet
    // ... rest of deployment logic
}
```

### Step 2: Deploy Contracts

#### Base Sepolia (Testnet)

```bash
# Deploy contracts
forge script script/DeployFundingManager.s.sol:DeployFundingManager \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  --verify
```

#### Base Mainnet (Production)

```bash
# Deploy contracts
forge script script/DeployFundingManager.s.sol:DeployFundingManager \
  --rpc-url https://mainnet.base.org \
  --broadcast \
  --verify
```

#### Local Development (Anvil)

```bash
# Start local node
anvil

# Deploy (in another terminal)
forge script script/DeployFundingManager.s.sol:DeployFundingManager \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### Step 3: Automatic Configuration Update (After Deployment)

**These scripts update configuration automatically:**

```bash
# Update Config.s.sol with deployed addresses
node scripts/update-config.js 84532

# Update frontend configuration
node scripts/update-frontend-config.js 84532
```

### Step 4: Manual Verification (After Automatic Update)

**Verify these files were updated correctly:**

```bash
# Check Config.s.sol was updated
grep -A 5 "Base Sepolia" script/Config.s.sol

# Check frontend files were created
ls -la ../frontend/config/contracts.ts ../frontend/.env.local
```

## What Gets Updated Automatically vs Manually

### ✅ Automatic Updates (via scripts)

- **`script/Config.s.sol`** - FundingManager addresses after deployment
- **`../frontend/config/contracts.ts`** - Contract addresses for frontend
- **`../frontend/.env.local`** - Environment variables for frontend

### ⚠️ Manual Updates Required

- **`script/Config.s.sol`** - Protocol wallet addresses + USDC addresses (for existing networks)
- **`script/DeployFundingManager.s.sol`** - USDC addresses (only for new networks not in Config.s.sol)

### 📝 Configuration Strategy

**For existing networks (Base Sepolia, Base Mainnet, etc.):**

- ✅ Configure both `fundingToken` and `protocolWallet` in `Config.s.sol`
- ✅ `DeployFundingManager.s.sol` reads from `Config.s.sol`

**For new networks:**

- ✅ Add new network configuration in `DeployFundingManager.s.sol`
- ✅ Optionally add to `Config.s.sol` for consistency

**For Local/Anvil:**

- ✅ Only configure `protocolWallet` in `Config.s.sol`
- ✅ `fundingToken` is deployed automatically as `MockUSDC`

### 🔄 Update Flow Summary

1. **Before First Deployment**: Edit protocol wallet addresses manually
2. **Deploy**: Run forge script with --broadcast
3. **After Deployment**: Run automation scripts to update addresses
4. **Verify**: Check that files were updated correctly

## Visual Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT FLOW                             │
└─────────────────────────────────────────────────────────────────┘

1. MANUAL SETUP (Before First Deployment)
   ┌─────────────────────────────────────────────────────────────┐
   │ Edit script/Config.s.sol                                   │
   │ • Update protocol wallet addresses                         │
   │ • Update USDC addresses for new networks                   │
   └─────────────────────────────────────────────────────────────┘
                              │
                              ▼
2. DEPLOY CONTRACTS
   ┌─────────────────────────────────────────────────────────────┐
   │ forge script script/DeployFundingManager.s.sol            │
   │ --rpc-url [RPC_URL] --broadcast --verify                   │
   │                                                             │
   │ Generates: broadcast/DeployFundingManager.s.sol/[network]/ │
   └─────────────────────────────────────────────────────────────┘
                              │
                              ▼
3. AUTOMATIC CONFIGURATION UPDATE
   ┌─────────────────────────────────────────────────────────────┐
   │ node scripts/update-config.js [network]                   │
   │ • Updates script/Config.s.sol with deployed addresses      │
   │                                                             │
   │ node scripts/update-frontend-config.js [network]          │
   │ • Creates ../frontend/config/contracts.ts                  │
   │ • Creates ../frontend/.env.local                           │
   └─────────────────────────────────────────────────────────────┘
                              │
                              ▼
4. VERIFICATION
   ┌─────────────────────────────────────────────────────────────┐
   │ Check that files were updated correctly                    │
   │ • grep "Base Sepolia" script/Config.s.sol                  │
   │ • ls -la ../frontend/config/contracts.ts                   │
   └─────────────────────────────────────────────────────────────┘
```

## What Gets Updated When

| File                                | When              | How       | What                                                               |
| ----------------------------------- | ----------------- | --------- | ------------------------------------------------------------------ |
| `script/Config.s.sol`               | Before deployment | Manual    | Protocol wallet addresses + USDC addresses (for existing networks) |
| `script/Config.s.sol`               | After deployment  | Automatic | FundingManager addresses                                           |
| `script/DeployFundingManager.s.sol` | Before deployment | Manual    | USDC addresses (only for new networks not in Config.s.sol)         |
| `../frontend/config/contracts.ts`   | After deployment  | Automatic | Contract addresses                                                 |
| `../frontend/.env.local`            | After deployment  | Automatic | Environment variables                                              |

## Contract Interaction

### Create Campaign

```bash
forge script script/CreateCampaign.s.sol:CreateCampaign \
  --rpc-url [RPC_URL] \
  --broadcast
```

### Contribute to Campaign

```bash
forge script script/ContributeToCampaign.s.sol:ContributeToCampaign \
  --rpc-url [RPC_URL] \
  --broadcast
```

### View Campaign Status

```bash
# View campaign details
forge script script/ViewCampaign.s.sol:ViewCampaign \
  --rpc-url [RPC_URL]

# View EventToken details
forge script script/ViewEventToken.s.sol:ViewEventToken \
  --rpc-url [RPC_URL]
```

### Close Expired Campaign

```bash
forge script script/CloseExpiredCampaign.s.sol:CloseExpiredCampaign \
  --rpc-url [RPC_URL] \
  --broadcast
```

## Project Structure

```
packages/contracts/
├── src/                          # Core contracts
│   ├── FundingManager.sol        # Main contract
│   ├── EventToken.sol           # Event tokens
│   ├── DynamicFeeHook.sol       # Fee hook
│   ├── mocks/
│   │   └── MockUSDC.sol         # Mock USDC for testing
│   └── libraries/               # Libraries
│       ├── PoolLib.sol          # Pool operations
│       ├── CampaignLib.sol      # Campaign logic
│       └── TokenLib.sol         # Token operations
├── script/                      # Deployment scripts
│   ├── DeployFundingManager.s.sol
│   ├── CreateCampaign.s.sol
│   ├── ContributeToCampaign.s.sol
│   ├── ViewCampaign.s.sol
│   ├── ViewEventToken.s.sol
│   ├── CloseExpiredCampaign.s.sol
│   ├── Config.s.sol
│   └── README.md
├── scripts/                     # Automation scripts
│   ├── update-config.js         # Updates Config.s.sol
│   ├── update-frontend-config.js # Updates frontend
│   └── README.md
├── test/                        # Test suite
│   ├── FundingManager.t.sol
│   ├── EventToken.t.sol
│   ├── DynamicFeeHook.t.sol
│   ├── FundingManagerPoolIntegration.t.sol
│   └── utils/
│       └── Deployers.sol
├── lib/                         # Dependencies
│   ├── v4-core/                 # Uniswap V4 Core
│   ├── v4-periphery/            # Uniswap V4 Periphery
│   └── hookmate/                # Hookmate utilities
└── broadcast/                   # Deployment files
    └── DeployFundingManager.s.sol/
        ├── 84532/              # Base Sepolia
        ├── 8453/               # Base Mainnet
        └── 31337/              # Local/Anvil
```

## Configuration

### Environment Variables

```bash
# Required for deployment
export PRIVATE_KEY="your_private_key"
export ETHERSCAN_API_KEY="your_api_key"

# Optional
export RPC_URL="https://sepolia.base.org"
export EXPLORER_URL="https://sepolia.basescan.org"
```

### Supported Networks

| Network          | Chain ID | RPC URL                      | Explorer                     |
| ---------------- | -------- | ---------------------------- | ---------------------------- |
| Local/Anvil      | 31337    | http://localhost:8545        | http://localhost:8545        |
| Base Sepolia     | 84532    | https://sepolia.base.org     | https://sepolia.basescan.org |
| Base Mainnet     | 8453     | https://mainnet.base.org     | https://basescan.org         |
| Ethereum Mainnet | 1        | https://eth.llamarpc.com     | https://etherscan.io         |
| Sepolia          | 11155111 | https://sepolia.llamarpc.com | https://sepolia.etherscan.io |

## Testing

### Run All Tests

```bash
forge test
```

### Specific Tests

```bash
# FundingManager tests
forge test --match-contract FundingManagerTest

# EventToken tests
forge test --match-contract EventTokenTest

# DynamicFeeHook tests
forge test --match-contract DynamicFeeHookTest

# Pool integration tests
forge test --match-contract FundingManagerPoolIntegrationTest
```

### Gas Reports

```bash
forge test --gas-report
```

### Coverage

```bash
forge coverage
```

## Monitoring & Verification

### Verify Contracts

```bash
# Base Sepolia
forge verify-contract <CONTRACT_ADDRESS> \
  --chain-id 84532 \
  --etherscan-api-key $ETHERSCAN_API_KEY

# Base Mainnet
forge verify-contract <CONTRACT_ADDRESS> \
  --chain-id 8453 \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Monitor Transactions

```bash
# View deployment transaction
cast tx <TX_HASH> --rpc-url <RPC_URL>

# View event logs
cast logs --from-block <BLOCK_NUMBER> --address <CONTRACT_ADDRESS> --rpc-url <RPC_URL>
```

## Automation

### Update Scripts

The scripts in `scripts/` automate configuration updates:

```bash
# Update Config.s.sol
node scripts/update-config.js [network] [deployScript]

# Update frontend configuration
node scripts/update-frontend-config.js [network] [deployScript]
```

### Examples

```bash
# Base Sepolia
node scripts/update-config.js 84532
node scripts/update-frontend-config.js 84532

# Base Mainnet
node scripts/update-config.js 8453
node scripts/update-frontend-config.js 8453

# Local development
node scripts/update-config.js 31337
node scripts/update-frontend-config.js 31337
```

## Troubleshooting

### Common Errors

#### "Insufficient funds"

```bash
# Check balance
cast balance <ADDRESS> --rpc-url <RPC_URL>

# Get ETH from faucet (testnet)
cast faucet <ADDRESS> --rpc-url <RPC_URL>
```

#### "Contract verification failed"

```bash
# Verify manually
forge verify-contract <CONTRACT_ADDRESS> <CONTRACT_NAME> \
  --chain-id <CHAIN_ID> \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

#### "Script execution failed"

```bash
# Check detailed logs
forge script script/DeployFundingManager.s.sol:DeployFundingManager \
  --rpc-url <RPC_URL> \
  --broadcast \
  --debug
```

### Debugging

```bash
# Compile with debug info
forge build --debug

# Run tests with logs
forge test -vvv

# Check configuration
forge config
```

## Documentation

- [Deployment Scripts](script/README.md)
- [Automation Scripts](scripts/README.md)
- [Foundry Documentation](https://book.getfoundry.sh/)
- [Uniswap V4 Documentation](https://docs.uniswap.org/sdk/v4/overview)

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

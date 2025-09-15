# Fanio Deployment Scripts

Scripts to deploy and configure the FundingManager contract for Fanio.

## 📋 Prerequisites

1. **Environment variables:**

   ```bash
   export PRIVATE_KEY="your_private_key_here"
   export ETHERSCAN_API_KEY="your_api_key"  # For contract verification
   ```

2. **Manual configuration required:**

   **Before first deployment, edit these files:**

   ```bash
   # Edit protocol wallet addresses
   vim script/Config.s.sol

   # Edit USDC addresses for your network (if needed)
   vim script/DeployFundingManager.s.sol
   ```

3. **Available networks:**
   - Base Sepolia
   - Base Mainnet
   - Local/Anvil

## ⚠️ Manual Configuration Required

### Before First Deployment

**You must edit these files manually before deploying:**

#### 1. Update `script/Config.s.sol`

**For Base Sepolia and other existing networks:**

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

### After Deployment

**These files are updated automatically by scripts:**

- ✅ `script/Config.s.sol` - FundingManager addresses (via `update-config.js`)
- ✅ `../frontend/config/contracts.ts` - Frontend contract addresses (via `update-frontend-config.js`)
- ✅ `../frontend/.env.local` - Frontend environment variables (via `update-frontend-config.js`)

## 🚀 Available Scripts

### 1. DeployFundingManager.s.sol

Main script to deploy the FundingManager contract with DynamicFeeHook integration.

**Usage:**

```bash
# Deploy on Base Sepolia
forge script script/DeployFundingManager.s.sol:DeployFundingManager --rpc-url https://sepolia.base.org --broadcast --verify

# Deploy locally
forge script script/DeployFundingManager.s.sol:DeployFundingManager --rpc-url http://localhost:8545 --broadcast
```

**Configuration:**

- **Automatic:** The script automatically detects the network and uses the appropriate configuration
- **Base Sepolia:** Uses USDC address `0x036CBD53842c5426634e7929541ec2318F3DCF7C`
- **Local/Anvil:** Uses MockERC20 for testing
- **Addresses:** Uses AddressConstants for PoolManager and PositionManager addresses
- **Protocol Wallet:** Update the wallet address in `Config.s.sol` before deployment

### 2. CreateCampaign.s.sol

Script to create campaigns using the deployed FundingManager with 20% excess funding.

**Usage:**

```bash
# Create campaign on specific network
forge script script/CreateCampaign.s.sol:CreateCampaign --rpc-url [RPC_URL] --broadcast
```

**Configuration:**

- Creates campaigns with 100k USDC target (120k total goal with 20% excess)
- Requires 10k USDC organizer deposit (10% of target)
- Automatically handles USDC approval

### 3. ContributeToCampaign.s.sol

Script to contribute to existing campaigns.

**Usage:**

```bash
# Contribute to campaign
forge script script/ContributeToCampaign.s.sol:ContributeToCampaign --rpc-url [RPC_URL] --broadcast
```

**Configuration:**

- Default contribution: 10k USDC
- Automatically handles USDC approval
- Shows campaign progress after contribution

### 4. ViewCampaign.s.sol

Script to view campaign details and status.

**Usage:**

```bash
# View campaign status
forge script script/ViewCampaign.s.sol:ViewCampaign --rpc-url [RPC_URL]
```

**Features:**

- Shows campaign progress vs target and total goal
- Displays time remaining in human-readable format
- Shows organizer deposit and unique backers

### 5. ViewEventToken.s.sol

Script to view EventToken details for a campaign.

**Usage:**

```bash
# View EventToken details
forge script script/ViewEventToken.s.sol:ViewEventToken --rpc-url [RPC_URL]
```

**Features:**

- Automatically gets EventToken address from campaign
- Shows token name, symbol, decimals, total supply, and cap
- Handles cases where EventToken hasn't been created yet

### 6. CloseExpiredCampaign.s.sol

Script to close expired campaigns and trigger automatic refunds.

**Usage:**

```bash
# Close expired campaign
forge script script/CloseExpiredCampaign.s.sol:CloseExpiredCampaign --rpc-url [RPC_URL] --broadcast
```

**Features:**

- Automatically refunds organizer deposit and all contributor funds
- Shows campaign status before and after closing
- Validates campaign is expired and not funded

### 7. Config.s.sol

Configuration script with predefined addresses for different networks.

**Features:**

- Network-specific configurations
- Integration with AddressConstants for V4 addresses
- Helper functions for PoolManager and PositionManager addresses

## 🔧 Network Configuration

### Base Sepolia

- **USDC:** 0x036CBD53842c5426634e7929541ec2318F3DCF7C
- **RPC:** https://sepolia.base.org

### Local/Anvil

- **USDC:** Mock token for local testing
- **RPC:** http://localhost:8545

## 📝 Deployment Steps

1. **Update protocol wallet in Config.s.sol:**

   ```bash
   # Edit packages/contracts/script/Config.s.sol
   # Update protocolWallet address in getBaseSepoliaConfig() and getLocalConfig()
   ```

2. **Set environment variables:**

   ```bash
   export PRIVATE_KEY="your_private_key"
   ```

3. **Deploy FundingManager:**

   ```bash
   forge script script/DeployFundingManager.s.sol:DeployFundingManager --rpc-url [RPC_URL] --broadcast
   ```

4. **Save the deployed contract address**

5. **Create campaign:**
   ```bash
   # Update CreateCampaign.s.sol with the contract address
   forge script script/CreateCampaign.s.sol:CreateCampaign --rpc-url [RPC_URL] --broadcast
   ```

## ⚠️ Important Notes

- **Never share your private key**
- **Verify USDC addresses** for each network
- **Use testnets** for testing before mainnet
- **Save the addresses** of deployed contracts

## 🆘 Troubleshooting

- **Gas error:** Increase gas limit
- **Nonce error:** Use `--legacy` or update nonce
- **Verification error:** Make sure you have the correct API key

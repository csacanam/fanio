# Fanio Deployment Scripts

Scripts to deploy and configure the FundingManager contract for Fanio.

## 📋 Prerequisites

1. **Environment variables:**

   ```bash
   export PRIVATE_KEY="your_private_key_here"
   ```

2. **Available networks:**
   - Base Sepolia
   - Local/Anvil

## 🚀 Available Scripts

### 1. DeployFundingManager.s.sol

Main script to deploy the FundingManager contract.

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
- **Local/Anvil:** Uses mock token for testing
- **Protocol Wallet:** Update the wallet address in `Config.s.sol` before deployment

### 2. CreateCampaign.s.sol

Script to create campaigns using the deployed FundingManager.

**Usage:**

```bash
# Create campaign on specific network
forge script script/CreateCampaign.s.sol:CreateCampaign --rpc-url [RPC_URL] --broadcast
```

**Configuration:**

- Update `fundingManagerAddress` with the deployed contract address
- Customize `eventName`, `tokenSymbol`, `targetAmount`, etc.

### 3. Config.s.sol

Configuration script with predefined addresses for different networks.

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

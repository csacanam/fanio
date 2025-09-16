#!/usr/bin/env node

/**
 * Script to update frontend configuration with deployed contract addresses
 * This script reads the latest broadcast file and updates the frontend config
 *
 * Usage: node update-frontend-config.js [network] [deployScript]
 * Examples:
 *   node update-frontend-config.js 84532 DeployFundingManager.s.sol
 *   node update-frontend-config.js 31337 DeployFundingManager.s.sol
 */

const fs = require("fs");
const path = require("path");

// Colors for console output
const colors = {
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  blue: "\x1b[34m",
  reset: "\x1b[0m",
};

function log(message, color = "reset") {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

// Network configurations
const NETWORKS = {
  31337: {
    name: "Local/Anvil",
    explorer: "http://localhost:8545",
    rpcUrl: "http://localhost:8545",
  },
  84532: {
    name: "Base Sepolia",
    explorer: "https://sepolia.basescan.org",
    rpcUrl: "https://sepolia.base.org",
  },
  8453: {
    name: "Base Mainnet",
    explorer: "https://basescan.org",
    rpcUrl: "https://mainnet.base.org",
  },
  1: {
    name: "Ethereum Mainnet",
    explorer: "https://etherscan.io",
    rpcUrl: "https://eth.llamarpc.com",
  },
  11155111: {
    name: "Sepolia",
    explorer: "https://sepolia.etherscan.io",
    rpcUrl: "https://sepolia.llamarpc.com",
  },
};

function updateFrontendConfig() {
  try {
    // Parse command line arguments
    const network = process.argv[2] || "84532";
    const deployScript = process.argv[3] || "DeployFundingManager.s.sol";

    const networkInfo = NETWORKS[network];
    if (!networkInfo) {
      log(`❌ Unsupported network: ${network}`, "red");
      log(
        `   Supported networks: ${Object.keys(NETWORKS).join(", ")}`,
        "yellow"
      );
      process.exit(1);
    }

    log(
      `🔄 Updating frontend configuration for ${networkInfo.name} (${network})...`,
      "yellow"
    );
    log(`   Deploy script: ${deployScript}`, "blue");

    // Get the latest broadcast file for the specified network
    const broadcastDir = path.join(
      __dirname,
      "..",
      "broadcast",
      deployScript,
      network
    );
    const latestFile = path.join(broadcastDir, "run-latest.json");

    if (!fs.existsSync(latestFile)) {
      log(`❌ No broadcast file found at: ${latestFile}`, "red");
      log(
        `   Run the deploy script first: forge script script/${deployScript} --rpc-url [RPC_URL] --broadcast`,
        "yellow"
      );
      process.exit(1);
    }

    // Read and parse the broadcast file
    const broadcastData = JSON.parse(fs.readFileSync(latestFile, "utf8"));

    // Extract contract addresses
    const transactions = broadcastData.transactions || [];
    if (transactions.length === 0) {
      log("❌ No transactions found in broadcast file", "red");
      process.exit(1);
    }

    // Find FundingManager deployment
    const fundingManagerTx = transactions.find(
      (tx) => tx.contractName === "FundingManager"
    );

    if (!fundingManagerTx) {
      log(
        "❌ Could not find FundingManager transaction in broadcast file",
        "red"
      );
      log("   Available transactions:", "yellow");
      transactions.forEach((tx, index) => {
        log(
          `   ${index}: ${tx.contractName || "Unknown"} - ${
            tx.contractAddress
          }`,
          "yellow"
        );
      });
      process.exit(1);
    }

    const fundingManager = fundingManagerTx.contractAddress;
    const usdcAddress = fundingManagerTx.arguments?.[0];

    if (!fundingManager) {
      log("❌ Could not find FundingManager contract address", "red");
      process.exit(1);
    }

    // Get StateView address from Config contract
    let stateViewAddress = "0x0000000000000000000000000000000000000000";
    try {
      // We need to call the Config contract to get the StateView address
      // For now, we'll use the known address for Base Sepolia
      if (network === "84532") {
        stateViewAddress = "0x571291b572ed32ce6751a2cb2486ebee8defb9b4";
      }
    } catch (err) {
      log(`⚠️  Could not get StateView address: ${err.message}`, "yellow");
    }

    log("✅ Extracted addresses:", "green");
    log(`   FundingManager: ${fundingManager}`, "green");
    if (usdcAddress) {
      log(`   USDC: ${usdcAddress}`, "green");
    } else {
      log(`   USDC: Not found in broadcast file`, "yellow");
    }
    log(`   StateView: ${stateViewAddress}`, "green");

    // Create frontend config file
    const frontendConfigPath = path.join(
      __dirname,
      "..",
      "..",
      "frontend",
      "config",
      "contracts.ts"
    );

    // Ensure frontend config directory exists
    const configDir = path.dirname(frontendConfigPath);
    if (!fs.existsSync(configDir)) {
      fs.mkdirSync(configDir, { recursive: true });
    }

    // Generate the config file content
    const networkKey =
      network === "31337"
        ? "local"
        : network === "84532"
        ? "baseSepolia"
        : network === "8453"
        ? "baseMainnet"
        : network === "1"
        ? "ethereumMainnet"
        : network === "11155111"
        ? "sepolia"
        : `network${network}`;

    const configContent = `// Auto-generated contract configuration
// Updated on: ${new Date().toISOString()}
// Network: ${networkInfo.name} (${network})

export const CONTRACTS = {
  local: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder for local
    usdc: "0x0000000000000000000000000000000000000000", // Placeholder for local
    stateView: "0x0000000000000000000000000000000000000000" // Placeholder for local
  },
  baseSepolia: {
    fundingManager: "${
      network === "84532"
        ? fundingManager
        : "0x0000000000000000000000000000000000000000"
    }",
    usdc: "${
      network === "84532"
        ? usdcAddress || "0x0000000000000000000000000000000000000000"
        : "0x0000000000000000000000000000000000000000"
    }",
    stateView: "${
      network === "84532"
        ? stateViewAddress
        : "0x0000000000000000000000000000000000000000"
    }"
  },
  baseMainnet: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder
    usdc: "0x0000000000000000000000000000000000000000", // Placeholder
    stateView: "0x0000000000000000000000000000000000000000" // Placeholder
  },
  ethereumMainnet: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder
    usdc: "0x0000000000000000000000000000000000000000", // Placeholder
    stateView: "0x0000000000000000000000000000000000000000" // Placeholder
  },
  sepolia: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder
    usdc: "0x0000000000000000000000000000000000000000", // Placeholder
    stateView: "0x0000000000000000000000000000000000000000" // Placeholder
  }
} as const;

export type Network = keyof typeof CONTRACTS;
export type ContractAddresses = typeof CONTRACTS[Network];

// Helper function to get current network addresses
export const getContractAddresses = (network: Network): ContractAddresses => {
  return CONTRACTS[network];
};

// Default to the deployed network
export const DEFAULT_NETWORK: Network = "${networkKey}";

export const EXPLORERS = {
  local: "http://localhost:8545",
  baseSepolia: "https://sepolia.basescan.org",
  baseMainnet: "https://basescan.org",
  ethereumMainnet: "https://etherscan.io",
  sepolia: "https://sepolia.etherscan.io"
} as const;

export const RPC_URLS = {
  local: "http://localhost:8545",
  baseSepolia: "https://sepolia.base.org",
  baseMainnet: "https://mainnet.base.org",
  ethereumMainnet: "https://eth.llamarpc.com",
  sepolia: "https://sepolia.llamarpc.com"
} as const;

export const getExplorerUrl = (network: Network): string => {
  return EXPLORERS[network];
};

export const getRpcUrl = (network: Network): string => {
  return RPC_URLS[network];
};
`;

    // Write the config file
    fs.writeFileSync(frontendConfigPath, configContent);
    log(`✅ Frontend configuration updated at: ${frontendConfigPath}`, "green");

    // Also create a .env.local file for the frontend
    const frontendEnvPath = path.join(
      __dirname,
      "..",
      "..",
      "frontend",
      ".env.local"
    );

    const envContent = `# Auto-generated environment variables
# Updated on: ${new Date().toISOString()}
# Network: ${networkInfo.name} (${network})

NEXT_PUBLIC_NETWORK=${networkKey}
NEXT_PUBLIC_CHAIN_ID=${network}
NEXT_PUBLIC_RPC_URL=${networkInfo.rpcUrl}
NEXT_PUBLIC_EXPLORER_URL=${networkInfo.explorer}
NEXT_PUBLIC_FUNDING_MANAGER=${fundingManager}
NEXT_PUBLIC_USDC_ADDRESS=${
      usdcAddress || "0x0000000000000000000000000000000000000000"
    }
NEXT_PUBLIC_STATE_VIEW=${stateViewAddress}
`;

    fs.writeFileSync(frontendEnvPath, envContent);
    log(`✅ Frontend .env.local updated at: ${frontendEnvPath}`, "green");

    log("🎉 Frontend configuration update complete!", "green");
    log(
      `💡 You can now use these addresses in your frontend code for ${networkInfo.name}`,
      "yellow"
    );
    log(`   Explorer: ${networkInfo.explorer}`, "blue");
    log(`   RPC: ${networkInfo.rpcUrl}`, "blue");

    if (fundingManager) {
      log(
        `   FundingManager: ${networkInfo.explorer}/address/${fundingManager}`,
        "blue"
      );
    }
  } catch (error) {
    log(`❌ Error updating frontend config: ${error.message}`, "red");
    process.exit(1);
  }
}

// Run the script
updateFrontendConfig();

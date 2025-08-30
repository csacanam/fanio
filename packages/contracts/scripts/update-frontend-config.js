#!/usr/bin/env node

/**
 * Script to update frontend configuration with deployed contract addresses
 * This script reads the latest broadcast file and updates the frontend config
 */

const fs = require("fs");
const path = require("path");

// Colors for console output
const colors = {
  red: "\x1b[31m",
  green: "\x1b[32m",
  yellow: "\x1b[33m",
  reset: "\x1b[0m",
};

function log(message, color = "reset") {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function updateFrontendConfig() {
  try {
    log("🔄 Updating frontend configuration...", "yellow");

    // Get the latest broadcast file for Base Sepolia
    const broadcastDir = path.join(
      __dirname,
      "..",
      "broadcast",
      "DeployFundingManager.s.sol",
      "84532"
    );
    const latestFile = path.join(broadcastDir, "run-latest.json");

    if (!fs.existsSync(latestFile)) {
      log("❌ No broadcast file found. Run the deploy script first.", "red");
      process.exit(1);
    }

    // Read and parse the broadcast file
    const broadcastData = JSON.parse(fs.readFileSync(latestFile, "utf8"));

    // Extract contract addresses
    const fundingManager = broadcastData.transactions[0].contractAddress;
    const usdcAddress = broadcastData.transactions[0].arguments[0]; // USDC address is first constructor argument

    if (!fundingManager || !usdcAddress) {
      log("❌ Could not extract contract addresses from broadcast file", "red");
      log(`   FundingManager: ${fundingManager}`, "red");
      log(`   USDC: ${usdcAddress}`, "red");
      process.exit(1);
    }

    log("✅ Extracted addresses:", "green");
    log(`   FundingManager: ${fundingManager}`, "green");
    log(`   USDC: ${usdcAddress}`, "green");

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
    const configContent = `// Auto-generated contract configuration
// Updated on: ${new Date().toISOString()}
// Network: Base Sepolia

export const CONTRACTS = {
  local: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder for local
    usdc: "0x0000000000000000000000000000000000000000" // Placeholder for local
  },
  baseSepolia: {
    fundingManager: "${fundingManager}",
    usdc: "${usdcAddress}"
  }
} as const;

export type Network = keyof typeof CONTRACTS;
export type ContractAddresses = typeof CONTRACTS[Network];

// Helper function to get current network addresses
export const getContractAddresses = (network: Network): ContractAddresses => {
  return CONTRACTS[network];
};

// Default to Base Sepolia for now
export const DEFAULT_NETWORK: Network = "baseSepolia";
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

NEXT_PUBLIC_NETWORK=baseSepolia
NEXT_PUBLIC_FUNDING_MANAGER=${fundingManager}
NEXT_PUBLIC_USDC_ADDRESS=${usdcAddress}
`;

    fs.writeFileSync(frontendEnvPath, envContent);
    log(`✅ Frontend .env.local updated at: ${frontendEnvPath}`, "green");

    log("🎉 Frontend configuration update complete!", "green");
    log("💡 You can now use these addresses in your frontend code", "yellow");
  } catch (error) {
    log(`❌ Error updating frontend config: ${error.message}`, "red");
    process.exit(1);
  }
}

// Run the script
updateFrontendConfig();

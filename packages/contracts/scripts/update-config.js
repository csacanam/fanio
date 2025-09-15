#!/usr/bin/env node

/**
 * Script to automatically update Config.s.sol with latest deployed addresses
 * This script reads broadcast files and updates the Config contract
 *
 * Usage: node update-config.js [network] [deployScript]
 * Examples:
 *   node update-config.js 84532 DeployFundingManager.s.sol
 *   node update-config.js 31337 DeployFundingManager.s.sol
 */

const fs = require("fs");
const path = require("path");

// Add ethers for proper address checksumming
const { ethers } = require("ethers");

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
  31337: { name: "Local/Anvil", explorer: "http://localhost:8545" },
  84532: { name: "Base Sepolia", explorer: "https://sepolia.basescan.org" },
  8453: { name: "Base Mainnet", explorer: "https://basescan.org" },
  1: { name: "Ethereum Mainnet", explorer: "https://etherscan.io" },
  11155111: { name: "Sepolia", explorer: "https://sepolia.etherscan.io" },
};

function updateConfig() {
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
      `🔄 Updating Config.s.sol for ${networkInfo.name} (${network})...`,
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

    // Extract contract addresses and checksum them properly
    const transactions = broadcastData.transactions || [];
    if (transactions.length === 0) {
      log("❌ No transactions found in broadcast file", "red");
      process.exit(1);
    }

    // Find FundingManager deployment (usually the first contract)
    const fundingManagerTx =
      transactions.find(
        (tx) => tx.contractName === "FundingManager" || tx.contractAddress
      ) || transactions[0];

    const fundingManagerRaw = fundingManagerTx.contractAddress;
    const usdcAddressRaw = fundingManagerTx.arguments?.[0];

    if (!fundingManagerRaw) {
      log("❌ Could not find FundingManager contract address", "red");
      process.exit(1);
    }

    // Convert to proper checksummed addresses
    const fundingManager = ethers.getAddress(fundingManagerRaw);
    const usdcAddress = usdcAddressRaw
      ? ethers.getAddress(usdcAddressRaw)
      : null;

    log("✅ Extracted addresses:", "green");
    log(`   FundingManager: ${fundingManager} (checksummed)`, "green");
    if (usdcAddress) {
      log(`   USDC: ${usdcAddress} (checksummed)`, "green");
    } else {
      log(`   USDC: Not found in broadcast file`, "yellow");
    }

    // Read current Config.s.sol
    const configPath = path.join(__dirname, "..", "script", "Config.s.sol");
    let configContent = fs.readFileSync(configPath, "utf8");

    // Update USDC address if found
    if (usdcAddress) {
      const usdcRegex = new RegExp(
        `fundingToken = address\\(0x[a-fA-F0-9]{40}\\); // USDC on ${networkInfo.name}`,
        "g"
      );
      if (usdcRegex.test(configContent)) {
        configContent = configContent.replace(
          usdcRegex,
          `fundingToken = address(${usdcAddress}); // USDC on ${networkInfo.name}`
        );
        log(`✅ Updated USDC address for ${networkInfo.name}`, "green");
      } else {
        log(
          `⚠️  Could not find USDC address pattern for ${networkInfo.name}`,
          "yellow"
        );
      }
    }

    // Update FundingManager address for the specific network
    try {
      const fundingManagerRegex = new RegExp(
        `} else if \\(block\\.chainid == ${network}\\) \\{[\\s\\S]*?return address\\(0x[a-fA-F0-9]{40}\\)`,
        "g"
      );

      if (fundingManagerRegex.test(configContent)) {
        configContent = configContent.replace(fundingManagerRegex, (match) => {
          return match.replace(
            /return address\(0x[a-fA-F0-9]{40}\)/,
            `return address(${fundingManager})`
          );
        });
        log(
          `✅ Updated FundingManager address for ${networkInfo.name}`,
          "green"
        );
      } else {
        log(
          `⚠️  Could not find FundingManager address pattern for ${networkInfo.name}`,
          "yellow"
        );
        log(
          `   Make sure the network ${network} is configured in Config.s.sol`,
          "yellow"
        );
      }
    } catch (error) {
      log("⚠️  Could not update FundingManager address", "yellow");
      log(`   Error: ${error.message}`, "yellow");
    }

    // Write updated Config.s.sol
    fs.writeFileSync(configPath, configContent);
    log(`✅ Config.s.sol updated automatically at: ${configPath}`, "green");

    log("🎉 Config update complete!", "green");
    log(
      `💡 Config.s.sol now uses the latest deployed addresses for ${networkInfo.name}`,
      "yellow"
    );
    log(`   Explorer: ${networkInfo.explorer}`, "blue");

    if (fundingManager) {
      log(
        `   FundingManager: ${networkInfo.explorer}/address/${fundingManager}`,
        "blue"
      );
    }
  } catch (error) {
    log(`❌ Error updating config: ${error.message}`, "red");
    process.exit(1);
  }
}

// Run the script
updateConfig();

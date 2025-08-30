#!/usr/bin/env node

/**
 * Script to automatically update Config.s.sol with latest deployed addresses
 * This script reads broadcast files and updates the Config contract
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
  reset: "\x1b[0m",
};

function log(message, color = "reset") {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function updateConfig() {
  try {
    log("🔄 Updating Config.s.sol automatically...", "yellow");

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

    // Extract contract addresses and checksum them properly
    const fundingManagerRaw = broadcastData.transactions[0].contractAddress;
    const usdcAddressRaw = broadcastData.transactions[0].arguments[0];

    // Convert to proper checksummed addresses
    const fundingManager = ethers.getAddress(fundingManagerRaw);
    const usdcAddress = ethers.getAddress(usdcAddressRaw);

    if (!fundingManager || !usdcAddress) {
      log("❌ Could not extract contract addresses from broadcast file", "red");
      process.exit(1);
    }

    log("✅ Extracted addresses:", "green");
    log(`   FundingManager: ${fundingManager} (checksummed)`, "green");
    log(`   USDC: ${usdcAddress} (checksummed)`, "green");

    // Read current Config.s.sol
    const configPath = path.join(__dirname, "..", "script", "Config.s.sol");
    let configContent = fs.readFileSync(configPath, "utf8");

    // Update Base Sepolia USDC address - only in getBaseSepoliaConfig function
    const usdcRegex =
      /fundingToken = address\(0x[a-fA-F0-9]{40}\); \/\/ USDC on Base Sepolia/;
    if (usdcRegex.test(configContent)) {
      configContent = configContent.replace(
        usdcRegex,
        `fundingToken = address(${usdcAddress}); // USDC on Base Sepolia`
      );
      log("✅ Updated USDC address in getBaseSepoliaConfig", "green");
    }

    // Update FundingManager address - use direct string replacement
    try {
      // Find and replace ANY FundingManager address in getFundingManagerAddress function
      // Look for any address in the Base Sepolia section
      const fundingManagerRegex =
        /} else if \(block\.chainid == 84532\) \{[\s\S]*?return address\(0x[a-fA-F0-9]{40}\)/;
      if (fundingManagerRegex.test(configContent)) {
        configContent = configContent.replace(fundingManagerRegex, (match) => {
          // Replace only the address part, keeping the rest of the structure
          return match.replace(
            /return address\(0x[a-fA-F0-9]{40}\)/,
            `return address(${fundingManager})`
          );
        });
        log(
          "✅ Updated FundingManager address using regex replacement",
          "green"
        );
      } else {
        log(
          "⚠️  Could not find FundingManager address pattern to replace",
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
      "💡 Config.s.sol now automatically uses the latest deployed addresses with proper checksum",
      "yellow"
    );
  } catch (error) {
    log(`❌ Error updating config: ${error.message}`, "red");
    process.exit(1);
  }
}

// Run the script
updateConfig();

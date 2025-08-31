// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {EventToken} from "../src/EventToken.sol";
import {Config} from "./Config.s.sol";
import {console} from "forge-std/console.sol";

contract CheckTokenDecimals is Script {
    function run() external {
        // Get campaign ID 0
        uint256 campaignId = 0;

        // Get configuration based on network
        Config config = new Config();
        address fundingManagerAddress = config.getFundingManagerAddress();

        console.log("=== Checking Token Decimals and Balances ===");
        console.log("Campaign ID:", campaignId);
        console.log("FundingManager Address:", fundingManagerAddress);

        // Get campaign details
        FundingManager fundingManager = FundingManager(fundingManagerAddress);

        try fundingManager.getCampaignEventToken(campaignId) returns (
            address eventTokenAddress
        ) {
            console.log("Event Token Address:", eventTokenAddress);

            if (eventTokenAddress != address(0)) {
                EventToken eventToken = EventToken(eventTokenAddress);

                // Check token details
                console.log("=== EventToken Details ===");
                console.log("Token Name:", eventToken.name());
                console.log("Token Symbol:", eventToken.symbol());
                console.log("Token Decimals:", eventToken.decimals());
                console.log("Total Supply:", eventToken.totalSupply());
                console.log("Cap:", eventToken.cap());

                // Check campaign status
                try fundingManager.getCampaignStatus(campaignId) returns (
                    bool isActive,
                    bool isExpired,
                    bool isFunded,
                    uint256 timeLeft,
                    uint256 raisedAmount,
                    uint256 targetAmount,
                    uint256 organizerDeposit,
                    address fundingToken,
                    uint256 protocolFeesCollected,
                    uint256 uniqueBackers
                ) {
                    console.log("=== Campaign Status ===");
                    console.log("Is Active:", isActive);
                    console.log("Is Funded:", isFunded);
                    console.log("Raised Amount (wei):", raisedAmount);
                    console.log("Target Amount (wei):", targetAmount);
                    console.log("Unique Backers:", uniqueBackers);

                    // Calculate expected tokens
                    uint256 expectedTokens = raisedAmount; // Should be 1:1 ratio
                    console.log("Expected Tokens (1:1 ratio):", expectedTokens);

                    // Check if there's a decimal mismatch
                    uint256 tokenDecimals = eventToken.decimals();
                    uint256 usdcDecimals = 6; // USDC has 6 decimals

                    if (tokenDecimals != usdcDecimals) {
                        console.log("=== DECIMAL MISMATCH DETECTED ===");
                        console.log("USDC Decimals:", usdcDecimals);
                        console.log("Token Decimals:", tokenDecimals);
                        console.log("This explains the minting issue!");

                        // Calculate the correct conversion
                        if (tokenDecimals > usdcDecimals) {
                            uint256 multiplier = 10 **
                                (tokenDecimals - usdcDecimals);
                            uint256 correctTokens = raisedAmount * multiplier;
                            console.log(
                                "Correct Tokens (with decimal adjustment):",
                                correctTokens
                            );
                        } else {
                            uint256 divisor = 10 **
                                (usdcDecimals - tokenDecimals);
                            uint256 correctTokens = raisedAmount / divisor;
                            console.log(
                                "Correct Tokens (with decimal adjustment):",
                                correctTokens
                            );
                        }
                    }
                } catch Error(string memory reason) {
                    console.log("Error getting campaign status:", reason);
                } catch {
                    console.log("Could not get campaign status");
                }
            }
        } catch {
            console.log("Could not get Event Token address");
        }
    }
}

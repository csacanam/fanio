// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {Config} from "./Config.s.sol";
import {console} from "forge-std/console.sol";

contract ViewCampaign is Script {
    function run() external {
        // Get campaign ID from function parameter
        uint256 campaignId = 0; // View campaign 0 (the one we just created in the new contract)

        // Get configuration based on network
        Config config = new Config();
        address fundingManagerAddress = config.getFundingManagerAddress();

        if (fundingManagerAddress == address(0)) {
            revert(
                "FundingManager not deployed on this network. Deploy first using DeployFundingManager.s.sol"
            );
        }

        console.log("=== Viewing Campaign Details ===");
        console.log("Campaign ID:", campaignId);
        console.log("Network Chain ID:", block.chainid);
        console.log("FundingManager Address:", fundingManagerAddress);

        // Get campaign details using getCampaignStatus
        FundingManager fundingManager = FundingManager(fundingManagerAddress);

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
            console.log("Is Expired:", isExpired);
            console.log("Is Funded:", isFunded);
            console.log("Time Left (seconds):", timeLeft);
            console.log("Raised Amount:", raisedAmount);
            console.log("Target Amount:", targetAmount);
            console.log("Organizer Deposit:", organizerDeposit);
            console.log("Funding Token:", fundingToken);
            console.log("Protocol Fees Collected:", protocolFeesCollected);
            console.log("Unique Backers:", uniqueBackers);

            // Calculate progress
            if (targetAmount > 0) {
                uint256 progress = (raisedAmount * 100) / targetAmount;
                console.log("Progress:", progress, "%");
            }

            // Calculate time remaining in human readable format
            if (timeLeft > 0) {
                uint256 daysRemaining = timeLeft / 1 days;
                uint256 hoursRemaining = (timeLeft % 1 days) / 1 hours;
                console.log("Days Remaining:", daysRemaining);
                console.log("Hours Remaining:", hoursRemaining);
            } else {
                console.log("Campaign has ended");
            }
        } catch Error(string memory reason) {
            console.log("Error getting campaign status:", reason);
        } catch {
            console.log("Campaign not found or error occurred");
        }

        // Try to get EventToken address
        try fundingManager.getCampaignEventToken(campaignId) returns (
            address eventToken
        ) {
            console.log("Event Token Address:", eventToken);
        } catch {
            console.log("Could not get Event Token address");
        }
    }
}

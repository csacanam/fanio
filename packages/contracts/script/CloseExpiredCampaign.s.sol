// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {Config} from "./Config.s.sol";
import {console} from "forge-std/console.sol";

contract CloseExpiredCampaign is Script {
    function run() external {
        // Configuration
        uint256 campaignId = 0; // Campaign to close

        // Get configuration based on network
        Config config = new Config();
        address fundingManagerAddress = config.getFundingManagerAddress();

        if (fundingManagerAddress == address(0)) {
            revert(
                "FundingManager not deployed on this network. Deploy first using DeployFundingManager.s.sol"
            );
        }

        console.log("=== Closing Expired Campaign ===");
        console.log("Campaign ID:", campaignId);
        console.log("Network Chain ID:", block.chainid);
        console.log("FundingManager Address:", fundingManagerAddress);

        // Get private key for the caller
        uint256 callerPrivateKey = vm.parseUint(
            string.concat("0x", vm.envString("PRIVATE_KEY"))
        );
        address caller = vm.addr(callerPrivateKey);

        console.log("Caller Address:", caller);

        // Get campaign status before closing
        FundingManager fundingManager = FundingManager(fundingManagerAddress);

        try fundingManager.getCampaignStatus(campaignId) returns (
            bool isActive,
            bool isExpired,
            bool isFunded,
            uint256 timeLeft,
            uint256 raisedAmount,
            uint256 targetAmount,
            uint256 organizerDeposit,
            address /* fundingToken */,
            uint256 /* protocolFeesCollected */,
            uint256 uniqueBackers
        ) {
            console.log("=== Campaign Status Before Closing ===");
            console.log("Is Active:", isActive);
            console.log("Is Expired:", isExpired);
            console.log("Is Funded:", isFunded);
            console.log("Time Left (seconds):", timeLeft);
            console.log("Raised Amount:", raisedAmount / 1e6, "USDC");
            console.log("Target Amount:", targetAmount / 1e6, "USDC");
            console.log("Organizer Deposit:", organizerDeposit / 1e6, "USDC");
            console.log("Unique Backers:", uniqueBackers);

            if (isFunded) {
                console.log("Campaign is already funded, cannot close");
                return;
            }

            if (!isExpired) {
                console.log("Campaign is not expired yet, cannot close");
                return;
            }

            // Close the campaign
            console.log("Closing expired campaign...");
            vm.startBroadcast(callerPrivateKey);

            fundingManager.closeExpiredCampaign(campaignId);

            vm.stopBroadcast();
            console.log("Campaign closed successfully!");

            // Get campaign status after closing
            try fundingManager.getCampaignStatus(campaignId) returns (
                bool isActiveAfter,
                bool isExpiredAfter,
                bool isFundedAfter,
                uint256 /* timeLeftAfter */,
                uint256 raisedAmountAfter,
                uint256 targetAmountAfter,
                uint256 organizerDepositAfter,
                address /* fundingTokenAfter */,
                uint256 /* protocolFeesCollectedAfter */,
                uint256 uniqueBackersAfter
            ) {
                console.log("=== Campaign Status After Closing ===");
                console.log("Is Active:", isActiveAfter);
                console.log("Is Expired:", isExpiredAfter);
                console.log("Is Funded:", isFundedAfter);
                console.log("Raised Amount:", raisedAmountAfter / 1e6, "USDC");
                console.log("Target Amount:", targetAmountAfter / 1e6, "USDC");
                console.log(
                    "Organizer Deposit:",
                    organizerDepositAfter / 1e6,
                    "USDC"
                );
                console.log("Unique Backers:", uniqueBackersAfter);
            } catch {
                console.log("Could not get campaign status after closing");
            }
        } catch Error(string memory reason) {
            console.log("Error getting campaign status:", reason);
        } catch {
            console.log("Could not get campaign status");
        }
    }
}

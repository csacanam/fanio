// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {Config} from "./Config.s.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract ContributeToCampaign is Script {
    function run() external {
        // Configuration - modify these values as needed
        uint256 campaignId = 0; // Campaign to contribute to
        uint256 contributionAmount = 10_000e6; // 10k USDC (10,000,000,000 wei)

        // Get configuration based on network
        Config config = new Config();
        address fundingManagerAddress = config.getFundingManagerAddress();
        (address fundingToken, ) = config.getBaseSepoliaConfig();

        if (fundingManagerAddress == address(0)) {
            revert(
                "FundingManager not deployed on this network. Deploy first using DeployFundingManager.s.sol"
            );
        }

        console.log("=== Contributing to Campaign ===");
        console.log("Campaign ID:", campaignId);
        console.log("Contribution Amount:", contributionAmount / 1e6, "USDC");
        console.log("Network Chain ID:", block.chainid);
        console.log("FundingManager Address:", fundingManagerAddress);
        console.log("USDC Address:", fundingToken);

        // Get private key for the contributor
        uint256 contributorPrivateKey = vm.parseUint(
            string.concat("0x", vm.envString("PRIVATE_KEY"))
        );
        address contributor = vm.addr(contributorPrivateKey);

        console.log("Contributor Address:", contributor);

        // Get USDC contract
        IERC20 usdc = IERC20(fundingToken);

        // Check USDC balance
        uint256 balance = usdc.balanceOf(contributor);
        console.log("USDC Balance:", balance / 1e6, "USDC");

        if (balance < contributionAmount) {
            revert("Insufficient USDC balance for contribution");
        }

        // Check allowance
        uint256 allowance = usdc.allowance(contributor, fundingManagerAddress);
        console.log("Current Allowance:", allowance / 1e6, "USDC");

        // If allowance is insufficient, approve
        if (allowance < contributionAmount) {
            console.log("Approving USDC spending...");
            vm.startBroadcast(contributorPrivateKey);
            usdc.approve(fundingManagerAddress, contributionAmount);
            vm.stopBroadcast();
            console.log("USDC approved for FundingManager");
        }

        // Make contribution
        console.log("Making contribution...");
        vm.startBroadcast(contributorPrivateKey);

        FundingManager fundingManager = FundingManager(fundingManagerAddress);
        fundingManager.contribute(campaignId, contributionAmount);

        vm.stopBroadcast();
        console.log("Contribution successful!");

        // Get updated campaign status
        try fundingManager.getCampaignStatus(campaignId) returns (
            bool /* isActive */,
            bool /* isExpired */,
            bool /* isFunded */,
            uint256 /* timeLeft */,
            uint256 raisedAmount,
            uint256 targetAmount,
            uint256 /* organizerDeposit */,
            address /* fundingTokenAddr */,
            uint256 /* protocolFeesCollected */,
            uint256 /* uniqueBackers */
        ) {
            console.log("=== Updated Campaign Status ===");
            console.log("Raised Amount:", raisedAmount / 1e6, "USDC");
            console.log("Target Amount:", targetAmount / 1e6, "USDC");

            if (targetAmount > 0) {
                uint256 progress = (raisedAmount * 100) / targetAmount;
                console.log("Progress:", progress, "%");
            }
        } catch {
            console.log("Could not get updated campaign status");
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {Config} from "./Config.s.sol";
import {console} from "forge-std/console.sol";

contract CreateCampaign is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.parseUint(
            string.concat("0x", vm.envString("PRIVATE_KEY"))
        );
        address deployer = vm.addr(deployerPrivateKey);

        // Get configuration based on network
        Config config = new Config();
        address fundingManagerAddress = config.getFundingManagerAddress();

        if (fundingManagerAddress == address(0)) {
            revert(
                "FundingManager not deployed on this network. Deploy first using DeployFundingManager.s.sol"
            );
        }

        // Campaign configuration
        string memory eventName = "Taylor Swift | The Eras Tour";
        string memory tokenSymbol = "TSBOG";
        uint256 targetAmount = 100e6; // 100 USDC (6 decimals) - much smaller for testing
        uint256 durationDays = 30; // 30 days
        address fundingToken = address(0); // Use default (USDC)

        console.log("=== Creating Campaign ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("FundingManager Address:", fundingManagerAddress);
        console.log("Event Name:", eventName);
        console.log("Token Symbol:", tokenSymbol);
        console.log("Target Amount:", targetAmount);
        console.log("Duration (days):", durationDays);
        console.log("Organizer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Create campaign
        FundingManager fundingManager = FundingManager(fundingManagerAddress);
        uint256 campaignId = fundingManager.createCampaign(
            eventName,
            tokenSymbol,
            targetAmount,
            durationDays,
            fundingToken
        );

        vm.stopBroadcast();

        console.log("=== Campaign Created Successfully ===");
        console.log("Campaign ID:", campaignId);
    }
}

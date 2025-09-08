// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {Config} from "./Config.s.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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

        // Get USDC token address from config
        (address fundingToken, ) = config.getBaseSepoliaConfig();

        console.log("=== USDC Setup ===");
        console.log("USDC Address:", fundingToken);

        // Check USDC balance and approve if needed
        IERC20 usdc = IERC20(fundingToken);
        uint256 balance = usdc.balanceOf(deployer);
        uint256 requiredAmount = 10e6; // 10 USDC for deposit (10% of 100 USDC)
        console.log("Your USDC Balance:", balance);
        console.log("Required Amount:", requiredAmount);

        if (balance < requiredAmount) {
            revert("Insufficient USDC balance");
        }

        // Check current allowance and approve if needed
        uint256 currentAllowance = usdc.allowance(
            deployer,
            fundingManagerAddress
        );
        console.log("Current Allowance:", currentAllowance);

        if (currentAllowance < requiredAmount) {
            console.log("Approving USDC...");
            vm.startBroadcast(deployerPrivateKey);
            usdc.approve(fundingManagerAddress, requiredAmount);
            vm.stopBroadcast();
            console.log("USDC approved successfully");
        } else {
            console.log("USDC already approved");
        }

        console.log("=== Creating Campaign ===");
        console.log("Network Chain ID:", block.chainid);
        console.log("FundingManager Address:", fundingManagerAddress);
        console.log("Event Name: Taylor Swift | The Eras Tour");
        console.log("Token Symbol: TSBOG");
        console.log("Target Amount: 100000000");
        console.log("Duration (days): 30");
        console.log("Organizer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Create campaign
        FundingManager fundingManager = FundingManager(fundingManagerAddress);
        uint256 campaignId = fundingManager.createCampaign(
            "Taylor Swift | The Eras Tour",
            "TSBOG",
            100e6, // 100 USDC (6 decimals)
            30, // 30 days
            fundingToken
        );

        vm.stopBroadcast();

        console.log("=== Campaign Created Successfully ===");
        console.log("Campaign ID:", campaignId);
    }
}   

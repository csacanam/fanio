// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";

contract CreateCampaign is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Configuration - Update these values
        address fundingManagerAddress = address(0); // Address of deployed FundingManager
        string memory eventName = "Taylor Swift | The Eras Tour";
        string memory tokenSymbol = "TSBOG";
        uint256 targetAmount = 100_000e6; // 100k USDC (6 decimals)
        uint256 duration = 30 days;
        address organizer = deployer; // Organizer address

        vm.startBroadcast(deployerPrivateKey);

        // Create campaign
        FundingManager fundingManager = FundingManager(fundingManagerAddress);
        fundingManager.createCampaign(
            eventName,
            tokenSymbol,
            targetAmount,
            duration,
            organizer
        );

        vm.stopBroadcast();
    }
}

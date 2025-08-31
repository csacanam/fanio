// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {Config} from "./Config.s.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {console} from "forge-std/console.sol";

contract DeployFundingManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.parseUint(
            string.concat("0x", vm.envString("PRIVATE_KEY"))
        );
        address deployer = vm.addr(deployerPrivateKey);

        // Get configuration based on network
        Config config = new Config();

        address fundingToken;
        address protocolWallet;

        // Check if we're on local network (Anvil)
        if (block.chainid == 31337) {
            // Local deployment: deploy MockUSDC first, then FundingManager
            vm.startBroadcast(deployerPrivateKey);

            MockUSDC mockUSDC = new MockUSDC();
            fundingToken = address(mockUSDC);
            protocolWallet = deployer; // Use deployer as protocol wallet for local testing

            // For local deployment, use a mock PoolManager address
            // In real usage, this would be the actual PoolManager
            address poolManager = address(0x123); // Mock address for local testing

            FundingManager fundingManager = new FundingManager(
                fundingToken,
                protocolWallet,
                poolManager,
                address(0) // No hook for now
            );

            vm.stopBroadcast();

            // Print deployment addresses (Foundry standard)
            console.log("=== Local Deployment Complete ===");
            console.log("MockUSDC deployed at:", address(mockUSDC));
            console.log("FundingManager deployed at:", address(fundingManager));
            console.log("Protocol Wallet:", protocolWallet);
        } else {
            // Network deployment: use Config.s.sol values
            (fundingToken, protocolWallet) = config.getBaseSepoliaConfig();

            vm.startBroadcast(deployerPrivateKey);

            // Base Sepolia PoolManager address
            address poolManager = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;

            FundingManager fundingManager = new FundingManager(
                fundingToken,
                protocolWallet,
                poolManager,
                address(0) // No hook for now
            );

            vm.stopBroadcast();

            // Print deployment addresses (Foundry standard)
            console.log("=== Network Deployment Complete ===");
            console.log("FundingManager deployed at:", address(fundingManager));
            console.log("Funding Token:", fundingToken);
            console.log("Protocol Wallet:", protocolWallet);
        }
    }
}

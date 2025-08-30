// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {Config} from "./Config.s.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";

contract DeployFundingManager is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
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

            new FundingManager(fundingToken, protocolWallet);

            vm.stopBroadcast();

            // Local deployment addresses will be shown in transaction trace
            // MockUSDC: address(mockUSDC)
            // FundingManager: address(fundingManager)
            // Protocol Wallet: deployer
        } else {
            // Network deployment: use Config.s.sol values
            (fundingToken, protocolWallet) = config.getBaseSepoliaConfig();

            vm.startBroadcast(deployerPrivateKey);

            new FundingManager(fundingToken, protocolWallet);

            vm.stopBroadcast();

            // Network deployment addresses will be shown in transaction trace
            // FundingManager: address(fundingManager)
            // Funding Token: fundingToken
            // Protocol Wallet: protocolWallet
        }
    }
}

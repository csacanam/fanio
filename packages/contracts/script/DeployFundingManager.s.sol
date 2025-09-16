// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {DynamicFeeHook} from "../src/DynamicFeeHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Config} from "./Config.s.sol";
import {MockUSDC} from "../src/mocks/MockUSDC.sol";
import {AddressConstants} from "../lib/hookmate/src/constants/AddressConstants.sol";
import {console} from "forge-std/console.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

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

            // Deploy DynamicFeeHook first
            DynamicFeeHook dynamicFeeHook = new DynamicFeeHook(
                IPoolManager(poolManager),
                deployer // Use deployer as authorized caller
            );

            // Deploy PositionManager (mock for now)
            address positionManager = address(0x456); // Mock address for local testing

            FundingManager fundingManager = new FundingManager(
                fundingToken,
                protocolWallet,
                poolManager,
                address(dynamicFeeHook),
                positionManager
            );

            // Transfer authorization from deployer to FundingManager
            dynamicFeeHook.setAuthorizedCaller(address(fundingManager));

            vm.stopBroadcast();

            // Print deployment addresses (Foundry standard)
            console.log("=== Local Deployment Complete ===");
            console.log("MockUSDC deployed at:", address(mockUSDC));
            console.log("FundingManager deployed at:", address(fundingManager));
            console.log("DynamicFeeHook deployed at:", address(dynamicFeeHook));
            console.log("Protocol Wallet:", protocolWallet);
        } else if (block.chainid == 84532) {
            // Base Sepolia deployment: use Base Sepolia config
            (fundingToken, protocolWallet) = config.getBaseSepoliaConfig();

            vm.startBroadcast(deployerPrivateKey);

            // Get addresses from AddressConstants
            address poolManager = AddressConstants.getPoolManagerAddress(
                block.chainid
            );
            address positionManager = AddressConstants
                .getPositionManagerAddress(block.chainid);

            uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);

            // Mine a salt that will produce a hook address with the correct flags
            bytes memory constructorArgs = abi.encode(poolManager, deployer);
            (address hookAddress, bytes32 salt) = HookMiner.find(
                CREATE2_FACTORY,
                flags,
                type(DynamicFeeHook).creationCode,
                constructorArgs
            );

            // Deploy DynamicFeeHook first
            DynamicFeeHook dynamicFeeHook = new DynamicFeeHook{salt: salt}(
                IPoolManager(poolManager),
                deployer // Use deployer as authorized caller
            );

            FundingManager fundingManager = new FundingManager(
                fundingToken,
                protocolWallet,
                poolManager,
                address(dynamicFeeHook),
                positionManager
            );

            // Transfer authorization from deployer to FundingManager
            dynamicFeeHook.setAuthorizedCaller(address(fundingManager));

            vm.stopBroadcast();

            require(
                address(dynamicFeeHook) == hookAddress,
                "DeployHookScript: Hook Address Mismatch"
            );

            // Print deployment addresses (Foundry standard)
            console.log("=== Base Sepolia Deployment Complete ===");
            console.log("FundingManager deployed at:", address(fundingManager));
            console.log("DynamicFeeHook deployed at:", address(dynamicFeeHook));
            console.log("PoolManager address:", poolManager);
            console.log("PositionManager address:", positionManager);
            console.log("Funding Token:", fundingToken);
            console.log("Protocol Wallet:", protocolWallet);
        } else {
            revert("Unsupported network");
        }
    }
}

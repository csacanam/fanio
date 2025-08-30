// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

contract Config is Script {
    // Network-specific configurations

    // Base Sepolia
    function getBaseSepoliaConfig()
        external
        pure
        returns (address fundingToken, address protocolWallet)
    {
        fundingToken = address(0x7de9a0c146Cc6A92F2592C5E4e2331B263De88B1); // USDC on Base Sepolia
        protocolWallet = address(0x3F696921Df10037961aF3b757689FC383709b75d); // Update with your wallet
    }

    // Local/Anvil
    function getLocalConfig()
        external
        pure
        returns (address fundingToken, address protocolWallet)
    {
        fundingToken = address(0); // Will be deployed separately for local testing
        protocolWallet = address(0x3F696921Df10037961aF3b757689FC383709b75d); // Your wallet
    }

    // Get FundingManager address for current network
    function getFundingManagerAddress() external view returns (address) {
        if (block.chainid == 31337) {
            // Local/Anvil - return address(0) to indicate it needs to be deployed
            return address(0);
        } else if (block.chainid == 84532) {
            // Base Sepolia - return the deployed address
            return address(0xDEC2A229CfDBc512198c19ac63b67BdAAE20f42C);
        } else {
            // Unknown network
            revert("Unsupported network");
        }
    }
}

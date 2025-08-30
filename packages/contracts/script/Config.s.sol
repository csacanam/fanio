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
        protocolWallet = address(0x3F696921Df10037961aF3b757689FC383709b75d); // Update with your wallet
    }
}

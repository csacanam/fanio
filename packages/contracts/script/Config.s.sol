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
        fundingToken = address(0x036CBD53842c5426634e7929541ec2318F3DCF7C); // USDC on Base Sepolia
        protocolWallet = address(0x1234567890123456789012345678901234567890); // Update with your wallet
    }

    // Local/Anvil
    function getLocalConfig()
        external
        pure
        returns (address fundingToken, address protocolWallet)
    {
        fundingToken = address(0); // Will be deployed separately for local testing
        protocolWallet = address(0x1234567890123456789012345678901234567890); // Update with your wallet
    }
}

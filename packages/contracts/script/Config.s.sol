// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {AddressConstants} from "../lib/hookmate/src/constants/AddressConstants.sol";

contract Config is Script {
    // Network-specific configurations

    // Base Sepolia
    function getBaseSepoliaConfig()
        external
        pure
        returns (address fundingToken, address protocolWallet)
    {
        fundingToken = address(0xC8310baA6444e135f7BC54D698F0EE32Fa0621a3); // USDC real on Base Sepolia
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
            return address(0xe8ff979679459D966D26185446fa301228ac401B);
        } else if (block.chainid == 8453) {
            // Base Mainnet - return address(0) to indicate it needs to be deployed
            return address(0);
        } else {
            // Unknown network
            revert("Unsupported network");
        }
    }

    function getStateViewAddress() external view returns (address) {
        if (block.chainid == 31337) {
            // Local/Anvil - return address(0) to indicate it needs to be deployed
            return address(0);
        } else if (block.chainid == 84532) {
            // Base Sepolia - return the StateView address
            return address(0xe8ff979679459D966D26185446fa301228ac401B);
        } else if (block.chainid == 8453) {
            // Base Mainnet - return address(0) to indicate it needs to be deployed
            return address(0);
        } else {
            // Unknown network
            revert("Unsupported network");
        }
    }

    function getQuoterAddress() external view returns (address) {
        if (block.chainid == 31337) {
            // Local/Anvil - return address(0) to indicate it needs to be deployed
            return address(0);
        } else if (block.chainid == 84532) {
            // Base Sepolia - return the Quoter address
            return address(0xe8ff979679459D966D26185446fa301228ac401B);
        } else if (block.chainid == 8453) {
            // Base Mainnet - return address(0) to indicate it needs to be deployed
            return address(0);
        } else {
            // Unknown network
            revert("Unsupported network");
        }
    }
}

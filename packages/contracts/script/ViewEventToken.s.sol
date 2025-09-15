// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {EventToken} from "../src/EventToken.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {Config} from "./Config.s.sol";
import {console} from "forge-std/console.sol";

contract ViewEventToken is Script {
    function run() external {
        // Configuration
        uint256 campaignId = 0; // Campaign to view EventToken for

        // Get configuration based on network
        Config config = new Config();
        address fundingManagerAddress = config.getFundingManagerAddress();

        if (fundingManagerAddress == address(0)) {
            revert(
                "FundingManager not deployed on this network. Deploy first using DeployFundingManager.s.sol"
            );
        }

        console.log("=== Viewing EventToken Details ===");
        console.log("Campaign ID:", campaignId);
        console.log("Network Chain ID:", block.chainid);
        console.log("FundingManager Address:", fundingManagerAddress);

        // Get EventToken address from campaign
        FundingManager fundingManager = FundingManager(fundingManagerAddress);

        try fundingManager.getCampaignEventToken(campaignId) returns (
            address eventTokenAddress
        ) {
            if (eventTokenAddress == address(0)) {
                console.log("No EventToken created for this campaign yet");
                return;
            }

            console.log("EventToken Address:", eventTokenAddress);

            EventToken eventToken = EventToken(eventTokenAddress);

            try eventToken.name() returns (string memory name) {
                console.log("Token Name:", name);
            } catch {
                console.log("Could not get token name");
            }

            try eventToken.symbol() returns (string memory symbol) {
                console.log("Token Symbol:", symbol);
            } catch {
                console.log("Could not get token symbol");
            }

            try eventToken.decimals() returns (uint8 decimals) {
                console.log("Token Decimals:", decimals);
            } catch {
                console.log("Could not get token decimals");
            }

            try eventToken.totalSupply() returns (uint256 totalSupply) {
                console.log("Total Supply:", totalSupply / 1e18, "tokens");
            } catch {
                console.log("Could not get total supply");
            }

            try eventToken.cap() returns (uint256 cap) {
                console.log("Token Cap:", cap / 1e18, "tokens");
            } catch {
                console.log("Could not get token cap");
            }
        } catch Error(string memory reason) {
            console.log("Error getting EventToken address:", reason);
        } catch {
            console.log("Could not get EventToken address");
        }
    }
}

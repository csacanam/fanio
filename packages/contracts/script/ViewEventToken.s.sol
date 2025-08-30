// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {EventToken} from "../src/EventToken.sol";
import {console} from "forge-std/console.sol";

contract ViewEventToken is Script {
    function run() external {
        // EventToken address from the campaign
        address eventTokenAddress = 0x9Df184226612937a035d5bC226B604Ec72Dc6d2B;

        console.log("=== Viewing EventToken Details ===");
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

        try eventToken.totalSupply() returns (uint256 totalSupply) {
            console.log("Total Supply:", totalSupply);
        } catch {
            console.log("Could not get total supply");
        }
    }
}

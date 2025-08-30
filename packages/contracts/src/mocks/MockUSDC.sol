// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("Mock USDC", "USDC") {
        _mint(msg.sender, 1000000 * 10 ** 6); // 1M USDC with 6 decimals
    }

    function decimals() public pure override returns (uint8) {
        return 6; // USDC has 6 decimals
    }
}

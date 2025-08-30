// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
 * @title EventToken
 * @dev Standard ERC20 token with capped supply using OpenZeppelin's ERC20Capped
 *
 * This token represents shares in an event and has a maximum supply
 * equal to 1.3x the funding target (100% for contributors + 30% for liquidity)
 */
contract EventToken is ERC20Capped {
    /**
     * @dev Constructor creates a new EventToken with capped supply
     * @param _name Token name (e.g., "Bad Bunny NY 2025")
     * @param _symbol Token symbol (e.g., "BBNY25")
     * @param _cap Maximum total supply (1.3x funding target)
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cap
    ) ERC20(_name, _symbol) ERC20Capped(_cap) {}
}

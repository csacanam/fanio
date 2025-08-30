// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
 * @title EventToken
 * @dev Standard ERC20 token with capped supply and controlled minting
 *
 * This token represents shares in an event and has a maximum supply
 * equal to 155% of the funding target:
 * - 130% for contributors (1:1 ratio with funding)
 * - 25% extra for initial liquidity pool (1.2x price premium)
 *
 * Only the FundingManager contract can mint new tokens, ensuring
 * controlled token distribution and maintaining tokenomics integrity.
 */
contract EventToken is ERC20Capped {
    // FundingManager address that can mint tokens
    address public immutable FUNDING_MANAGER;

    /**
     * @dev Constructor creates a new EventToken with capped supply
     * @param _name Token name (e.g., "Bad Bunny NY 2025")
     * @param _symbol Token symbol (e.g., "BBNY25")
     * @param _cap Maximum total supply (155% of funding target)
     * @param _fundingManager Address of the FundingManager contract
     */
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cap,
        address _fundingManager
    ) ERC20(_name, _symbol) ERC20Capped(_cap) {
        require(
            _fundingManager != address(0),
            "Invalid funding manager address"
        );
        FUNDING_MANAGER = _fundingManager;
    }

    /**
     * @dev Mint new tokens (only FundingManager can mint)
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == FUNDING_MANAGER, "Only FundingManager can mint");
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be positive");
        require(totalSupply() + amount <= cap(), "Exceeds max supply");

        _mint(to, amount);
    }
}

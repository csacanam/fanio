// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

/**
 * @title EventToken
 * @dev ERC20 token with capped supply and controlled minting for crowdfunding campaigns
 *
 * This token represents ownership shares in a specific live event and serves as the
 * primary mechanism for fan engagement and value capture in the Fanio ecosystem.
 *
 * TOKENOMICS:
 * - Total Supply: 155% of the funding target
 * - Contributors: 100% of target (1:1 ratio with contribution)
 * - Pool Liquidity: 25% of target (for Uniswap V4 initial liquidity)
 * - Remaining 30%: Reserved for future pool expansion
 *
 * SECURITY FEATURES:
 * - Capped supply prevents inflation
 * - Only FundingManager can mint tokens
 * - Immutable FUNDING_MANAGER address
 * - Standard ERC20 functionality with OpenZeppelin security
 *
 * USE CASES:
 * - Early access to event tickets
 * - Voting rights on event decisions
 * - Trading on secondary markets (Uniswap V4)
 * - Event-specific perks and benefits
 *
 * @author Fanio Team
 * @notice This token is deployed once per crowdfunding campaign
 */
contract EventToken is ERC20Capped {
    // ========================================
    // IMMUTABLE STATE VARIABLES
    // ========================================

    /// @notice Address of the FundingManager contract that can mint tokens
    /// @dev This address is set during construction and cannot be changed
    address public immutable FUNDING_MANAGER;

    // ========================================
    // CONSTRUCTOR
    // ========================================

    /**
     * @dev Initialize a new EventToken for a crowdfunding campaign
     *
     * This constructor creates a new ERC20 token with a predefined cap that
     * represents the maximum supply for the specific event. The token is
     * immediately ready for controlled minting by the FundingManager.
     *
     * @param _name Human-readable token name (e.g., "Bad Bunny NY 2025")
     * @param _symbol Short token symbol (e.g., "BBNY25")
     * @param _cap Maximum total supply (155% of funding target)
     * @param _fundingManager Address of the FundingManager contract
     *
     * @notice Token name and symbol should be descriptive of the specific event
     * @notice Cap is calculated as: targetAmount * 155 / 100
     * @notice FundingManager address is immutable and cannot be changed
     * @notice Token is immediately ready for minting by FundingManager
     *
     * @custom:security Validates fundingManager is not zero address
     * @custom:security Inherits OpenZeppelin ERC20Capped security features
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

    // ========================================
    // MINTING FUNCTIONS
    // ========================================

    /**
     * @dev Mint new tokens to a specified address
     *
     * This function allows the FundingManager to mint new EventTokens during
     * the crowdfunding process. It's the only way new tokens can be created,
     * ensuring controlled supply and maintaining tokenomics integrity.
     *
     * MINTING SCENARIOS:
     * 1. Contributor tokens: Minted 1:1 with contribution amount
     * 2. Pool tokens: Minted for Uniswap V4 initial liquidity (25% of target)
     *
     * @param to Recipient address for the minted tokens
     * @param amount Number of tokens to mint
     *
     * @notice Only the FundingManager contract can call this function
     * @notice Tokens are minted directly to the recipient address
     * @notice Total supply cannot exceed the predefined cap
     * @notice Zero address and zero amount are not allowed
     *
     * @custom:security Only callable by FUNDING_MANAGER address
     * @custom:security Prevents minting to zero address
     * @custom:security Ensures positive minting amount
     * @custom:security Enforces supply cap limit
     * @custom:security Inherits OpenZeppelin _mint security
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == FUNDING_MANAGER, "Only FundingManager can mint");
        require(to != address(0), "Cannot mint to zero address");
        require(amount > 0, "Amount must be positive");
        require(totalSupply() + amount <= cap(), "Exceeds max supply");

        _mint(to, amount);
    }
}

// ========================================
// BUSINESS LOGIC & TOKENOMICS
// ========================================
/*
 * EVENT TOKEN OVERVIEW:
 *
 * PURPOSE:
 * Each EventToken represents ownership shares in a specific live event,
 * enabling fans to participate in event funding and capture value from
 * successful events.
 *
 * TOKEN SUPPLY BREAKDOWN (155% of funding target):
 *
 * 1. CONTRIBUTOR TOKENS (100% of target):
 *    - Minted 1:1 with contribution amount
 *    - Example: $100 USDC contribution = 100 EventTokens
 *    - Distributed immediately upon contribution
 *    - Represents direct ownership in the event
 *
 * 2. POOL LIQUIDITY TOKENS (25% of target):
 *    - Minted during funding finalization
 *    - Reserved for Uniswap V4 initial liquidity
 *    - Enables secondary market trading
 *    - Example: $100k target = 25k pool tokens
 *
 * 3. REMAINING SUPPLY (30% of target):
 *    - Available for future pool expansion
 *    - Can be used for additional liquidity
 *    - Maintains price stability
 *
 * MINTING CONTROL:
 * - Only FundingManager can mint tokens
 * - Prevents unauthorized token creation
 * - Maintains supply cap integrity
 * - Ensures controlled distribution
 *
 * USE CASES:
 * - Early access to event tickets
 * - Voting on event decisions (setlist, venue, etc.)
 * - Trading on secondary markets
 * - Event-specific perks and benefits
 * - Proof of participation and support
 *
 * SECURITY FEATURES:
 * - Immutable FUNDING_MANAGER address
 * - Supply cap enforcement
 * - OpenZeppelin ERC20Capped security
 * - Controlled minting access
 */

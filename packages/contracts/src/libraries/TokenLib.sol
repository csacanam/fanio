// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/**
 * @title TokenLib
 * @dev Library for token-related utility functions
 *
 * This library provides utility functions for handling token operations,
 * decimal conversions, and token cap calculations across the Fanio platform.
 *
 * PURPOSE:
 * Centralizes token-related logic to handle decimal differences between
 * funding tokens (USDC with 6 decimals) and EventTokens (18 decimals).
 * Ensures accurate conversions and calculations across the ecosystem.
 *
 * KEY FEATURES:
 * - Safe decimal retrieval with fallback to 18
 * - Token cap calculation (140% of target with decimal adjustment)
 * - Decimal conversion between different token standards
 * - User token calculation for 1:1 minting ratio
 *
 * DECIMAL HANDLING:
 * - USDC: 6 decimals (funding token)
 * - EventToken: 18 decimals (event token)
 * - Automatic conversion between different decimal standards
 *
 * USAGE:
 * This library is used by FundingManager.sol and EventToken.sol for
 * all token-related calculations and conversions.
 *
 * @author Fanio Team
 */
library TokenLib {
    /**
     * @dev Safely get token decimals with fallback to 18
     *
     * @param token Address of the token contract
     * @return decimals Number of decimals (18 if call fails)
     * @dev Uses try-catch to handle tokens without decimals() function
     * @dev Defaults to 18 decimals if call fails for safety
     */
    function safeDecimals(address token) internal view returns (uint8) {
        try IERC20Metadata(token).decimals() returns (uint8 d) {
            return d;
        } catch {
            return 18;
        }
    }

    /**
     * @dev Calculate token cap accounting for decimal differences
     *
     * @param targetAmount Target amount in funding token units
     * @param fundingToken Address of the funding token
     * @param eventTokenDecimals Number of decimals for the EventToken
     * @return Cap amount in event token units (140% of target)
     */
    function calculateTokenCap(
        uint256 targetAmount,
        address fundingToken,
        uint8 eventTokenDecimals
    ) internal view returns (uint256) {
        uint256 fundingTokenDecimals = safeDecimals(fundingToken);

        // Convert targetAmount from funding token units to event token units
        uint256 targetInEventTokenUnits;
        if (eventTokenDecimals > fundingTokenDecimals) {
            uint256 multiplier = 10 **
                (eventTokenDecimals - fundingTokenDecimals);
            targetInEventTokenUnits = targetAmount * multiplier;
        } else {
            uint256 divisor = 10 ** (fundingTokenDecimals - eventTokenDecimals);
            targetInEventTokenUnits = targetAmount / divisor;
        }

        // Calculate cap: 140% of target in event token units
        return (targetInEventTokenUnits * 140) / 100;
    }

    /**
     * @dev Convert funding token units to event token units
     *
     * @param amount Amount in funding token units
     * @param fundingToken Address of the funding token
     * @param eventTokenDecimals Number of decimals for the EventToken
     * @return Amount in event token units
     */
    function convertToEventTokenUnits(
        uint256 amount,
        address fundingToken,
        uint8 eventTokenDecimals
    ) internal view returns (uint256) {
        uint256 fundingTokenDecimals = safeDecimals(fundingToken);

        // Convert amount from funding token units to event token units
        if (eventTokenDecimals > fundingTokenDecimals) {
            uint256 multiplier = 10 **
                (eventTokenDecimals - fundingTokenDecimals);
            return amount * multiplier;
        } else {
            uint256 divisor = 10 ** (fundingTokenDecimals - eventTokenDecimals);
            return amount / divisor;
        }
    }

    /**
     * @dev Calculate user tokens with decimal adjustment
     *
     * @param amount Contribution amount in funding token units
     * @param fundingTokenDecimals Decimals of funding token
     * @param eventTokenDecimals Decimals of event token
     * @return userTokens Amount of event tokens to mint
     * @dev Implements 1:1 ratio with decimal conversion
     * @dev $100 USDC (6d) = 100 EventTokens (18d)
     */
    function calculateUserTokens(
        uint256 amount,
        uint256 fundingTokenDecimals,
        uint256 eventTokenDecimals
    ) internal pure returns (uint256 userTokens) {
        if (eventTokenDecimals > fundingTokenDecimals) {
            uint256 multiplier = 10 **
                (eventTokenDecimals - fundingTokenDecimals);
            userTokens = amount * multiplier;
        } else {
            uint256 divisor = 10 ** (fundingTokenDecimals - eventTokenDecimals);
            userTokens = amount / divisor;
        }
    }
}

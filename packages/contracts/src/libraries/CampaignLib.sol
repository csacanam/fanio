// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title CampaignLib
 * @dev Library for campaign-related utility functions
 *
 * This library provides utility functions for campaign state management,
 * validation, and status checking across the Fanio platform.
 *
 * PURPOSE:
 * Centralizes campaign logic to ensure consistency and reduce code duplication
 * across the Fanio ecosystem. All campaign-related calculations and validations
 * are handled through this library.
 *
 * KEY FEATURES:
 * - Campaign expiration and time management
 * - Goal calculation with pool allocation (currently 20%)
 * - Contribution validation and limits
 * - Parameter validation for campaign creation
 * - Percentage calculations for various allocations
 *
 * USAGE:
 * This library is used by FundingManager.sol for all campaign operations
 * including creation, contribution validation, and finalization.
 *
 * @author Fanio Team
 */
library CampaignLib {
    /**
     * @dev Check if a campaign has expired
     *
     * @param deadline Campaign deadline timestamp
     * @param currentTime Current block timestamp
     * @return True if campaign has expired
     * @dev Used to determine if campaign is still active
     * @dev Campaigns expire when current time >= deadline
     */
    function isExpired(
        uint256 deadline,
        uint256 currentTime
    ) internal pure returns (bool) {
        return currentTime >= deadline;
    }

    /**
     * @dev Calculate time left until campaign deadline
     *
     * @param deadline Campaign deadline timestamp
     * @param currentTime Current block timestamp
     * @return Time left in seconds (0 if expired)
     */
    function timeLeft(
        uint256 deadline,
        uint256 currentTime
    ) internal pure returns (uint256) {
        return currentTime >= deadline ? 0 : deadline - currentTime;
    }

    /**
     * @dev Calculate campaign goal including pool allocation
     *
     * @param targetAmount Base target amount
     * @param poolAllocationPercent Pool allocation percentage (e.g., 20 for 20%)
     * @return Total goal amount including pool allocation
     * @dev Currently uses 20% pool allocation (100k + 20k = 120k)
     * @dev This determines when campaign is considered successful
     */
    function calculateCampaignGoal(
        uint256 targetAmount,
        uint256 poolAllocationPercent
    ) internal pure returns (uint256) {
        return targetAmount + (targetAmount * poolAllocationPercent) / 100;
    }

    /**
     * @dev Check if contribution would exceed maximum allowed amount
     *
     * @param currentRaised Current amount raised
     * @param contributionAmount Amount to contribute
     * @param maxAllowed Maximum allowed amount
     * @return True if contribution would exceed limit
     */
    function wouldExceedMaxAmount(
        uint256 currentRaised,
        uint256 contributionAmount,
        uint256 maxAllowed
    ) internal pure returns (bool) {
        return currentRaised + contributionAmount > maxAllowed;
    }

    /**
     * @dev Validate campaign parameters
     *
     * @param targetAmount Target amount for the campaign
     * @param durationDays Duration in days
     * @return True if parameters are valid
     */
    function validateCampaignParams(
        uint256 targetAmount,
        uint256 durationDays
    ) internal pure returns (bool) {
        return targetAmount > 0 && durationDays > 0;
    }

    /**
     * @dev Calculate required organizer deposit
     *
     * @param targetAmount Target amount for the campaign
     * @param depositPercent Deposit percentage (e.g., 10 for 10%)
     * @return Required deposit amount
     */
    function calculateRequiredDeposit(
        uint256 targetAmount,
        uint256 depositPercent
    ) internal pure returns (uint256) {
        return (targetAmount * depositPercent) / 100;
    }

    /**
     * @dev Calculate percentage of an amount
     *
     * @param amount Base amount
     * @param percent Percentage (e.g., 25 for 25%)
     * @return Calculated percentage amount
     */
    function calculatePercentage(
        uint256 amount,
        uint256 percent
    ) internal pure returns (uint256) {
        return (amount * percent) / 100;
    }
}

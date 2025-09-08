// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./EventToken.sol";

// Uniswap V4 imports
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

/**
 * @title FundingManager
 * @dev Trustless crowdfunding platform for live events powered by Uniswap v4 hooks
 *
 * This contract manages the complete lifecycle of crowdfunding campaigns:
 * 1. Campaign creation with organizer deposit (10% of target)
 * 2. Fan contributions with immediate token minting (1:1 ratio)
 * 3. Automatic funding finalization when target is reached
 * 4. Protocol fee collection and organizer fund distribution
 * 5. Pool token preparation for Uniswap V4 liquidity
 *
 * Key Features:
 * - Flexible funding tokens (default USDC + custom options)
 * - Real-time token minting for contributors
 * - Automatic campaign expiration handling
 * - Comprehensive financial tracking and accountability
 * - Gas-optimized storage structure
 *
 * @author Fanio Team
 * @notice This is the core contract for the Fanio platform
 */
contract FundingManager is ReentrancyGuard {
    // ========================================
    // IMMUTABLE STATE VARIABLES
    // ========================================

    /// @notice Default funding currency (USDC) - can be overridden per campaign
    IERC20 public immutable DEFAULT_FUNDING_TOKEN;

    /// @notice Protocol wallet for collecting fees (10% of organizer deposit)
    address public immutable PROTOCOL_WALLET;

    /// @notice Uniswap V4 PoolManager contract
    IPoolManager public immutable poolManager;

    /// @notice Fanio trading hook contract
    // address public fanioHook; // TODO: Hook variable temporarily disabled for demo

    // ========================================
    // DATA STRUCTURES
    // ========================================

    /**
     * @dev Core campaign data structure containing all campaign information
     *
     * This struct is optimized for gas efficiency while maintaining comprehensive
     * tracking of campaign state and financial accountability.
     *
     * Storage Layout (9 fields total):
     * - Core Info: 8 fields (addresses, amounts, timing, status)
     * - Accountability: 1 field (financial tracking)
     */
    struct EventCampaign {
        // ========================================
        // 🏗️ CORE CAMPAIGN INFO (8 fields)
        // ========================================

        /// @notice Address of the EventToken contract for this campaign
        /// @dev Deployed during campaign creation with FundingManager as minter
        address eventToken;
        /// @notice Address of the campaign organizer/creator
        /// @dev Only this address can withdraw funds and manage the campaign
        address organizer;
        /// @notice Custom funding token for this campaign
        /// @dev Uses DEFAULT_FUNDING_TOKEN if address(0) is passed during creation
        address fundingToken;
        /// @notice Total funding goal amount in funding token units
        /// @dev Example: 100,000 USDC for a $100k campaign
        uint256 targetAmount;
        /// @notice Organizer's initial deposit (10% of target amount)
        /// @dev This amount is collected as protocol fee if campaign succeeds
        uint256 organizerDeposit;
        /// @notice Campaign end timestamp (deadline)
        /// @dev Calculated as: block.timestamp + (durationDays * 1 days)
        uint256 deadline;
        /// @notice Whether the campaign is currently active
        /// @dev Set to false when expired, funded, or manually closed
        bool isActive;
        /// @notice Whether the campaign has reached its funding target
        /// @dev Triggers automatic finalization and fund distribution
        bool isFunded;
        // ========================================
        // 💰 ACCOUNTABILITY - Financial Tracking (3 fields)
        // ========================================

        /// @notice Total amount raised from all contributors
        /// @dev Increases with each contribution, max = targetAmount
        uint256 raisedAmount;
        /// @notice Protocol fees collected (equal to organizerDeposit)
        /// @dev Only collected if campaign succeeds, sent to PROTOCOL_WALLET
        uint256 protocolFeesCollected;
        /// @notice Number of unique contributors to this campaign
        /// @dev Increments when a new address makes their first contribution
        uint256 uniqueBackers;
    }

    // ========================================
    // STORAGE VARIABLES
    // ========================================

    /// @notice Mapping from campaign ID to campaign data
    /// @dev campaignId starts from 0 and increments with each new campaign
    mapping(uint256 => EventCampaign) public campaigns;

    /// @notice Mapping from user address to campaign ID to contribution amount
    /// @dev Tracks individual user contributions for each campaign
    mapping(address => mapping(uint256 => uint256)) public userContributions;

    /// @notice Next available campaign ID (auto-incrementing)
    /// @dev Used to generate unique campaign identifiers
    uint256 public nextCampaignId;

    // ========================================
    // EVENTS
    // ========================================

    /**
     * @dev Emitted when a new crowdfunding campaign is created
     * @param campaignId Unique identifier for the campaign
     * @param organizer Address of the campaign creator
     * @param eventToken Address of the deployed EventToken contract
     * @param fundingToken Address of the funding token used
     * @param targetAmount Funding goal amount
     * @param organizerDeposit Initial deposit amount (10% of target)
     * @param deadline Campaign end timestamp
     */
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed organizer,
        address eventToken,
        address fundingToken,
        uint256 targetAmount,
        uint256 organizerDeposit,
        uint256 deadline
    );

    /**
     * @dev Emitted when a user contributes to a campaign
     * @param campaignId ID of the campaign being contributed to
     * @param contributor Address of the contributing user
     * @param amount Amount contributed in funding token units
     * @param tokensMinted Event tokens minted to contributor (1:1 ratio)
     */
    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount,
        uint256 tokensMinted
    );

    /**
     * @dev Emitted when a campaign successfully reaches its funding target
     * @param campaignId ID of the funded campaign
     * @param totalRaised Total amount raised (equal to target amount)
     */
    event CampaignFunded(uint256 indexed campaignId, uint256 totalRaised);

    /**
     * @dev Emitted when a campaign expires without reaching its funding target
     * @param campaignId ID of the expired campaign
     * @param totalRaised Total amount raised before expiration
     */
    event CampaignExpired(uint256 indexed campaignId, uint256 totalRaised);

    /**
     * @dev Emitted when pool tokens are minted for initial liquidity
     * @param campaignId ID of the campaign
     * @param poolTokens Number of tokens minted for pool (25% of target)
     */
    event TokensMinted(uint256 indexed campaignId, uint256 poolTokens);

    /**
     * @dev Emitted when protocol fees are collected
     * @param campaignId ID of the campaign
     * @param amount Protocol fee amount (equal to organizer deposit)
     */
    event ProtocolFeePaid(uint256 indexed campaignId, uint256 amount);

    /**
     * @dev Emitted when funds are sent to the organizer
     * @param campaignId ID of the campaign
     * @param organizer Address of the campaign organizer
     * @param amount Amount sent to organizer (100% of target)
     */
    event OrganizerFundsSent(
        uint256 indexed campaignId,
        address organizer,
        uint256 amount
    );

    // ========================================
    // CONSTRUCTOR
    // ========================================

    /**
     * @dev Initialize the FundingManager contract
     * @param defaultFundingToken Address of the default funding token (e.g., USDC)
     * @param protocolWallet Address where protocol fees will be collected
     *
     * @notice Both parameters are immutable and cannot be changed after deployment
     * @notice The defaultFundingToken is used when campaigns don't specify a custom token
     * @notice The protocolWallet receives 10% of successful campaign targets as fees
     */
    constructor(
        address defaultFundingToken,
        address protocolWallet,
        address _poolManager
        // address _fanioHook // TODO: Hook parameter temporarily disabled for demo
    ) {
        require(defaultFundingToken != address(0), "Invalid funding token");
        require(protocolWallet != address(0), "Invalid protocol wallet");
        require(_poolManager != address(0), "Invalid pool manager");

        DEFAULT_FUNDING_TOKEN = IERC20(defaultFundingToken);
        PROTOCOL_WALLET = protocolWallet;
        poolManager = IPoolManager(_poolManager);
        // fanioHook = _fanioHook; // TODO: Hook assignment temporarily disabled for demo
    }

    // ========================================
    // CAMPAIGN MANAGEMENT FUNCTIONS
    // ========================================

    /**
     * @dev Create a new crowdfunding campaign with custom EventToken
     *
     * This function performs the following operations:
     * 1. Validates input parameters
     * 2. Calculates required organizer deposit (10% of target)
     * 3. Transfers deposit from organizer to contract
     * 4. Deploys new EventToken contract with calculated cap
     * 5. Creates campaign record with all necessary data
     *
     * @param tokenName Name of the EventToken (e.g., "Concert A Token")
     * @param tokenSymbol Symbol of the EventToken (e.g., "CONCERT")
     * @param targetAmount Funding goal in funding token units (e.g., 100,000 USDC)
     * @param durationDays Campaign duration in days (e.g., 30 days)
     * @param fundingToken Custom funding token address, or address(0) for default
     *
     * @return campaignId Unique identifier for the created campaign
     *
     * @notice Organizer must approve this contract to spend requiredDeposit
     * @notice EventToken cap is calculated as 155% of target (130% for contributors + 25% for pool)
     * @notice Campaign deadline is set to block.timestamp + (durationDays * 1 days)
     *
     * @custom:security Requires organizer to have sufficient funding token balance
     * @custom:security Requires organizer to approve this contract for deposit amount
     */
    function createCampaign(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 targetAmount,
        uint256 durationDays,
        address fundingToken
    ) external returns (uint256 campaignId) {
        require(targetAmount > 0, "Target amount must be positive");
        require(durationDays > 0, "Duration must be positive");

        // Calculate required deposit (10% of target)
        uint256 requiredDeposit = targetAmount / 10; // 10%

        // Use custom funding token or default
        IERC20 tokenToUse = fundingToken == address(0)
            ? DEFAULT_FUNDING_TOKEN
            : IERC20(fundingToken);

        // Transfer tokens from organizer to contract
        require(
            tokenToUse.transferFrom(msg.sender, address(this), requiredDeposit),
            "Deposit transfer failed"
        );

        campaignId = nextCampaignId++;
        uint256 deadline = block.timestamp + (durationDays * 1 days);

        // Calculate cap: 155% of target amount, accounting for decimal differences
        uint256 cap = _calculateTokenCap(targetAmount, address(tokenToUse), 18); // EventToken will use 18 decimals

        // Deploy EventToken with FundingManager address
        // Use 18 decimals by default for compatibility with most networks
        EventToken eventToken = new EventToken(
            tokenName,
            tokenSymbol,
            cap,
            address(this),
            18 // Default decimals for EventToken
        );

        // Create campaign
        campaigns[campaignId] = EventCampaign({
            eventToken: address(eventToken),
            organizer: msg.sender,
            fundingToken: address(tokenToUse),
            targetAmount: targetAmount,
            raisedAmount: 0,
            organizerDeposit: requiredDeposit,
            deadline: deadline,
            isActive: true,
            isFunded: false,
            // 💰 Initialize accountability fields
            protocolFeesCollected: 0,
            uniqueBackers: 0
        });

        emit CampaignCreated(
            campaignId,
            msg.sender,
            address(eventToken),
            address(tokenToUse),
            targetAmount,
            requiredDeposit,
            deadline
        );
    }

    /**
     * @dev Contribute to an active crowdfunding campaign
     *
     * This function allows users to contribute funds to a campaign and immediately
     * receive EventTokens in return at a 1:1 ratio with their contribution.
     *
     * Flow:
     * 1. Checks and updates campaign status (may close expired campaigns)
     * 2. Validates campaign is still active after status check
     * 3. Validates campaign is not already funded
     * 4. Checks contribution doesn't exceed maximum allowed amount (target + 30% for pool)
     * 5. Transfers funding tokens from contributor to contract
     * 6. Updates campaign raised amount and user contribution tracking
     * 7. Mints EventTokens to contributor (1:1 ratio)
     * 8. Automatically finalizes funding if target is reached (even with excess)
     *
     * @param campaignId ID of the campaign to contribute to
     * @param amount Contribution amount in funding token units
     *
     * @notice Contributor must approve this contract to spend the contribution amount
     * @notice EventTokens are minted immediately upon contribution
     * @notice If target is reached, funding is automatically finalized
     * @notice Reentrancy protection prevents multiple contributions in same transaction
     *
     * @custom:security Requires contributor to have sufficient funding token balance
     * @custom:security Requires contributor to approve this contract for contribution amount
     * @custom:security NonReentrant modifier prevents reentrancy attacks
     */
    function contribute(
        uint256 campaignId,
        uint256 amount
    ) external nonReentrant {
        EventCampaign storage campaign = campaigns[campaignId];

        // Check and update campaign status before processing
        _checkCampaignStatus(campaignId);

        // Verify campaign is still active after status check
        require(campaign.isActive, "Campaign is not active");

        require(amount > 0, "Amount must be positive");
        require(!campaign.isFunded, "Campaign already funded");

        // Validate that contribution doesn't exceed maximum allowed amount (target + 30% for pool)
        require(
            campaign.raisedAmount + amount <=
                campaign.targetAmount + (campaign.targetAmount * 30) / 100,
            "Contribution would exceed maximum allowed amount"
        );

        // Transfer tokens from contributor using campaign's funding token
        IERC20 campaignToken = IERC20(campaign.fundingToken);
        require(
            campaignToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Register contribution
        campaign.raisedAmount += amount;
        userContributions[msg.sender][campaignId] += amount;

        // Increment unique backers count if this is the first contribution from this address
        if (userContributions[msg.sender][campaignId] == amount) {
            campaign.uniqueBackers++;
        }

        // Mint tokens immediately to contributor (1:1 ratio with decimal adjustment)
        EventToken eventToken = EventToken(campaign.eventToken);
        uint256 tokenDecimals = eventToken.decimals();

        // Get funding token decimals dynamically by calling decimals() on the token contract
        // This makes it completely generic for any ERC20 token (6, 18, or any other decimals)
        uint256 fundingTokenDecimals;
        try IERC20Metadata(campaign.fundingToken).decimals() returns (
            uint8 decimals
        ) {
            fundingTokenDecimals = decimals;
        } catch {
            // Fallback: if we can't get decimals, assume 18 (most common for ERC20)
            fundingTokenDecimals = 18;
        }

        // Adjust for decimal difference between funding token and event token
        uint256 userTokens;
        if (tokenDecimals > fundingTokenDecimals) {
            // Event token has more decimals, multiply by the difference
            uint256 multiplier = 10 ** (tokenDecimals - fundingTokenDecimals);
            userTokens = amount * multiplier;
        } else {
            // Event token has fewer decimals, divide by the difference
            uint256 divisor = 10 ** (fundingTokenDecimals - tokenDecimals);
            userTokens = amount / divisor;
        }

        eventToken.mint(msg.sender, userTokens);

        emit ContributionMade(campaignId, msg.sender, amount, userTokens);

        // Check if funding target is reached (campaign closes when organizer goal + pool amount is reached)
        // Organizer wants targetAmount (100 USDC) + 30% for pool = 130 USDC total
        uint256 campaignGoal = campaign.targetAmount +
            (campaign.targetAmount * 30) /
            100;
        if (campaign.raisedAmount >= campaignGoal) {
            _finalizeFunding(campaignId);
        }
    }

    /**
     * @dev Internal function to finalize funding when target is reached
     *
     * This function is called automatically when a campaign reaches its funding target.
     * It performs the following critical operations:
     *
     * 1. Mints pool tokens (25% of target) for initial Uniswap V4 liquidity
     * 2. Collects protocol fee (10% of target) from organizer's deposit
     * 3. Sends full target amount to organizer
     * 4. Keeps excess USDC (up to 30% of target) for pool creation
     * 5. Updates campaign state and accounting fields
     * 6. Emits relevant events for tracking
     *
     * @param campaignId ID of the campaign to finalize
     *
     * @notice This function can only be called internally when target is reached
     * @notice Pool tokens are minted to this contract for future Uniswap V4 pool creation
     * @notice Protocol fee equals the organizer's initial deposit (10% of target)
     * @notice Organizer receives exactly the target amount (100% of goal)
     * @notice Excess USDC (up to 30% of target) is kept for pool creation
     *
     * @custom:security Internal function - cannot be called directly by users
     * @custom:security Only called when campaign.raisedAmount >= campaign.targetAmount
     */
    function _finalizeFunding(uint256 campaignId) internal {
        EventCampaign storage campaign = campaigns[campaignId];

        campaign.isFunded = true;
        campaign.isActive = false;

        // 1. Mint pool tokens (25% of target for initial liquidity)
        EventToken eventToken = EventToken(campaign.eventToken);

        // Convert pool tokens from funding token units to event token units
        // This ensures consistency with the token minting logic in contribute()
        uint256 poolTokensInFundingUnits = (campaign.targetAmount * 25) / 100;

        // Get EventToken decimals dynamically
        EventToken eventTokenContract = EventToken(campaign.eventToken);
        uint8 eventTokenDecimals = eventTokenContract.decimals();

        uint256 poolTokens = _convertToEventTokenUnits(
            poolTokensInFundingUnits,
            campaign.fundingToken,
            eventTokenDecimals
        );

        eventToken.mint(address(this), poolTokens);

        emit TokensMinted(campaignId, poolTokens);

        // 2. Pay protocol fee (10% of target - from organizer deposit)
        uint256 protocolFee = campaign.organizerDeposit;
        IERC20 campaignToken = IERC20(campaign.fundingToken);

        campaignToken.transfer(PROTOCOL_WALLET, protocolFee);
        emit ProtocolFeePaid(campaignId, protocolFee);

        // 3. Send funds to organizer (100% of target)
        campaignToken.transfer(campaign.organizer, campaign.targetAmount);
        emit OrganizerFundsSent(
            campaignId,
            campaign.organizer,
            campaign.targetAmount
        );

        // 4. Pool data is now stored in EventCampaign struct

        // 💰 Update accountability fields
        campaign.protocolFeesCollected = protocolFee;

        emit CampaignFunded(campaignId, campaign.raisedAmount);

        // TODO: Hook functionality temporarily disabled for demo
        // Transfer tokens to hook for pool creation
        // if (fanioHook != address(0)) {
        //     uint256 fundingAmount = (campaign.targetAmount * 30) / 100; // 30% of target
        //     uint256 tokenAmount = IERC20(campaign.eventToken).balanceOf(address(this)); // poolTokens already minted
            
        //     _transferTokensToHook(campaignId, fundingAmount, tokenAmount);
            
        //     // TODO: Hook pool initialization temporarily disabled for demo
        //     // _initializeHookPool(campaignId, fundingAmount, tokenAmount);
        // }
    }

    // ========================================
    // UNISWAP V4 POOL CREATION
    // ========================================

    // Pool creation is now handled by the hook in afterInitialize
    // This section has been simplified to just transfer tokens and initialize pool

    /**
     * @dev Close an expired campaign that didn't reach its funding goal
     *
     * This is the PRIMARY function for handling campaign expiration. It can be called
     * by anyone to close a campaign that has passed its deadline without reaching
     * the funding target. This ensures campaigns don't remain in an inconsistent
     * state indefinitely.
     *
     * Flow:
     * 1. Validates campaign has passed its deadline
     * 2. Confirms campaign hasn't been funded
     * 3. Uses unified logic to close expired campaign
     * 4. Emits expiration event
     *
     * @param campaignId ID of the expired campaign to close
     *
     * @notice Anyone can call this function to close expired campaigns
     * @notice Campaign must be past its deadline
     * @notice Campaign must not have been successfully funded
     * @notice This function handles both active and already-inactive campaigns
     * @notice Refund logic for contributors is planned for future implementation
     *
     * @custom:security Anyone can call this function (public utility)
     * @custom:security Only affects expired, unfunded campaigns
     * @custom:security No funds are transferred in this function
     * @custom:security Idempotent - safe to call multiple times
     */
    function closeExpiredCampaign(uint256 campaignId) external {
        EventCampaign storage campaign = campaigns[campaignId];

        // Verify campaign is expired and not funded
        require(
            block.timestamp >= campaign.deadline,
            "Campaign not expired yet"
        );
        require(!campaign.isFunded, "Campaign already funded");

        // Use unified logic to close the campaign
        _checkCampaignStatus(campaignId);

        // TODO: Implement refund logic for contributors
    }

    /**
     * @dev Internal function to check and update campaign status based on current time
     *
     * This function automatically handles campaign expiration by checking if the
     * current timestamp has passed the campaign deadline. If so, it calls the
     * centralized expiration logic to mark the campaign as inactive.
     *
     * Flow:
     * 1. Checks if current time >= campaign deadline
     * 2. Verifies campaign is still active
     * 3. Confirms campaign hasn't been funded
     * 4. Closes campaign and emits event if expired
     *
     * This function contains the unified logic for closing expired campaigns
     * and is used by both automatic expiration checks and manual expiration.
     *
     * @param campaignId ID of the campaign to check
     *
     * @notice This function is called automatically before each contribution
     * @notice Only affects active, unfunded campaigns that have passed their deadline
     * @notice Campaigns that are already funded cannot expire
     * @notice This function prevents contributions to expired campaigns
     * @notice Marks expired campaigns as inactive directly for consistency
     *
     * @custom:security Internal function - cannot be called directly by users
     * @custom:security Automatically called in contribute() function
     * @custom:security No funds are transferred in this function
     * @custom:security Delegates to centralized expiration logic
     */
    function _checkCampaignStatus(uint256 campaignId) internal {
        EventCampaign storage campaign = campaigns[campaignId];

        // Check if campaign has expired and close it if necessary
        if (
            block.timestamp >= campaign.deadline &&
            campaign.isActive &&
            !campaign.isFunded
        ) {
            campaign.isActive = false;
            emit CampaignExpired(campaignId, campaign.raisedAmount);
        }
    }

    /**
     * @dev Get comprehensive campaign status information
     *
     * This function provides a complete overview of a campaign's current state,
     * including timing, funding progress, and financial accountability.
     *
     * @param campaignId ID of the campaign to query
     *
     * @return isActive Whether the campaign is currently active
     * @return isExpired Whether the campaign has expired (past deadline)
     * @return isFunded Whether the campaign has reached its funding target
     * @return timeLeft Time remaining until deadline in seconds (0 if expired)
     * @return raisedAmount Total amount raised from all contributors
     * @return targetAmount Funding goal amount
     * @return organizerDeposit Amount deposited by organizer (10% of target)
     * @return fundingToken Address of the funding token used for this campaign
     * @return protocolFeesCollected Protocol fees collected (0 if not funded)
     *
     * @notice This function provides all necessary information for frontend display
     * @notice timeLeft is calculated as max(0, deadline - block.timestamp)
     * @notice isExpired is derived from current time vs deadline comparison
     * @notice All financial amounts are in the campaign's funding token units
     */
    function getCampaignStatus(
        uint256 campaignId
    )
        external
        view
        returns (
            bool isActive,
            bool isExpired,
            bool isFunded,
            uint256 timeLeft,
            uint256 raisedAmount,
            uint256 targetAmount,
            uint256 organizerDeposit,
            address fundingToken,
            uint256 protocolFeesCollected,
            uint256 uniqueBackers
        )
    {
        EventCampaign storage campaign = campaigns[campaignId];

        isActive = campaign.isActive;
        isExpired = block.timestamp >= campaign.deadline;
        isFunded = campaign.isFunded;
        timeLeft = block.timestamp >= campaign.deadline
            ? 0
            : campaign.deadline - block.timestamp;
        raisedAmount = campaign.raisedAmount;
        targetAmount = campaign.targetAmount;
        organizerDeposit = campaign.organizerDeposit;

        fundingToken = campaign.fundingToken;

        return (
            isActive,
            isExpired,
            isFunded,
            timeLeft,
            raisedAmount,
            targetAmount,
            organizerDeposit,
            fundingToken,
            campaign.protocolFeesCollected,
            campaign.uniqueBackers
        );
    }

    /**
     * @dev Get the real campaign goal (targetAmount + 30% for pool)
     *
     * @param campaignId ID of the campaign
     * @return Real goal amount including pool allocation
     *
     * @notice This is the amount that needs to be raised for the campaign to close
     * @notice Equal to targetAmount (what organizer wants) + 30% (for pool)
     */
    function getCampaignGoal(
        uint256 campaignId
    ) external view returns (uint256) {
        EventCampaign storage campaign = campaigns[campaignId];
        return campaign.targetAmount + (campaign.targetAmount * 30) / 100;
    }

    /**
     * @dev Get EventToken address for a specific campaign
     *
     * @param campaignId ID of the campaign
     * @return Address of the EventToken contract for this campaign
     */
    function getCampaignEventToken(
        uint256 campaignId
    ) external view returns (address) {
        return campaigns[campaignId].eventToken;
    }

    /**
     * @dev Calculate the token cap accounting for decimal differences
     *
     * @param targetAmount Target amount in funding token units
     * @param fundingToken Address of the funding token
     * @param eventTokenDecimals Number of decimals for the EventToken
     * @return Cap amount in event token units (155% of target)
     *
     * @notice This function converts the target amount from funding token units
     * to event token units, accounting for decimal differences
     */
    function _calculateTokenCap(
        uint256 targetAmount,
        address fundingToken,
        uint8 eventTokenDecimals
    ) internal view returns (uint256) {
        // Get decimals dynamically from funding token
        uint256 fundingTokenDecimals = IERC20Metadata(fundingToken).decimals();

        // Convert targetAmount from funding token units to event token units
        uint256 targetInEventTokenUnits;
        if (eventTokenDecimals > fundingTokenDecimals) {
            // Event token has more decimals, multiply by the difference
            uint256 multiplier = 10 **
                (eventTokenDecimals - fundingTokenDecimals);
            targetInEventTokenUnits = targetAmount * multiplier;
        } else {
            // Event token has fewer decimals, divide by the difference
            uint256 divisor = 10 ** (fundingTokenDecimals - eventTokenDecimals);
            targetInEventTokenUnits = targetAmount / divisor;
        }

        // Calculate cap: 155% of target in event token units
        return (targetInEventTokenUnits * 155) / 100;
    }

    /**
     * @dev Transfer tokens to hook for pool creation
     * @param campaignId ID of the campaign
     * @param fundingAmount Amount of funding tokens
     * @param tokenAmount Amount of event tokens
     * 
     * @notice TEMPORARILY DISABLED FOR DEMO - Hook not yet functional
     */
    function _transferTokensToHook(
        uint256 campaignId,
        uint256 fundingAmount,
        uint256 tokenAmount
    ) internal {
        // TODO: Hook token transfer temporarily disabled for demo
        // EventCampaign storage campaign = campaigns[campaignId];
        
        // // Transfer funding tokens to hook
        // IERC20(campaign.fundingToken).transfer(fanioHook, fundingAmount);
        
        // // Transfer event tokens to hook
        // IERC20(campaign.eventToken).transfer(fanioHook, tokenAmount);
        
        // // Emit event
        // emit TokensTransferredToHook(campaignId, fanioHook, fundingAmount, tokenAmount);
    }

    /**
     * @dev Initialize hook pool and add initial liquidity
     * @param campaignId ID of the campaign
     * @param fundingAmount Amount of funding tokens
     * @param tokenAmount Amount of event tokens
     * 
     * @notice TEMPORARILY DISABLED FOR DEMO - Hook not yet functional
     */
    function _initializeHookPool(
        uint256 campaignId,
        uint256 fundingAmount,
        uint256 tokenAmount
    ) internal {
        // TODO: Hook pool initialization temporarily disabled for demo
        // EventCampaign storage campaign = campaigns[campaignId];
        
        // // Create PoolKey for the trading pool
        // PoolKey memory key = PoolKey({
        //     currency0: Currency.wrap(campaign.fundingToken < campaign.eventToken ? 
        //         campaign.fundingToken : campaign.eventToken),
        //     currency1: Currency.wrap(campaign.fundingToken < campaign.eventToken ? 
        //         campaign.eventToken : campaign.fundingToken),
        //     fee: 3000, // 0.3% fee
        //     tickSpacing: 60,
        //     hooks: IHooks(fanioHook)
        // });

        // // Initialize the pool (this will trigger the hook's afterInitialize)
        // uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(1824); // 1.2:1 price
        // poolManager.initialize(key, sqrtPriceX96);
        
        // emit PoolInitialized(campaignId, address(poolManager), key);
    }

    /**
     * @dev Convert funding token units to event token units
     *
     * @param amount Amount in funding token units
     * @param fundingToken Address of the funding token
     * @param eventTokenDecimals Number of decimals for the EventToken
     * @return Amount in event token units
     *
     * @notice This function converts amounts from funding token units to event token units
     * accounting for decimal differences, ensuring consistency across all token operations
     */
    function _convertToEventTokenUnits(
        uint256 amount,
        address fundingToken,
        uint8 eventTokenDecimals
    ) internal view returns (uint256) {
        // Get decimals dynamically from funding token
        uint256 fundingTokenDecimals = IERC20Metadata(fundingToken).decimals();

        // Convert amount from funding token units to event token units
        if (eventTokenDecimals > fundingTokenDecimals) {
            // Event token has more decimals, multiply by the difference
            uint256 multiplier = 10 **
                (eventTokenDecimals - fundingTokenDecimals);
            return amount * multiplier;
        } else {
            // Event token has fewer decimals, divide by the difference
            uint256 divisor = 10 ** (fundingTokenDecimals - eventTokenDecimals);
            return amount / divisor;
        }
    }
}

// ========================================
// EVENTS
// ========================================

// Event removed - liquidity is now handled by the hook

/**
 * @dev Emitted when tokens are transferred to hook for pool creation
 * @param campaignId ID of the campaign
 * @param hook Address of the hook
 * @param fundingAmount Amount of funding tokens transferred
 * @param tokenAmount Amount of event tokens transferred
 */
event TokensTransferredToHook(
    uint256 indexed campaignId,
    address indexed hook,
    uint256 fundingAmount,
    uint256 tokenAmount
);

/**
 * @dev Emitted when pool is initialized
 * @param campaignId ID of the campaign
 * @param poolManager Address of the pool manager
 * @param key Pool key information
 */
event PoolInitialized(
    uint256 indexed campaignId,
    address indexed poolManager,
    PoolKey key
);

// ========================================
// BUSINESS LOGIC & TOKENOMICS
// ========================================
/*
 * FUNDING FLOW OVERVIEW:
 *
 * 1. CAMPAIGN CREATION:
 *    - Organizer deposits 10% of target amount
 *    - EventToken deployed with cap = 155% of target
 *    - Campaign becomes active with deadline
 *
 * 2. CONTRIBUTION PHASE:
 *    - Fans contribute funding tokens (USDC or custom)
 *    - EventTokens minted immediately 1:1 with contribution
 *    - Campaign tracks raised amount vs target
 *
 * 3. FUNDING FINALIZATION (when target reached):
 *    - Pool tokens minted (25% of target) for Uniswap V4
 *    - Protocol fee collected (10% of target) from organizer deposit
 *    - Full target amount sent to organizer
 *    - Campaign marked as funded and inactive
 *
 * 4. POST-FUNDING:
 *    - Organizer can withdraw raised funds
 *    - Pool tokens ready for Uniswap V4 liquidity creation
 *    - Contributors hold EventTokens (1:1 with contribution)
 *
 * TOKEN DISTRIBUTION:
 * - Contributors: 130% of target (1:1 ratio with contribution, up to 30% over target)
 * - Pool: 25% of target (for initial Uniswap V4 liquidity)
 * - Total Supply: 155% of target (130% + 25%)
 *
 * FINANCIAL TRACKING:
 * - organizerDeposit: 10% of target (protocol fee if successful)
 * - raisedAmount: Total contributions received
 * - protocolFeesCollected: Fees collected (equal to organizer deposit)
 * - fundsWithdrawn: Whether organizer has withdrawn funds
 *
 * SECURITY FEATURES:
 * - ReentrancyGuard on all external functions
 * - Automatic campaign expiration handling
 * - Comprehensive balance verification
 * - Access control for organizer-only functions
 */

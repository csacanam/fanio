// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./EventToken.sol";

/**
 * @title FundingManager
 * @dev Minimal MVP for trustless crowdfunding campaigns
 */
contract FundingManager is ReentrancyGuard {
    // Default funding currency (USDC) - can be overridden per campaign
    IERC20 public immutable DEFAULT_FUNDING_TOKEN;

    // Campaign storage
    struct EventCampaign {
        address eventToken;
        address organizer;
        address fundingToken; // Custom funding token for this campaign
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 organizerDeposit; // Amount deposited by organizer
        uint256 deadline;
        bool isActive;
        bool isFunded;
    }

    mapping(uint256 => EventCampaign) public campaigns;
    mapping(address => mapping(uint256 => uint256)) public userContributions;
    uint256 public nextCampaignId;

    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed organizer,
        address eventToken,
        address fundingToken,
        uint256 targetAmount,
        uint256 organizerDeposit,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignFunded(uint256 indexed campaignId, uint256 totalRaised);
    event CampaignExpired(uint256 indexed campaignId, uint256 totalRaised);
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed organizer,
        uint256 amount
    );

    constructor(address defaultFundingToken) {
        DEFAULT_FUNDING_TOKEN = IERC20(defaultFundingToken);
    }

    /**
     * @dev Create a new funding campaign
     */
    function createCampaign(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 targetAmount,
        uint256 durationDays,
        address fundingToken // Custom funding token (use address(0) for default)
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

        // Calculate cap: 130% for contributors (1:1) + 25% extra for pool (1.2x price)
        uint256 cap = (targetAmount * 155) / 100;

        // Deploy EventToken
        EventToken eventToken = new EventToken(tokenName, tokenSymbol, cap);

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
            isFunded: false
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
     * @dev Contribute to a funding campaign
     */
    function contribute(
        uint256 campaignId,
        uint256 amount
    ) external nonReentrant {
        EventCampaign storage campaign = campaigns[campaignId];

        // Check and update campaign status before processing
        _checkCampaignStatus(campaignId);

        require(amount > 0, "Amount must be positive");
        require(!campaign.isFunded, "Campaign already funded");

        // Validate that contribution doesn't exceed funding target
        require(
            campaign.raisedAmount + amount <= campaign.targetAmount,
            "Contribution would exceed funding target"
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

        emit ContributionMade(campaignId, msg.sender, amount);

        // Check if funding target is reached
        if (campaign.raisedAmount >= campaign.targetAmount) {
            _finalizeFunding(campaignId);
        }
    }

    /**
     * @dev Finalize funding when target is reached
     */
    function _finalizeFunding(uint256 campaignId) internal {
        EventCampaign storage campaign = campaigns[campaignId];

        campaign.isFunded = true;
        campaign.isActive = false;

        emit CampaignFunded(campaignId, campaign.raisedAmount);

        // TODO: Create Uniswap V4 pool with automatic liquidity
    }

    /**
     * @dev Organizer withdraws funds after successful funding
     */
    function withdrawFunds(uint256 campaignId) external nonReentrant {
        EventCampaign storage campaign = campaigns[campaignId];
        require(campaign.organizer == msg.sender, "Not the organizer");
        require(campaign.isFunded, "Campaign not funded");

        // Organizer receives the full target amount
        uint256 organizerAmount = campaign.targetAmount;

        // Transfer tokens to organizer using campaign's funding token
        IERC20 campaignToken = IERC20(campaign.fundingToken);
        require(
            campaignToken.transfer(msg.sender, organizerAmount),
            "Transfer failed"
        );

        emit FundsWithdrawn(campaignId, msg.sender, organizerAmount);
    }

    /**
     * @dev Close an expired campaign that didn't reach its funding goal
     * @param campaignId The ID of the campaign to close
     */
    function closeExpiredCampaign(uint256 campaignId) external {
        EventCampaign storage campaign = campaigns[campaignId];
        require(campaign.isActive, "Campaign not active");
        require(
            block.timestamp >= campaign.deadline,
            "Campaign not expired yet"
        );
        require(!campaign.isFunded, "Campaign already funded");

        campaign.isActive = false;

        emit CampaignExpired(campaignId, campaign.raisedAmount);

        // TODO: Implement refund logic for contributors
    }

    /**
     * @dev Check and update campaign status based on current time
     * @param campaignId The ID of the campaign to check
     */
    function _checkCampaignStatus(uint256 campaignId) internal {
        EventCampaign storage campaign = campaigns[campaignId];
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
     * @param campaignId The ID of the campaign to query
     * @return isActive Whether the campaign is currently active
     * @return isExpired Whether the campaign has expired
     * @return isFunded Whether the campaign has been successfully funded
     * @return timeLeft Time remaining until deadline (0 if expired)
     * @return raisedAmount Total amount raised so far
     * @return targetAmount Funding goal amount
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
            uint256 targetAmount
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

        return (
            isActive,
            isExpired,
            isFunded,
            timeLeft,
            raisedAmount,
            targetAmount
        );
    }

    /**
     * @dev Get the funding token address for a specific campaign
     * @param campaignId The ID of the campaign to query
     * @return fundingToken The address of the funding token used by this campaign
     */
    function getCampaignFundingToken(
        uint256 campaignId
    ) external view returns (address fundingToken) {
        EventCampaign storage campaign = campaigns[campaignId];
        return campaign.fundingToken;
    }
}

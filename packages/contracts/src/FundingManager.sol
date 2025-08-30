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

    // Protocol wallet for collecting fees
    address public immutable PROTOCOL_WALLET;

    // Campaign storage
    struct EventCampaign {
        // 🏗️ CORE CAMPAIGN INFO
        address eventToken; // Address of the EventToken contract
        address organizer; // Campaign organizer address
        address fundingToken; // Custom funding token for this campaign
        uint256 targetAmount; // Funding goal amount
        uint256 organizerDeposit; // Amount deposited by organizer (10% of target)
        uint256 deadline; // Campaign end timestamp
        bool isActive; // Whether campaign is currently active
        bool isFunded; // Whether campaign reached funding target
        // 💰 ACCOUNTABILITY - Money tracking and financial state
        uint256 raisedAmount; // Total amount raised so far
        uint256 protocolFeesCollected; // Protocol fees collected (10% of target)
        bool fundsWithdrawn; // Whether organizer has withdrawn funds
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
        uint256 amount,
        uint256 tokensMinted
    );

    event CampaignFunded(uint256 indexed campaignId, uint256 totalRaised);
    event CampaignExpired(uint256 indexed campaignId, uint256 totalRaised);
    event TokensMinted(uint256 indexed campaignId, uint256 poolTokens);
    event ProtocolFeePaid(uint256 indexed campaignId, uint256 amount);
    event OrganizerFundsSent(
        uint256 indexed campaignId,
        address organizer,
        uint256 amount
    );
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed organizer,
        uint256 amount
    );

    constructor(address defaultFundingToken, address protocolWallet) {
        DEFAULT_FUNDING_TOKEN = IERC20(defaultFundingToken);
        PROTOCOL_WALLET = protocolWallet;
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

        // Deploy EventToken with FundingManager address
        EventToken eventToken = new EventToken(
            tokenName,
            tokenSymbol,
            cap,
            address(this)
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
            fundsWithdrawn: false,
            // 💰 Initialize accountability fields
            protocolFeesCollected: 0
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

        // Mint tokens immediately to contributor (1:1 ratio)
        EventToken eventToken = EventToken(campaign.eventToken);
        uint256 userTokens = amount; // 1:1 ratio with contribution
        eventToken.mint(msg.sender, userTokens);

        emit ContributionMade(campaignId, msg.sender, amount, userTokens);

        // Check if funding target is reached
        if (campaign.raisedAmount == campaign.targetAmount) {
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

        // 1. Mint pool tokens (25% of target for initial liquidity)
        EventToken eventToken = EventToken(campaign.eventToken);
        uint256 poolTokens = (campaign.targetAmount * 25) / 100;
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

        // TODO: Create Uniswap V4 pool with automatic liquidity
    }

    /**
     * @dev Organizer withdraws funds after successful funding
     */
    function withdrawFunds(uint256 campaignId) external nonReentrant {
        EventCampaign storage campaign = campaigns[campaignId];
        require(campaign.organizer == msg.sender, "Not the organizer");
        require(campaign.isFunded, "Campaign not funded");
        require(!campaign.fundsWithdrawn, "Funds already withdrawn");

        // Organizer receives the full target amount
        uint256 organizerAmount = campaign.targetAmount;

        // Transfer tokens to organizer using campaign's funding token
        IERC20 campaignToken = IERC20(campaign.fundingToken);
        require(
            campaignToken.transfer(msg.sender, organizerAmount),
            "Transfer failed"
        );

        // Update withdrawal tracking
        campaign.fundsWithdrawn = true;

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
     * @return organizerDeposit Amount deposited by organizer
     * @return fundsWithdrawn Whether organizer has withdrawn funds

     * @return fundingToken Address of the funding token used
     * @return protocolFeesCollected Protocol fees collected



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
            bool fundsWithdrawn,
            address fundingToken,
            uint256 protocolFeesCollected
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
        fundsWithdrawn = campaign.fundsWithdrawn;
        fundingToken = campaign.fundingToken;

        return (
            isActive,
            isExpired,
            isFunded,
            timeLeft,
            raisedAmount,
            targetAmount,
            organizerDeposit,
            fundsWithdrawn,
            fundingToken,
            campaign.protocolFeesCollected
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

    /**
     * @dev Verify campaign balance and accounting
     * @param campaignId The ID of the campaign to verify
     * @return isBalanced Whether the accounting is balanced
     * @return expectedBalance Expected balance based on accounting
     * @return actualBalance Actual balance in the contract
     * @return discrepancy Description of any discrepancy found
     */
    function verifyCampaignBalance(
        uint256 campaignId
    )
        external
        view
        returns (
            bool isBalanced,
            uint256 expectedBalance,
            uint256 actualBalance,
            string memory discrepancy
        )
    {
        EventCampaign storage campaign = campaigns[campaignId];

        // Calculate expected balance based on accounting
        expectedBalance =
            campaign.organizerDeposit +
            campaign.raisedAmount -
            campaign.protocolFeesCollected;

        // Get actual balance in the contract
        IERC20 campaignToken = IERC20(campaign.fundingToken);
        actualBalance = campaignToken.balanceOf(address(this));

        isBalanced = (expectedBalance == actualBalance);

        if (!isBalanced) {
            discrepancy = "Balance mismatch detected";
        }

        return (isBalanced, expectedBalance, actualBalance, discrepancy);
    }
}

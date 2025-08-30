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
    // Funding currency (USDC)
    IERC20 public immutable FUNDING_TOKEN;

    // Campaign storage
    struct EventCampaign {
        address eventToken;
        address organizer;
        uint256 targetAmount;
        uint256 raisedAmount;
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
        uint256 targetAmount,
        uint256 deadline
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    event CampaignFunded(uint256 indexed campaignId, uint256 totalRaised);
    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed organizer,
        uint256 amount
    );

    constructor(address fundingToken) {
        FUNDING_TOKEN = IERC20(fundingToken);
    }

    /**
     * @dev Create a new funding campaign
     */
    function createCampaign(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 targetAmount,
        uint256 durationDays
    ) external returns (uint256 campaignId) {
        require(targetAmount > 0, "Target amount must be positive");
        require(durationDays > 0, "Duration must be positive");

        // Calcular deposit requerido (10% de la meta)
        uint256 requiredDeposit = (targetAmount * 1000) / 10000; // 10%

        // Transferir USDC del organizador al contrato
        require(
            FUNDING_TOKEN.transferFrom(
                msg.sender,
                address(this),
                requiredDeposit
            ),
            "Deposit transfer failed"
        );

        campaignId = nextCampaignId++;
        uint256 deadline = block.timestamp + (durationDays * 1 days);

        // Calculate cap (1.3x target for contributors + liquidity)
        uint256 cap = (targetAmount * 130) / 100;

        // Deploy EventToken
        EventToken eventToken = new EventToken(tokenName, tokenSymbol, cap);

        // Create campaign
        campaigns[campaignId] = EventCampaign({
            eventToken: address(eventToken),
            organizer: msg.sender,
            targetAmount: targetAmount,
            raisedAmount: 0,
            deadline: deadline,
            isActive: true,
            isFunded: false
        });

        emit CampaignCreated(
            campaignId,
            msg.sender,
            address(eventToken),
            targetAmount,
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
        require(campaign.isActive, "Campaign not active");
        require(block.timestamp < campaign.deadline, "Campaign ended");
        require(amount > 0, "Amount must be positive");
        require(!campaign.isFunded, "Campaign already funded");

        // Transfer USDC from contributor
        require(
            FUNDING_TOKEN.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Registrar contribución
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

        // TODO: Crear Uniswap V4 pool con liquidez automática
    }

    /**
     * @dev Organizer withdraws funds after successful funding
     */
    function withdrawFunds(uint256 campaignId) external nonReentrant {
        EventCampaign storage campaign = campaigns[campaignId];
        require(campaign.organizer == msg.sender, "Not the organizer");
        require(campaign.isFunded, "Campaign not funded");

        // Organizador recibe la meta completa
        uint256 organizerAmount = campaign.targetAmount;

        require(
            FUNDING_TOKEN.transfer(msg.sender, organizerAmount),
            "Transfer failed"
        );

        emit FundsWithdrawn(campaignId, msg.sender, organizerAmount);
    }
}

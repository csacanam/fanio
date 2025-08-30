// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./EventToken.sol";

/**
 * @title FundingManager
 * @dev Manages trustless crowdfunding campaigns for live events using Uniswap v4
 */
contract FundingManager is ReentrancyGuard, Ownable {
    // Constants
    uint256 public constant PROTOCOL_FEE_BPS = 1000; // 10%
    uint256 public constant LIQUIDITY_PERCENTAGE = 3000; // 30% extra for liquidity
    uint256 public constant BASIS_POINTS = 10000;

    // Funding currency (USDC)
    IERC20 public immutable FUNDING_TOKEN;

    // Events storage
    struct EventCampaign {
        address eventToken;
        address organizer;
        uint256 targetAmount;
        uint256 raisedAmount;
        uint256 deadline;
        bool isActive;
        bool isFunded;
        bool isWithdrawn;
        string eventName;
        string eventDescription;
        uint256 organizerDeposit; // 10% de la meta
        bool depositPaid; // Si ya pagó el deposit
        bool isRefundable; // Si se pueden hacer refunds
    }

    mapping(uint256 => EventCampaign) public campaigns;
    mapping(address => uint256[]) public organizerCampaigns;
    mapping(address => mapping(uint256 => uint256)) public userContributions;

    uint256 public nextCampaignId;
    uint256 public totalProtocolFees;

    // Events
    event CampaignCreated(
        uint256 indexed campaignId,
        address indexed organizer,
        address eventToken,
        uint256 targetAmount,
        uint256 deadline,
        string eventName
    );

    event ContributionMade(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount,
        uint256 tokensReceived
    );

    event CampaignFunded(
        uint256 indexed campaignId,
        uint256 totalRaised,
        uint256 liquidityAmount,
        uint256 protocolFee
    );

    event FundsWithdrawn(
        uint256 indexed campaignId,
        address indexed organizer,
        uint256 amount
    );

    event RefundClaimed(
        uint256 indexed campaignId,
        address indexed contributor,
        uint256 amount
    );

    constructor(address fundingToken) Ownable(msg.sender) {
        FUNDING_TOKEN = IERC20(fundingToken);
    }

    /**
     * @dev Create a new funding campaign
     */
    function createCampaign(
        string memory eventName,
        string memory eventDescription,
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
            isFunded: false,
            isWithdrawn: false,
            eventName: eventName,
            eventDescription: eventDescription,
            organizerDeposit: requiredDeposit,
            depositPaid: true,
            isRefundable: false
        });

        organizerCampaigns[msg.sender].push(campaignId);

        emit CampaignCreated(
            campaignId,
            msg.sender,
            address(eventToken),
            targetAmount,
            deadline,
            eventName
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
        require(campaign.depositPaid, "Organizer must pay deposit first");

        // Transfer USDC from contributor
        require(
            FUNDING_TOKEN.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        // Solo registrar contribución, NO mintear tokens
        campaign.raisedAmount += amount;
        userContributions[msg.sender][campaignId] += amount;

        emit ContributionMade(campaignId, msg.sender, amount, 0); // 0 tokens por ahora

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

        uint256 totalRaised = campaign.raisedAmount;

        // Calculate protocol fee (10% del deposit del organizador)
        uint256 protocolFee = campaign.organizerDeposit; // Ya está en el contrato

        // Calculate liquidity requirement (30% extra de la meta)
        uint256 liquidityAmount = (campaign.targetAmount *
            LIQUIDITY_PERCENTAGE) / BASIS_POINTS;

        totalProtocolFees += protocolFee;

        emit CampaignFunded(
            campaignId,
            totalRaised,
            liquidityAmount,
            protocolFee
        );

        // TODO: Crear Uniswap V4 pool con liquidez automática
    }

    /**
     * @dev Mintear EventTokens para todos los contribuidores
     */
    function mintEventTokens(uint256 campaignId) external {
        EventCampaign storage campaign = campaigns[campaignId];
        require(campaign.isFunded, "Campaign not funded");
        require(
            msg.sender == campaign.organizer,
            "Only organizer can mint tokens"
        );

        EventToken eventToken = EventToken(campaign.eventToken);

        // Mintear tokens para cada contribuidor
        // Esta función se puede optimizar con un mapping de contribuidores
        // Por ahora es básica para el MVP
        for (uint256 i = 0; i < 1000; i++) {
            // Límite para evitar gas limit
            // TODO: Implementar lógica para mintear tokens a todos los contribuidores
            break; // Placeholder
        }
    }

    /**
     * @dev Organizer withdraws funds after successful funding
     */
    function withdrawFunds(uint256 campaignId) external nonReentrant {
        EventCampaign storage campaign = campaigns[campaignId];
        require(campaign.organizer == msg.sender, "Not the organizer");
        require(campaign.isFunded, "Campaign not funded");
        require(!campaign.isWithdrawn, "Already withdrawn");

        campaign.isWithdrawn = true;

        // Organizador recibe la meta completa
        uint256 organizerAmount = campaign.targetAmount;

        require(
            FUNDING_TOKEN.transfer(msg.sender, organizerAmount),
            "Transfer failed"
        );

        emit FundsWithdrawn(campaignId, msg.sender, organizerAmount);
    }

    /**
     * @dev Activar refunds si la campaña falla
     */
    function activateRefunds(uint256 campaignId) external {
        EventCampaign storage campaign = campaigns[campaignId];
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(!campaign.isFunded, "Campaign was not funded");
        require(
            campaign.organizer == msg.sender,
            "Only organizer can activate refunds"
        );
        require(!campaign.isRefundable, "Refunds already activated");

        campaign.isRefundable = true;
        campaign.isActive = false;
    }

    /**
     * @dev Contributors claim refund if campaign fails
     */
    function claimRefund(uint256 campaignId) external nonReentrant {
        EventCampaign storage campaign = campaigns[campaignId];
        require(campaign.isRefundable, "Refunds not activated");
        require(!campaign.isFunded, "Campaign was funded");

        uint256 contribution = userContributions[msg.sender][campaignId];
        require(contribution > 0, "No contribution found");

        userContributions[msg.sender][campaignId] = 0;

        // Refund USDC (no hay tokens que quemar aún)
        require(
            FUNDING_TOKEN.transfer(msg.sender, contribution),
            "Refund failed"
        );

        emit RefundClaimed(campaignId, msg.sender, contribution);
    }

    /**
     * @dev Organizador recupera deposit si la campaña falla
     */
    function recoverDeposit(uint256 campaignId) external nonReentrant {
        EventCampaign storage campaign = campaigns[campaignId];
        require(campaign.organizer == msg.sender, "Not the organizer");
        require(block.timestamp >= campaign.deadline, "Campaign still active");
        require(!campaign.isFunded, "Campaign was funded");
        require(campaign.isRefundable, "Refunds not activated");

        uint256 deposit = campaign.organizerDeposit;
        campaign.organizerDeposit = 0;

        require(FUNDING_TOKEN.transfer(msg.sender, deposit), "Transfer failed");

        emit FundsWithdrawn(campaignId, msg.sender, deposit);
    }

    /**
     * @dev Get campaign details
     */
    function getCampaign(
        uint256 campaignId
    )
        external
        view
        returns (
            address eventToken,
            address organizer,
            uint256 targetAmount,
            uint256 raisedAmount,
            uint256 deadline,
            bool isActive,
            bool isFunded,
            string memory eventName,
            string memory eventDescription
        )
    {
        EventCampaign storage campaign = campaigns[campaignId];
        return (
            campaign.eventToken,
            campaign.organizer,
            campaign.targetAmount,
            campaign.raisedAmount,
            campaign.deadline,
            campaign.isActive,
            campaign.isFunded,
            campaign.eventName,
            campaign.eventDescription
        );
    }

    /**
     * @dev Get campaigns by organizer
     */
    function getOrganizerCampaigns(
        address organizer
    ) external view returns (uint256[] memory) {
        return organizerCampaigns[organizer];
    }

    /**
     * @dev Get user contribution for a campaign
     */
    function getUserContribution(
        address user,
        uint256 campaignId
    ) external view returns (uint256) {
        return userContributions[user][campaignId];
    }

    /**
     * @dev Owner can withdraw protocol fees
     */
    function withdrawProtocolFees() external onlyOwner {
        uint256 amount = totalProtocolFees;
        totalProtocolFees = 0;

        require(FUNDING_TOKEN.transfer(owner(), amount), "Transfer failed");
    }
}

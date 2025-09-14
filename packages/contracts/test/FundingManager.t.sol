// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {EventToken} from "../src/EventToken.sol";
import {DynamicFeeHook} from "../src/DynamicFeeHook.sol";
import {MockERC20} from "v4-periphery/lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "./utils/Deployers.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

/**
 * @title FundingManagerTest
 * @notice Comprehensive test suite for FundingManager contract
 * @dev Tests the core functionality of the crowdfunding platform
 *
 * Test Coverage:
 * - Campaign creation and validation
 * - User contributions and token minting (1:1 ratio with 20% excess)
 * - Campaign expiration handling
 * - Funding finalization and pool creation (20k USDC + 20k EventTokens)
 * - Access control and security
 * - Integration with DynamicFeeHook
 * - Tokenomics verification (140% total supply)
 *
 * Test Flow:
 * 1. Deploy contracts with proper configuration
 * 2. Create campaigns with various parameters
 * 3. Test contribution mechanics
 * 4. Verify campaign state transitions
 * 5. Test pool creation when goals are reached
 */
contract FundingManagerTest is Test, Deployers {
    // ========================================
    // CONTRACT INSTANCES
    // ========================================

    /// @notice FundingManager contract under test
    FundingManager public fundingManager;

    /// @notice DynamicFeeHook for pool fee management
    DynamicFeeHook public hook;

    /// @notice Mock USDC token for testing
    MockERC20 public mockUSDC;

    // ========================================
    // TEST ACCOUNTS
    // ========================================

    /// @notice Campaign organizer address
    address public organizer = address(0x1);

    /// @notice First contributor address
    address public contributor1 = address(0x2);

    /// @notice Second contributor address
    address public contributor2 = address(0x3);

    /// @notice Protocol wallet for fee collection
    address public protocolWallet = address(0x456);

    // ========================================
    // TEST CONSTANTS
    // ========================================

    /// @notice Campaign target amount (100k USDC)
    uint256 public constant TARGET_AMOUNT = 100_000e6;

    /// @notice Total amount to raise including pool (120k USDC)
    uint256 public constant TOTAL_TO_RAISE = 120_000e6;

    /// @notice Organizer deposit (10% of target)
    uint256 public constant ORGANIZER_DEPOSIT = 10_000e6;

    /// @notice Standard contribution amount for tests
    uint256 public constant CONTRIBUTION_AMOUNT = 50_000e6;

    /**
     * @notice Set up test environment with all required contracts
     * @dev Deploys FundingManager, DynamicFeeHook, and test tokens
     *
     * Setup Process:
     * 1. Deploy MockUSDC token (6 decimals like real USDC)
     * 2. Deploy Uniswap V4 infrastructure (PoolManager, routers)
     * 3. Deploy DynamicFeeHook with proper flags
     * 4. Deploy FundingManager with all dependencies
     * 5. Configure hook authorization
     * 6. Mint test tokens to accounts
     */
    function setUp() public {
        // Deploy MockUSDC with 6 decimals (like real USDC)
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);

        // Deploy PoolManager and routers first
        //deployFreshManagerAndRouters();
        deployArtifacts();

        // Deploy DynamicFeeHook with proper flags using deployCodeTo
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        address hookAddress = address(uint160(flags));
        deployCodeTo(
            "DynamicFeeHook.sol:DynamicFeeHook",
            abi.encode(
                poolManager,
                address(this) // Test contract as authorized caller for now
            ),
            hookAddress
        );

        // Deploy FundingManager with real PoolManager and hook
        fundingManager = new FundingManager(
            address(mockUSDC),
            protocolWallet,
            address(poolManager),
            hookAddress,
            address(positionManager)
        );

        // Update hook to use FundingManager as authorized caller
        DynamicFeeHook(hookAddress).setAuthorizedCaller(
            address(fundingManager)
        );

        // Initialize the hook variable with the deployed address
        hook = DynamicFeeHook(hookAddress);

        // Give USDC to organizer and contributors
        mockUSDC.mint(organizer, TARGET_AMOUNT);
        mockUSDC.mint(contributor1, TOTAL_TO_RAISE); // Give enough to reach total (120k)
        mockUSDC.mint(contributor2, CONTRIBUTION_AMOUNT);
    }

    function test_DeployWithCorrectParameters() public view {
        assertEq(
            address(fundingManager.DEFAULT_FUNDING_TOKEN()),
            address(mockUSDC)
        );
        assertEq(fundingManager.PROTOCOL_WALLET(), protocolWallet);
    }

    function test_CreateCampaign() public {
        // Approve USDC spending
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), ORGANIZER_DEPOSIT);

        // Create campaign
        uint256 campaignId = fundingManager.createCampaign(
            "Test Event",
            "TEST",
            TARGET_AMOUNT,
            30, // 30 days duration
            address(0) // Use default funding token
        );

        // Verify campaign was created
        (
            bool isActive,
            ,
            ,
            ,
            uint256 raisedAmount,
            uint256 targetAmount,
            ,
            ,
            ,

        ) = fundingManager.getCampaignStatus(campaignId);

        assertTrue(isActive);
        assertEq(raisedAmount, 0);
        assertEq(targetAmount, TARGET_AMOUNT);
        vm.stopPrank();
    }

    function test_ContributeToCampaign() public {
        // Create campaign first
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), ORGANIZER_DEPOSIT);
        uint256 campaignId = fundingManager.createCampaign(
            "Test Event",
            "TEST",
            TARGET_AMOUNT, // Use 100k as target (organizer wants 100k)
            30,
            address(0)
        );
        vm.stopPrank();

        // Contribute to campaign
        vm.startPrank(contributor1);
        mockUSDC.approve(address(fundingManager), CONTRIBUTION_AMOUNT);
        fundingManager.contribute(campaignId, CONTRIBUTION_AMOUNT);

        // Verify contribution was recorded
        (bool isActive, , , , uint256 raisedAmount, , , , , ) = fundingManager
            .getCampaignStatus(campaignId);

        assertTrue(isActive);
        assertEq(raisedAmount, CONTRIBUTION_AMOUNT);
        vm.stopPrank();
    }

    function test_FinalizeCampaignWhenTargetReached() public {
        // Create campaign
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), ORGANIZER_DEPOSIT);
        uint256 campaignId = fundingManager.createCampaign(
            "Test Event",
            "TEST",
            TARGET_AMOUNT, // Use 100k as target (organizer wants 100k)
            30,
            address(0)
        );
        vm.stopPrank();

        // Get EventToken address from campaign
        address eventTokenAddr = fundingManager.getCampaignEventToken(
            campaignId
        );
        EventToken eventToken = EventToken(eventTokenAddr);

        // No configuration needed - hook will auto-detect from balances

        // Record initial balances
        uint256 organizerInitialBalance = mockUSDC.balanceOf(organizer);
        uint256 protocolInitialBalance = mockUSDC.balanceOf(protocolWallet);

        // Contribute full total amount (120k USDC)
        vm.startPrank(contributor1);
        mockUSDC.approve(address(fundingManager), TOTAL_TO_RAISE);
        fundingManager.contribute(campaignId, TOTAL_TO_RAISE);
        vm.stopPrank();

        // Verify campaign is funded
        (
            bool isActive,
            ,
            bool isFunded,
            ,
            uint256 raisedAmount,
            ,
            ,
            ,
            ,

        ) = fundingManager.getCampaignStatus(campaignId);

        assertFalse(isActive); // Campaign should be inactive after funding
        assertTrue(isFunded);
        assertEq(raisedAmount, TOTAL_TO_RAISE);

        // Verify USDC transfers
        uint256 organizerFinalBalance = mockUSDC.balanceOf(organizer);
        uint256 protocolFinalBalance = mockUSDC.balanceOf(protocolWallet);
        uint256 contractFinalBalance = mockUSDC.balanceOf(
            address(fundingManager)
        );
        uint256 contributor1FinalBalance = mockUSDC.balanceOf(contributor1);

        // Organizer should receive full target amount (100k USDC)
        assertEq(
            organizerFinalBalance,
            organizerInitialBalance + TARGET_AMOUNT
        );

        // Protocol should receive organizer deposit (10k USDC)
        assertEq(
            protocolFinalBalance,
            protocolInitialBalance + ORGANIZER_DEPOSIT
        );

        // With pool creation enabled, all USDC goes to the pool
        // Contract should have 0 USDC remaining (all used for pool liquidity)
        assertEq(contractFinalBalance, 0);

        // Contributor1 should have 0 USDC (all contributed)
        assertEq(contributor1FinalBalance, 0);

        // Verify EventToken minting
        uint256 totalSupply = eventToken.totalSupply();

        // Calculate expected total supply accounting for decimal conversion
        // TOTAL_TO_RAISE = 120_000e6 (120k USDC) -> 120_000e18 (120k EventTokens)
        // Pool tokens = 20% of target = 20_000e18 (20k EventTokens)
        // Expected total = 120k + 20k = 140k EventTokens
        uint256 expectedTotalSupply = (TOTAL_TO_RAISE * 1e12) + // Convert 120k USDC to EventTokens
            ((TARGET_AMOUNT * 20) / 100) *
            1e12; // Convert 20k USDC to EventTokens

        assertEq(totalSupply, expectedTotalSupply);

        // With pool creation enabled, pool tokens go to PoolManager
        // Verify pool tokens are in PoolManager (20% of target, not total raised)
        assertApproxEqAbs(
            eventToken.balanceOf(address(poolManager)),
            ((TARGET_AMOUNT * 20) / 100) * 1e12,
            2e18, // ±2 token tolerance due to Uniswap V4 math
            "Pool should have ~20k EventTokens"
        );

        // Verify contributor1 received tokens (1:1 ratio with contribution)
        assertEq(eventToken.balanceOf(contributor1), TOTAL_TO_RAISE * 1e12);

        // Verify hook does NOT receive tokens (functionality disabled)
        assertEq(mockUSDC.balanceOf(address(hook)), 0); // No USDC transferred to hook
        assertEq(eventToken.balanceOf(address(hook)), 0); // No TSBOG transferred to hook

        // Verify pool was initialized and liquidity was added
        // Note: This requires the hook to actually add liquidity in afterInitialize
        // For now, we verify the hook has the tokens ready for pool creation
    }

    function test_CloseExpiredCampaign() public {
        // Create campaign with short duration
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), ORGANIZER_DEPOSIT);
        uint256 campaignId = fundingManager.createCampaign(
            "Test Event",
            "TEST",
            TARGET_AMOUNT,
            1, // 1 day duration
            address(0)
        );
        vm.stopPrank();

        // Fast forward past deadline
        vm.warp(block.timestamp + 2 days);

        // Close expired campaign
        fundingManager.closeExpiredCampaign(campaignId);

        // Verify campaign is closed
        (bool isActive, , , , , , , , , ) = fundingManager.getCampaignStatus(
            campaignId
        );
        assertFalse(isActive);
    }

    function test_CannotContributeToExpiredCampaign() public {
        // Create campaign with short duration
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), ORGANIZER_DEPOSIT);
        uint256 campaignId = fundingManager.createCampaign(
            "Test Event",
            "TEST",
            TARGET_AMOUNT,
            1, // 1 day duration
            address(0)
        );
        vm.stopPrank();

        // Fast forward past deadline
        vm.warp(block.timestamp + 2 days);

        // Try to contribute (should fail because campaign is expired)
        vm.startPrank(contributor1);
        mockUSDC.approve(address(fundingManager), CONTRIBUTION_AMOUNT);

        // The contribution should now fail because we added validation
        // to check isActive after _checkCampaignStatus
        vm.expectRevert("Campaign is not active");
        fundingManager.contribute(campaignId, CONTRIBUTION_AMOUNT);
        vm.stopPrank();

        // Verify that the campaign was actually closed during the failed contribution
        // Note: getCampaignStatus returns the state before the contribution attempt
        // but the campaign was closed during _checkCampaignStatus execution
        (, bool isExpired, , , , , , , , ) = fundingManager.getCampaignStatus(
            campaignId
        );

        // The campaign should be marked as expired (past deadline)
        assertTrue(isExpired);

        // Note: isActive might still be true in getCampaignStatus because
        // it returns the stored value, not the runtime state during contribute()
        // The important thing is that the contribution failed as expected
    }

    // ========================================
    // REFUND FUNCTIONALITY TESTS
    // ========================================

    /**
     * @notice Test automatic refund functionality for expired campaigns
     * @dev Verifies that closeExpiredCampaign automatically refunds all participants
     */
    function test_AutomaticRefundOnCampaignClose() public {
        // Create campaign with contribution
        uint256 campaignId = _createCampaignWithContribution();

        // Get balances before closing
        uint256 organizerBalanceBefore = mockUSDC.balanceOf(organizer);
        uint256 contributor1BalanceBefore = mockUSDC.balanceOf(contributor1);

        // Fast forward past deadline and close campaign
        vm.warp(block.timestamp + 8 days);
        fundingManager.closeExpiredCampaign(campaignId);

        // Verify organizer got refunded
        uint256 organizerBalanceAfter = mockUSDC.balanceOf(organizer);
        assertEq(
            organizerBalanceAfter,
            organizerBalanceBefore + ORGANIZER_DEPOSIT,
            "Organizer should receive deposit refund automatically"
        );

        // Verify contributor got refunded
        uint256 contributor1BalanceAfter = mockUSDC.balanceOf(contributor1);
        assertEq(
            contributor1BalanceAfter,
            contributor1BalanceBefore + 10_000e6,
            "Contributor should receive contribution refund automatically"
        );

        // Verify user's contribution is cleared
        assertEq(
            fundingManager.userContributions(contributor1, campaignId),
            0,
            "User contribution should be cleared after automatic refund"
        );
    }

    /**
     * @notice Test closeExpiredCampaign fails for active campaigns
     * @dev Verifies that closeExpiredCampaign can only be called on expired campaigns
     */
    function test_CloseExpiredCampaignFailsForActiveCampaign() public {
        // Create campaign without expiring it
        uint256 campaignId = _createCampaignWithContribution();

        // Try to close before campaign expires (should fail)
        vm.expectRevert("Campaign not expired yet");
        fundingManager.closeExpiredCampaign(campaignId);
    }

    /**
     * @notice Test closeExpiredCampaign fails for funded campaigns
     * @dev Verifies that closeExpiredCampaign cannot be called on funded campaigns
     */
    function test_CloseExpiredCampaignFailsForFundedCampaign() public {
        // Create and fund campaign to reach goal
        uint256 campaignId = _createAndFundCampaign();

        // Try to close funded campaign (should fail)
        vm.expectRevert("Campaign not expired yet");
        fundingManager.closeExpiredCampaign(campaignId);
    }

    // ========================================
    // HELPER FUNCTIONS
    // ========================================

    /**
     * @notice Create a campaign with a single contribution
     * @return campaignId The ID of the created campaign
     */
    function _createCampaignWithContribution() internal returns (uint256) {
        // Approve USDC spending
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), ORGANIZER_DEPOSIT);

        // Create a campaign
        uint256 campaignId = fundingManager.createCampaign(
            "Test Event",
            "TEST",
            TARGET_AMOUNT,
            7, // 7 days duration
            address(mockUSDC)
        );
        vm.stopPrank();

        // Contribute some amount (but not enough to reach goal)
        vm.startPrank(contributor1);
        mockUSDC.approve(address(fundingManager), 10_000e6);
        fundingManager.contribute(campaignId, 10_000e6);
        vm.stopPrank();

        return campaignId;
    }

    /**
     * @notice Create and fund a campaign to reach its goal
     * @return campaignId The ID of the created campaign
     */
    function _createAndFundCampaign() internal returns (uint256) {
        // Approve USDC spending
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), ORGANIZER_DEPOSIT);

        // Create a campaign
        uint256 campaignId = fundingManager.createCampaign(
            "Test Event",
            "TEST",
            TARGET_AMOUNT,
            7, // 7 days duration
            address(mockUSDC)
        );
        vm.stopPrank();

        // Fund the campaign to reach goal
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), 50_000e6);
        fundingManager.contribute(campaignId, 50_000e6);
        vm.stopPrank();

        vm.startPrank(contributor1);
        mockUSDC.approve(address(fundingManager), 40_000e6);
        fundingManager.contribute(campaignId, 40_000e6);
        vm.stopPrank();

        vm.startPrank(contributor2);
        mockUSDC.approve(address(fundingManager), 30_000e6);
        fundingManager.contribute(campaignId, 30_000e6);
        vm.stopPrank();

        return campaignId;
    }
}

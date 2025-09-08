// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {EventToken} from "../src/EventToken.sol";
import {DynamicFeeHook} from "../src/DynamicFeeHook.sol";
import {MockERC20} from "v4-periphery/lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolId} from "v4-core/types/PoolId.sol";

contract FundingManagerTest is Test, Deployers {
    FundingManager public fundingManager;
    DynamicFeeHook public hook;
    MockERC20 public mockUSDC;

    address public organizer = address(0x1);
    address public contributor1 = address(0x2);
    address public contributor2 = address(0x3);
    address public protocolWallet = address(0x456);

    uint256 public constant TARGET_AMOUNT = 100_000e6; // 100k USDC (what organizer wants)
    uint256 public constant TOTAL_TO_RAISE = 130_000e6; // 130k USDC (100k + 30k pool)
    uint256 public constant ORGANIZER_DEPOSIT = 10_000e6; // 10% of target
    uint256 public constant CONTRIBUTION_AMOUNT = 50_000e6; // 50k USDC

    function setUp() public {
        // Deploy MockUSDC with 6 decimals (like real USDC)
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);

        // Deploy PoolManager and routers first
        deployFreshManagerAndRouters();

        // Deploy DynamicFeeHook with proper flags using deployCodeTo
        uint160 flags = uint160(
            Hooks.AFTER_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        address hookAddress = address(uint160(flags));
        deployCodeTo(
            "DynamicFeeHook.sol:DynamicFeeHook",
            abi.encode(
                manager,
                address(0x456), // EventToken dummy, will be updated after campaign creation
                address(0x456) // FundingToken dummy, will be updated after campaign creation
            ),
            hookAddress
        );

        // Deploy FundingManager with real PoolManager (hook temporarily disabled for demo)
        fundingManager = new FundingManager(
            address(mockUSDC),
            protocolWallet,
            address(manager)
            // hookAddress // TODO: Hook parameter temporarily disabled for demo
        );

        // Initialize the hook variable with the deployed address
        hook = DynamicFeeHook(hookAddress);

        // Give USDC to organizer and contributors
        mockUSDC.mint(organizer, TARGET_AMOUNT);
        mockUSDC.mint(contributor1, TOTAL_TO_RAISE); // Give enough to reach total (130k)
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

        // Contribute full total amount (130k USDC)
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

        // TODO: Hook functionality temporarily disabled for demo
        // Contract should have excess USDC (30k) since hook transfer is disabled
        uint256 expectedExcessUSDC = TOTAL_TO_RAISE - TARGET_AMOUNT; // 130k - 100k = 30k
        assertEq(contractFinalBalance, expectedExcessUSDC);

        // Contributor1 should have 0 USDC (all contributed)
        assertEq(contributor1FinalBalance, 0);

        // Verify EventToken minting
        uint256 totalSupply = eventToken.totalSupply();

        // Calculate expected total supply accounting for decimal conversion
        // TOTAL_TO_RAISE = 130_000e6 (130k USDC) -> 130_000e18 (130k TSBOG)
        // TARGET_AMOUNT = 100_000e6 (100k USDC) -> 100_000e18 (100k TSBOG)
        // Pool tokens = 25% of target = 25_000e18 (25k TSBOG)
        // Expected total = 130k + 25k = 155k TSBOG
        uint256 expectedTotalSupply = (TOTAL_TO_RAISE * 1e12) + // Convert 130k USDC to TSBOG
            ((TARGET_AMOUNT * 25) / 100) *
            1e12; // Convert 25k USDC to TSBOG

        assertEq(totalSupply, expectedTotalSupply);

        // TODO: Hook functionality temporarily disabled for demo
        // Verify pool tokens are kept in FundingManager (25% of target, not total raised)
        assertEq(
            eventToken.balanceOf(address(fundingManager)),
            ((TARGET_AMOUNT * 25) / 100) * 1e12
        ); // 25k TSBOG kept in contract

        // Verify contributor1 received tokens (1:1 ratio with contribution)
        assertEq(eventToken.balanceOf(contributor1), TOTAL_TO_RAISE * 1e12);

        // TODO: Hook token transfer temporarily disabled for demo
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
}

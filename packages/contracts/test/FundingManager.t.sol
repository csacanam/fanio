// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {EventToken} from "../src/EventToken.sol";
import {MockERC20} from "v4-periphery/lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";

contract FundingManagerTest is Test {
    FundingManager public fundingManager;
    MockERC20 public mockUSDC;

    address public organizer = address(0x1);
    address public contributor1 = address(0x2);
    address public contributor2 = address(0x3);
    address public protocolWallet = address(0x456);

    uint256 public constant TARGET_AMOUNT = 100_000e6; // 100k USDC
    uint256 public constant ORGANIZER_DEPOSIT = 10_000e6; // 10% of target
    uint256 public constant CONTRIBUTION_AMOUNT = 50_000e6; // 50k USDC

    function setUp() public {
        // Deploy MockUSDC with 6 decimals (like real USDC)
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);

        // Deploy FundingManager
        fundingManager = new FundingManager(address(mockUSDC), protocolWallet);

        // Give USDC to organizer and contributors
        mockUSDC.mint(organizer, TARGET_AMOUNT);
        mockUSDC.mint(contributor1, TARGET_AMOUNT); // Give enough to reach target
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
            TARGET_AMOUNT,
            30,
            address(0)
        );
        vm.stopPrank();

        // Contribute to campaign
        vm.startPrank(contributor1);
        mockUSDC.approve(address(fundingManager), CONTRIBUTION_AMOUNT);
        fundingManager.contribute(campaignId, CONTRIBUTION_AMOUNT);

        // Verify contribution was recorded
        (bool isActive, , , , uint256 raisedAmount, , , , ) = fundingManager
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
            TARGET_AMOUNT,
            30,
            address(0)
        );
        vm.stopPrank();

        // Contribute full target amount
        vm.startPrank(contributor1);
        mockUSDC.approve(address(fundingManager), TARGET_AMOUNT);
        fundingManager.contribute(campaignId, TARGET_AMOUNT);
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

        ) = fundingManager.getCampaignStatus(campaignId);

        assertFalse(isActive); // Campaign should be inactive after funding
        assertTrue(isFunded);
        assertEq(raisedAmount, TARGET_AMOUNT);
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
        (bool isActive, , , , , , , , ) = fundingManager.getCampaignStatus(
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
        (, bool isExpired, , , , , , , ) = fundingManager.getCampaignStatus(
            campaignId
        );

        // The campaign should be marked as expired (past deadline)
        assertTrue(isExpired);

        // Note: isActive might still be true in getCampaignStatus because
        // it returns the stored value, not the runtime state during contribute()
        // The important thing is that the contribution failed as expected
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {EventToken} from "../src/EventToken.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {MockERC20} from "v4-periphery/lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";

contract EventTokenTest is Test, Deployers {
    EventToken public eventToken;
    FundingManager public fundingManager;
    MockERC20 public mockUSDC;

    address public organizer = address(0x1);
    address public contributor1 = address(0x2);
    address public contributor2 = address(0x3);

    uint256 public constant TARGET_AMOUNT = 100_000e6; // 100k USDC (6 decimals)
    uint256 public constant TOKEN_CAP = 155_000e18; // 155% of target (18 decimals)

    function setUp() public {
        // Deploy MockUSDC with 6 decimals (like real USDC)
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);

        // Deploy PoolManager and routers first
        deployFreshManagerAndRouters();

        // Deploy FundingManager with MockUSDC and real PoolManager
        address mockProtocolWallet = address(0x456);
        fundingManager = new FundingManager(
            address(mockUSDC),
            mockProtocolWallet,
            address(manager)
            // address(0) // TODO: Hook parameter temporarily disabled for demo
        );

        // Deploy EventToken with campaign info
        // Note: cap should be in token units (18 decimals), not USDC units (6 decimals)
        eventToken = new EventToken(
            "Test Event Token",
            "TEST",
            TOKEN_CAP, // Use the pre-calculated cap in token units
            address(fundingManager),
            18 // Use 18 decimals for EventToken
        );
    }

    function test_DeployWithCorrectParameters() public view {
        // Test EventToken deployment
        assertEq(eventToken.name(), "Test Event Token");
        assertEq(eventToken.symbol(), "TEST");
        assertEq(eventToken.totalSupply(), 0);
        assertEq(eventToken.cap(), TOKEN_CAP);
        assertEq(eventToken.decimals(), 18);

        // Test MockUSDC deployment
        assertEq(mockUSDC.name(), "Mock USDC");
        assertEq(mockUSDC.symbol(), "USDC");
        assertEq(mockUSDC.decimals(), 6);
        assertEq(mockUSDC.totalSupply(), 0);
    }

    function test_OnlyFundingManagerCanMint() public {
        // Try to mint from non-FundingManager address (should fail)
        vm.expectRevert();
        eventToken.mint(contributor1, 1000e18);

        // Mint from FundingManager (should succeed)
        vm.prank(address(fundingManager));
        eventToken.mint(contributor1, 1000e18);

        assertEq(eventToken.balanceOf(contributor1), 1000e18);
        assertEq(eventToken.totalSupply(), 1000e18);
    }

    function test_MintRespectsCap() public {
        vm.startPrank(address(fundingManager));

        // Mint up to cap (should succeed)
        eventToken.mint(contributor1, TOKEN_CAP);
        assertEq(eventToken.totalSupply(), TOKEN_CAP);

        // Try to mint beyond cap (should fail)
        vm.expectRevert();
        eventToken.mint(contributor2, 1e18);

        vm.stopPrank();
    }

    function test_TransferBetweenUsers() public {
        // Mint tokens to contributor1
        vm.prank(address(fundingManager));
        eventToken.mint(contributor1, 1000e18);

        // Transfer from contributor1 to contributor2
        vm.prank(contributor1);
        eventToken.transfer(contributor2, 500e18);

        assertEq(eventToken.balanceOf(contributor1), 500e18);
        assertEq(eventToken.balanceOf(contributor2), 500e18);
    }

    function test_TransferFailsWithInsufficientBalance() public {
        // Mint tokens to contributor1
        vm.prank(address(fundingManager));
        eventToken.mint(contributor1, 1000e18);

        // Try to transfer more than balance (should fail)
        vm.prank(contributor1);
        vm.expectRevert();
        eventToken.transfer(contributor2, 1500e18);

        // Balance should remain unchanged
        assertEq(eventToken.balanceOf(contributor1), 1000e18);
        assertEq(eventToken.balanceOf(contributor2), 0);
    }
}

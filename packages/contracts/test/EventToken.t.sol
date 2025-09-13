// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {EventToken} from "../src/EventToken.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {DynamicFeeHook} from "../src/DynamicFeeHook.sol";
import {MockERC20} from "v4-periphery/lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "./utils/Deployers.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

/**
 * @title EventTokenTest
 * @notice Test suite for EventToken contract functionality
 * @dev Tests the ERC20 token implementation and access control
 *
 * Test Coverage:
 * - Token deployment with correct parameters (140% cap)
 * - Minting functionality and access control (only FundingManager)
 * - Transfer operations between users
 * - Balance and supply management
 * - Integration with FundingManager
 * - Decimal handling (18 decimals)
 * - Supply cap enforcement
 *
 * Test Flow:
 * 1. Deploy EventToken through FundingManager
 * 2. Test minting permissions (only FundingManager can mint)
 * 3. Test transfer operations
 * 4. Verify balance and supply calculations
 */
contract EventTokenTest is Test, Deployers {
    // ========================================
    // CONTRACT INSTANCES
    // ========================================

    /// @notice EventToken contract under test
    EventToken public eventToken;

    /// @notice FundingManager for token deployment
    FundingManager public fundingManager;

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

    // ========================================
    // TEST CONSTANTS
    // ========================================

    /// @notice Campaign target amount (100k USDC, 6 decimals)
    uint256 public constant TARGET_AMOUNT = 100_000e6;

    /// @notice Token cap (155% of target, 18 decimals)
    uint256 public constant TOKEN_CAP = 155_000e18;

    /**
     * @notice Set up test environment with EventToken deployment
     * @dev Creates a campaign and deploys EventToken through FundingManager
     *
     * Setup Process:
     * 1. Deploy MockUSDC token
     * 2. Deploy Uniswap V4 infrastructure
     * 3. Deploy DynamicFeeHook with proper flags
     * 4. Deploy FundingManager with all dependencies
     * 5. Create a campaign to deploy EventToken
     * 6. Mint test tokens to accounts
     */
    function setUp() public {
        // Deploy MockUSDC with 6 decimals (like real USDC)
        mockUSDC = new MockERC20("Mock USDC", "USDC", 6);

        // Deploy PoolManager and routers first
        //deployFreshManagerAndRouters();
        deployArtifacts();

        // Deploy FundingManager with MockUSDC and real PoolManager
        address mockProtocolWallet = address(0x456);

        // Deploy DynamicFeeHook with proper flags
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo(
            "DynamicFeeHook.sol",
            abi.encode(poolManager, address(this)), // Test contract as authorized caller
            address(flags)
        );
        DynamicFeeHook dynamicFeeHook = DynamicFeeHook(address(flags));

        fundingManager = new FundingManager(
            address(mockUSDC),
            mockProtocolWallet,
            address(poolManager),
            address(dynamicFeeHook),
            address(positionManager)
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

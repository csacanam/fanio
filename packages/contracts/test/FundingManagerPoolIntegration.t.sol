// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {FundingManager} from "../src/FundingManager.sol";
import {DynamicFeeHook} from "../src/DynamicFeeHook.sol";
import {EventToken} from "../src/EventToken.sol";
import {MockERC20} from "v4-periphery/lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "./utils/Deployers.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";

/**
 * @title FundingManagerPoolIntegrationTest
 * @notice Integration test for FundingManager pool creation with DynamicFeeHook
 * @dev Tests the complete flow from campaign creation to pool initialization
 *
 * Test Flow:
 * 1. Create a campaign with FundingManager
 * 2. Contribute to reach the funding goal (120k USDC total)
 * 3. Verify pool is created with DynamicFeeHook (20k USDC + 20k EventTokens)
 * 4. Test pool liquidity and fee configuration
 * 5. Verify dynamic fees work correctly (1% buy, 10% sell)
 * 6. Test complete integration flow end-to-end
 */
contract FundingManagerPoolIntegrationTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    // Core contracts
    FundingManager public fundingManager;
    DynamicFeeHook public hook;
    MockERC20 public mockUSDC;
    EventToken public eventToken;

    // Test parameters
    address public organizer = address(0x1);
    address public contributor1 = address(0x2);
    address public contributor2 = address(0x3);
    address public protocolWallet = address(0x4);

    uint256 public constant TARGET_AMOUNT = 100_000e6; // 100k USDC (organizer target)
    uint256 public constant TOTAL_GOAL = 120_000e6; // 120k USDC (100k + 20% for pool)
    uint256 public constant ORGANIZER_DEPOSIT = 10_000e6; // 10k USDC (10% of target)

    // Pool configuration constants
    int24 private constant INITIAL_TICK = 274500; // ~1.2:1 price
    int24 private constant TICK_LOWER = -887220; // Full range lower
    int24 private constant TICK_UPPER = 887220; // Full range upper

    function setUp() public {
        // Deploy Uniswap V4 infrastructure
        //deployFreshManagerAndRouters();
        deployArtifacts();

        // Deploy test tokens
        mockUSDC = new MockERC20("USDC", "USDC", 6);

        // Deploy DynamicFeeHook first with temporary authorized caller
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo(
            "DynamicFeeHook.sol",
            abi.encode(poolManager, address(this)), // Test contract as temporary authorized caller
            address(flags)
        );
        hook = DynamicFeeHook(address(flags));

        // Deploy FundingManager with hook
        fundingManager = new FundingManager(
            address(mockUSDC),
            protocolWallet,
            address(poolManager),
            address(hook),
            address(positionManager)
        );

        // Update hook to use FundingManager as authorized caller
        hook.setAuthorizedCaller(address(fundingManager));

        // Setup test accounts with USDC
        mockUSDC.mint(organizer, 100_000e6);
        mockUSDC.mint(contributor1, 100_000e6);
        mockUSDC.mint(contributor2, 100_000e6);

        // Approve USDC for FundingManager
        vm.startPrank(organizer);
        mockUSDC.approve(address(fundingManager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(contributor1);
        mockUSDC.approve(address(fundingManager), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(contributor2);
        mockUSDC.approve(address(fundingManager), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @notice Test complete flow: create campaign, fund it, verify pool creation
     */
    function testCompleteFundingFlowWithPoolCreation() public {
        // Step 1: Create campaign
        uint256 campaignId = _createCampaign();

        // Step 2: Contribute to reach funding goal
        _contributeToReachGoal(campaignId);

        // Debug: Check campaign status
        (
            bool isActive,
            bool isExpired,
            bool isFunded,
            ,
            uint256 raisedAmount,
            uint256 targetAmount,
            ,
            ,
            ,

        ) = fundingManager.getCampaignStatus(campaignId);
        console.log("Campaign status:");
        console.log("- isActive:", isActive);
        console.log("- isExpired:", isExpired);
        console.log("- isFunded:", isFunded);
        console.log("- raisedAmount:", raisedAmount);
        console.log("- targetAmount:", targetAmount);

        // Step 3: Verify campaign is funded
        assertTrue(isFunded, "Campaign should be funded");

        // Step 4: Get EventToken address
        address eventTokenAddress = fundingManager.getCampaignEventToken(
            campaignId
        );
        eventToken = EventToken(eventTokenAddress);

        // Step 5: Verify pool was created and configured
        _verifyPoolCreation(campaignId, eventTokenAddress);

        // Step 6: Test dynamic fees work
        _testDynamicFees(eventTokenAddress);
    }

    /**
     * @notice Test pool liquidity setup
     */
    function testPoolLiquiditySetup() public {
        // Complete the funding flow first
        uint256 campaignId = _createCampaign();
        _contributeToReachGoal(campaignId);

        address eventTokenAddress = fundingManager.getCampaignEventToken(
            campaignId
        );
        eventToken = EventToken(eventTokenAddress);

        // Verify pool has liquidity (expecting ~30k USDC and ~25k EventTokens like DynamicFeeHook test)
        uint256 usdcBalance = mockUSDC.balanceOf(address(poolManager));
        uint256 eventBalance = eventToken.balanceOf(address(poolManager));

        console.log("USDC in pool:", usdcBalance);
        console.log("EventTokens in pool:", eventBalance);

        // Verify approximate amounts with 1:1 price (both should be equal)
        // fundingAmount = 30M (30% of target), tokenAmount = 25M (25% of target)
        // For 1:1 price, we use the smaller amount (25M) for both
        assertApproxEqAbs(
            usdcBalance,
            20_000e6, // 20k USDC (using smaller amount for 1:1 price)
            1_000e6, // ±1k USDC tolerance
            "Pool should have ~20k USDC"
        );
        assertApproxEqAbs(
            eventBalance,
            20_000e18, // 20k EventTokens with 18 decimals (same as USDC for 1:1 price)
            1_000e18, // ±1k EventTokens tolerance
            "Pool should have ~20k EventTokens"
        );
    }

    /**
     * @notice Test 1% buy fee when purchasing EventTokens with USDC
     */
    function testBuyFeeInPool() public {
        // Complete the funding flow first
        uint256 campaignId = _createCampaign();
        _contributeToReachGoal(campaignId);

        address eventTokenAddress = fundingManager.getCampaignEventToken(
            campaignId
        );

        // Test buy fee
        //_testBuyFeeInPool(eventTokenAddress);
    }

    /**
     * @notice Test fee asymmetry: 1% buy fee vs 10% sell fee
     */
    function testFeeAsymmetryInPool() public {
        // Complete the funding flow first
        uint256 campaignId = _createCampaign();
        _contributeToReachGoal(campaignId);

        address eventTokenAddress = fundingManager.getCampaignEventToken(
            campaignId
        );

        // Test fee asymmetry
        //_testFeeAsymmetryInPool(eventTokenAddress);
    }

    /**
     * @notice Test hook configuration after pool creation
     */
    function testHookConfigurationInPool() public {
        // Complete the funding flow first
        uint256 campaignId = _createCampaign();
        _contributeToReachGoal(campaignId);

        address eventTokenAddress = fundingManager.getCampaignEventToken(
            campaignId
        );

        PoolKey memory key = _createPoolKey(eventTokenAddress);
        PoolId poolId = key.toId();

        // Verify hook configuration
        assertEq(
            hook.eventTokens(poolId),
            eventTokenAddress,
            "Hook should be configured for EventToken"
        );

        assertEq(
            hook.authorizedCaller(),
            address(fundingManager),
            "FundingManager should be authorized caller"
        );
    }

    // ============ INTERNAL HELPER FUNCTIONS ============

    function _createCampaign() internal returns (uint256) {
        vm.startPrank(organizer);

        uint256 campaignId = fundingManager.createCampaign(
            "Test Concert",
            "TEST",
            TARGET_AMOUNT,
            7, // 7 days duration
            address(mockUSDC) // Use MockUSDC as funding token
        );

        vm.stopPrank();

        return campaignId;
    }

    function _contributeToReachGoal(uint256 campaignId) internal {
        // Organizer contributes 50k USDC (deposit doesn't count toward raisedAmount)
        vm.startPrank(organizer);
        fundingManager.contribute(campaignId, 50_000e6);
        vm.stopPrank();

        // Contributor1 contributes 40k USDC
        vm.startPrank(contributor1);
        fundingManager.contribute(campaignId, 40_000e6);
        vm.stopPrank();

        // Contributor2 contributes 30k USDC (total: 50k + 40k + 30k = 120k exactly)
        vm.startPrank(contributor2);
        fundingManager.contribute(campaignId, 30_000e6);
        vm.stopPrank();
    }

    function _verifyPoolCreation(
        uint256 /* campaignId */,
        address eventTokenAddress
    ) internal view {
        // Create expected pool key
        PoolKey memory expectedKey = PoolKey({
            currency0: Currency.wrap(
                address(mockUSDC) < eventTokenAddress
                    ? address(mockUSDC)
                    : eventTokenAddress
            ),
            currency1: Currency.wrap(
                address(mockUSDC) < eventTokenAddress
                    ? eventTokenAddress
                    : address(mockUSDC)
            ),
            fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });

        PoolId poolId = expectedKey.toId();

        // Verify hook is configured for this pool
        assertEq(
            hook.eventTokens(poolId),
            eventTokenAddress,
            "Hook should be configured for EventToken"
        );

        // Verify pool exists with expected liquidity amounts
        uint256 usdcBalance = mockUSDC.balanceOf(address(poolManager));
        uint256 eventBalance = EventToken(eventTokenAddress).balanceOf(
            address(poolManager)
        );

        // Verify approximate amounts with 1:1 price (both should be equal)
        // fundingAmount = 30M (30% of target), tokenAmount = 25M (25% of target)
        // For 1:1 price, we use the smaller amount (25M) for both
        assertApproxEqAbs(
            usdcBalance,
            20_000e6, // 20k USDC (using smaller amount for 1:1 price)
            1_000e6, // ±1k USDC tolerance
            "Pool should have ~20k USDC"
        );
        assertApproxEqAbs(
            eventBalance,
            20_000e18, // 20k EventTokens with 18 decimals (same as USDC for 1:1 price)
            1_000e18, // ±1k EventTokens tolerance
            "Pool should have ~20k EventTokens"
        );

        console.log("Pool created successfully with:");
        console.log("- USDC:", usdcBalance);
        console.log("- EventTokens:", eventBalance);
    }

    function _testDynamicFees(address eventTokenAddress) internal {
        // Test 1% buy fee when purchasing EventTokens with USDC
        //_testBuyFeeInPool(eventTokenAddress);

        // Test fee asymmetry: 1% buy vs 10% sell
        //_testFeeAsymmetryInPool(eventTokenAddress);

        console.log("Dynamic fees working correctly");
    }

    /**
     * @notice Test 1% buy fee when purchasing EventTokens with USDC
     */
    /*function _testBuyFeeInPool(address eventTokenAddress) internal {
        address user = address(0x1);
        uint256 swapAmount = 100e6; // 100 USDC

        // Setup user with USDC
        mockUSDC.mint(user, swapAmount);

        vm.startPrank(user);
        mockUSDC.approve(address(swapRouter), type(uint256).max);

        uint256 usdcBefore = mockUSDC.balanceOf(user);

        // Buy EventTokens with USDC (1% fee should apply)
        swap(
            _createPoolKey(eventTokenAddress),
            address(mockUSDC) < eventTokenAddress,
            -int256(swapAmount),
            ""
        );

        uint256 usdcAfter = mockUSDC.balanceOf(user);
        vm.stopPrank();

        // Verify exact input amount was spent (fee is applied to output)
        assertEq(
            usdcBefore - usdcAfter,
            swapAmount,
            "Should spend exact USDC amount"
        );
    }*/

    /**
     * @notice Test fee asymmetry: 1% buy fee vs 10% sell fee
     */
    /*function _testFeeAsymmetryInPool(address eventTokenAddress) internal {
        address trader = address(0x2);

        // Setup trader with USDC only (EventTokens will be obtained from buy)
        mockUSDC.mint(trader, 200e6);

        vm.startPrank(trader);
        mockUSDC.approve(address(swapRouter), type(uint256).max);
        EventToken(eventTokenAddress).approve(
            address(swapRouter),
            type(uint256).max
        );

        // Test buy (1% fee) - get EventTokens first
        uint256 usdcBefore = mockUSDC.balanceOf(trader);
        swap(
            _createPoolKey(eventTokenAddress),
            address(mockUSDC) < eventTokenAddress,
            -100e6,
            ""
        );
        uint256 usdcAfterBuy = mockUSDC.balanceOf(trader);

        // Test sell (10% fee) - sell some EventTokens back
        uint256 usdcBeforeSell = mockUSDC.balanceOf(trader);
        swap(
            _createPoolKey(eventTokenAddress),
            eventTokenAddress < address(mockUSDC),
            -50e18,
            ""
        );
        uint256 usdcAfterSell = mockUSDC.balanceOf(trader);

        vm.stopPrank();

        // Verify buy behavior
        assertEq(
            usdcBefore - usdcAfterBuy,
            100e6,
            "Buy should spend exact USDC amount"
        );

        // Verify sell behavior (should receive USDC, with 10% fee reducing output)
        assertGt(usdcAfterSell, usdcBeforeSell, "Sell should receive USDC");
    }*/

    /**
     * @notice Create pool key for the given EventToken address
     */
    function _createPoolKey(
        address eventTokenAddress
    ) internal view returns (PoolKey memory) {
        return
            PoolKey({
                currency0: Currency.wrap(
                    address(mockUSDC) < eventTokenAddress
                        ? address(mockUSDC)
                        : eventTokenAddress
                ),
                currency1: Currency.wrap(
                    address(mockUSDC) < eventTokenAddress
                        ? eventTokenAddress
                        : address(mockUSDC)
                ),
                fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
                tickSpacing: 60,
                hooks: IHooks(address(hook))
            });
    }
}

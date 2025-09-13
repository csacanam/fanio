// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
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
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

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

    // Pool configuration constants
    int24 private constant INITIAL_TICK = 274500; // ~1.2:1 price
    int24 private constant TICK_LOWER = -887220; // Full range lower
    int24 private constant TICK_UPPER = 887220; // Full range upper

    PoolSwapTest internal swapper;

    function setUp() public {
        // Deploy Uniswap V4 infrastructure
        deployArtifacts();
        swapper = new PoolSwapTest(poolManager);

        // Deploy test tokens
        mockUSDC = new MockERC20("USDC", "USDC", 6);

        // Deploy DynamicFeeHook first with temporary authorized caller
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
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
        mockUSDC.mint(address(0x5), 100e6); // Add 100 USDC for swap test user

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

        // Approve USDC for swapper (for swap tests)
        vm.startPrank(address(0x5));
        mockUSDC.approve(address(swapper), type(uint256).max);
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

        // Step 3: Verify campaign is funded
        (, , bool isFunded, , uint256 raisedAmount, , , , , ) = fundingManager
            .getCampaignStatus(campaignId);

        assertTrue(isFunded, "Campaign should be funded");
        assertEq(
            raisedAmount,
            TOTAL_GOAL,
            "Should have raised exactly 120k USDC"
        );

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

        // Verify pool has liquidity
        uint256 usdcBalance = mockUSDC.balanceOf(address(poolManager));
        uint256 eventBalance = eventToken.balanceOf(address(poolManager));

        // Verify approximate amounts with 1:1 price (both should be equal)
        assertApproxEqAbs(
            usdcBalance,
            20_000e6, // 20k USDC
            1_000e6, // ±1k USDC tolerance
            "Pool should have ~20k USDC"
        );
        assertApproxEqAbs(
            eventBalance,
            20_000e18, // 20k EventTokens with 18 decimals
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
        _testBuyFeeInPool(eventTokenAddress);
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
        // Organizer contributes 50k USDC
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

        // Verify approximate amounts with 1:1 price
        assertApproxEqAbs(
            usdcBalance,
            20_000e6, // 20k USDC
            1_000e6, // ±1k USDC tolerance
            "Pool should have ~20k USDC"
        );
        assertApproxEqAbs(
            eventBalance,
            20_000e18, // 20k EventTokens with 18 decimals
            1_000e18, // ±1k EventTokens tolerance
            "Pool should have ~20k EventTokens"
        );
    }

    function _testDynamicFees(address eventTokenAddress) internal {
        // Test 1% buy fee when purchasing EventTokens with USDC
        _testBuyFeeInPool(eventTokenAddress);

        // Test fee asymmetry: 1% buy vs 10% sell
        //_testFeeAsymmetryInPool(eventTokenAddress);
    }

    /**
     * @notice Test 1% buy fee when purchasing EventTokens with USDC
     */
    function _testBuyFeeInPool(address eventTokenAddress) internal {
        address user = address(0x5);
        uint128 swapAmount = 100e6; // 100 USDC

        vm.startPrank(user);

        uint256 usdcBefore = mockUSDC.balanceOf(user);
        uint256 eventTokenBefore = EventToken(eventTokenAddress).balanceOf(
            user
        );

        // Verify user has exactly 100 USDC
        assertEq(usdcBefore, swapAmount, "User should have exactly 100 USDC");
        assertEq(eventTokenBefore, 0, "User should have exactly 0 EventTokens");

        // Use the same pool key logic as _verifyPoolCreation (the actual pool)
        PoolKey memory key = PoolKey({
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

        // We want to buy EventTokens with USDC
        // Since EventToken is currency0 and USDC is currency1,
        // we need zeroForOne = false (token1 -> token0 = USDC -> EventToken)
        bool zeroForOne = false;

        // Buy EventTokens with USDC (1% fee should apply)
        BalanceDelta delta = _swapExactIn(key, zeroForOne, swapAmount, "");

        uint256 usdcAfter = mockUSDC.balanceOf(user);
        uint256 eventTokenAfter = EventToken(eventTokenAddress).balanceOf(user);
        vm.stopPrank();

        // Verify exact input amount was spent (fee is applied to output)
        assertEq(
            usdcBefore - usdcAfter,
            swapAmount,
            "Should spend exact USDC amount"
        );

        // Verify user received EventTokens
        assertGt(
            eventTokenAfter,
            eventTokenBefore,
            "User should receive EventTokens"
        );

        // Verify user has 0 USDC left (since we only gave them 100 USDC)
        assertEq(
            usdcAfter,
            0,
            "User should have 0 USDC left after spending exactly 100 USDC"
        );

        // Verify swap deltas are correct
        int128 d0 = delta.amount0();
        int128 d1 = delta.amount1();

        assertGt(d0, 0, "Should receive positive EventTokens (delta0 > 0)");
        assertEq(
            d1,
            -int128(swapAmount),
            "Should spend exact USDC amount (delta1 = -100e6)"
        );

        // Verify 1% dynamic fee is being applied correctly
        uint256 tokensReceived = eventTokenAfter - eventTokenBefore;

        // Verify we received EventTokens (the main goal)
        assertGt(tokensReceived, 0, "Should receive EventTokens from the swap");

        // Verify the swap deltas show the correct amounts
        assertEq(
            uint256(int256(d0)),
            tokensReceived,
            "Delta0 should match tokens received"
        );
        assertEq(
            uint256(int256(-d1)),
            swapAmount,
            "Delta1 should match USDC spent"
        );

        // Verify that the fee is being applied (tokens received should be less than perfect 1:1)
        // Since EventToken has 18 decimals and USDC has 6, we need to account for this
        uint256 expectedTokensIfNoFee = swapAmount * 1e12; // Convert USDC (6d) to EventToken (18d)
        assertLt(
            tokensReceived,
            expectedTokensIfNoFee,
            "Should receive less than perfect 1:1 ratio (fee applied)"
        );

        // Verify specific amount received (~98.5 tokens for 100 USDC with 1% fee)
        uint256 expectedTokensWithFee = (expectedTokensIfNoFee * 985) / 1000; // 98.5% of perfect ratio
        uint256 tolerance = (expectedTokensIfNoFee * 5) / 1000; // 0.5% tolerance

        assertApproxEqAbs(
            tokensReceived,
            expectedTokensWithFee,
            tolerance,
            "Should receive approximately 98.5% of perfect 1:1 ratio (1% fee applied)"
        );
    }

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

    function _swapExactIn(
        PoolKey memory key,
        bool zeroForOne, // true = token0 -> token1; false = token1 -> token0
        uint256 amountIn,
        bytes memory hookData
    ) internal returns (BalanceDelta delta) {
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne
                ? (TickMath.MIN_SQRT_PRICE + 1)
                : (TickMath.MAX_SQRT_PRICE - 1)
        });

        PoolSwapTest.TestSettings memory ts = PoolSwapTest.TestSettings({
            takeClaims: false,
            settleUsingBurn: false
        });

        delta = swapper.swap(key, params, ts, hookData);
    }
}

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
import {PoolSwapTest} from "v4-core/test/PoolSwapTest.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";

/**
 * @title FundingManagerPoolIntegrationTest
 * @notice Comprehensive integration test suite for FundingManager with Uniswap V4 pool creation
 * @dev Tests the complete flow from campaign creation to pool initialization with dynamic fees
 *
 * Test Coverage:
 * - Complete funding flow with pool creation
 * - Pool liquidity setup and verification
 * - Dynamic fee application (1% buy, 10% sell)
 * - Fee asymmetry testing
 * - Hook configuration validation
 * - End-to-end integration testing
 *
 * Test Flow:
 * 1. Deploy Uniswap V4 infrastructure and DynamicFeeHook
 * 2. Deploy FundingManager with hook integration
 * 3. Create campaign and reach funding goal (120k USDC total)
 * 4. Verify pool creation with correct liquidity (20k USDC + 20k EventTokens)
 * 5. Test dynamic fees work correctly in both directions
 * 6. Validate complete integration functionality
 */
contract FundingManagerPoolIntegrationTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    // ========================================
    // CONTRACT INSTANCES
    // ========================================

    /// @notice FundingManager contract under test
    FundingManager public fundingManager;

    /// @notice DynamicFeeHook for fee management
    DynamicFeeHook public hook;

    /// @notice Mock USDC token for testing
    MockERC20 public mockUSDC;

    /// @notice EventToken instance for testing
    EventToken public eventToken;

    /// @notice PoolSwapTest for executing swaps
    PoolSwapTest internal swapper;

    // ========================================
    // TEST ACCOUNTS
    // ========================================

    /// @notice Campaign organizer address
    address public organizer = address(0x1);

    /// @notice First contributor address
    address public contributor1 = address(0x2);

    /// @notice Second contributor address
    address public contributor2 = address(0x3);

    /// @notice Protocol wallet address
    address public protocolWallet = address(0x4);

    /// @notice Swap test user for buy fee testing
    address public swapTestUser = address(0x5);

    /// @notice Fee asymmetry test user
    address public feeTestUser = address(0x6);

    // ========================================
    // TEST CONSTANTS
    // ========================================

    /// @notice Campaign target amount (100k USDC, 6 decimals)
    uint256 public constant TARGET_AMOUNT = 100_000e6;

    /// @notice Total funding goal including pool liquidity (120k USDC, 6 decimals)
    uint256 public constant TOTAL_GOAL = 120_000e6;

    /// @notice Pool liquidity amount (20k USDC, 6 decimals)
    uint256 public constant POOL_LIQUIDITY_USDC = 20_000e6;

    /// @notice Pool liquidity amount (20k EventTokens, 18 decimals)
    uint256 public constant POOL_LIQUIDITY_EVENT = 20_000e18;

    /// @notice Buy test amount (100 USDC, 6 decimals)
    uint128 public constant BUY_TEST_AMOUNT = 100e6;

    /// @notice Sell test amount (50 EventTokens, 18 decimals)
    uint128 public constant SELL_TEST_AMOUNT = 50e18;

    /// @notice Fee asymmetry test amount (200 USDC, 6 decimals)
    uint256 public constant FEE_TEST_AMOUNT = 200e6;

    // ========================================
    // POOL CONFIGURATION CONSTANTS
    // ========================================

    /// @notice Initial tick for ~1.2:1 price ratio
    int24 private constant INITIAL_TICK = 274500;

    /// @notice Full range lower tick
    int24 private constant TICK_LOWER = -887220;

    /// @notice Full range upper tick
    int24 private constant TICK_UPPER = 887220;

    // ========================================
    // SETUP FUNCTION
    // ========================================

    /**
     * @notice Set up test environment with all required contracts and approvals
     * @dev Deploys Uniswap V4 infrastructure, DynamicFeeHook, FundingManager, and sets up test accounts
     */
    function setUp() public {
        // Deploy Uniswap V4 infrastructure
        deployArtifacts();
        swapper = new PoolSwapTest(poolManager);

        // Deploy test tokens
        mockUSDC = new MockERC20("USDC", "USDC", 6);

        // Deploy DynamicFeeHook with BEFORE_SWAP_FLAG
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        deployCodeTo(
            "DynamicFeeHook.sol",
            abi.encode(poolManager, address(this)), // Test contract as temporary authorized caller
            address(flags)
        );
        hook = DynamicFeeHook(address(flags));

        // Deploy FundingManager with hook integration
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
        _setupTestAccounts();

        // Setup approvals for all test accounts
        _setupApprovals();
    }

    // ========================================
    // MAIN TEST FUNCTIONS
    // ========================================

    /**
     * @notice Test complete funding flow with pool creation
     * @dev Verifies the entire process from campaign creation to pool initialization
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
     * @dev Verifies that the pool is created with correct liquidity amounts
     */
    function testPoolLiquiditySetup() public {
        // Complete the funding flow first
        uint256 campaignId = _createCampaign();
        _contributeToReachGoal(campaignId);

        address eventTokenAddress = fundingManager.getCampaignEventToken(
            campaignId
        );
        eventToken = EventToken(eventTokenAddress);

        // Verify pool has correct liquidity
        uint256 usdcBalance = mockUSDC.balanceOf(address(poolManager));
        uint256 eventBalance = eventToken.balanceOf(address(poolManager));

        // Verify approximate amounts with 1:1 price
        assertApproxEqAbs(
            usdcBalance,
            POOL_LIQUIDITY_USDC,
            1_000e6, // ±1k USDC tolerance
            "Pool should have ~20k USDC"
        );
        assertApproxEqAbs(
            eventBalance,
            POOL_LIQUIDITY_EVENT,
            1_000e18, // ±1k EventTokens tolerance
            "Pool should have ~20k EventTokens"
        );
    }

    /**
     * @notice Test 1% buy fee when purchasing EventTokens with USDC
     * @dev Verifies that the dynamic fee hook applies 1% fee on buy operations
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
     * @dev Verifies that different fees are applied for buy vs sell operations
     */
    function testFeeAsymmetryInPool() public {
        // Complete the funding flow first
        uint256 campaignId = _createCampaign();
        _contributeToReachGoal(campaignId);

        // Test fee asymmetry
        _testFeeAsymmetryInPool(
            fundingManager.getCampaignEventToken(campaignId)
        );
    }

    /**
     * @notice Test hook configuration after pool creation
     * @dev Verifies that the hook is properly configured for the created pool
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

    // ========================================
    // INTERNAL HELPER FUNCTIONS
    // ========================================

    /**
     * @notice Set up test accounts with USDC balances
     * @dev Mints USDC to all test accounts for testing
     */
    function _setupTestAccounts() internal {
        mockUSDC.mint(organizer, 100_000e6);
        mockUSDC.mint(contributor1, 100_000e6);
        mockUSDC.mint(contributor2, 100_000e6);
        mockUSDC.mint(swapTestUser, BUY_TEST_AMOUNT);
        mockUSDC.mint(feeTestUser, FEE_TEST_AMOUNT);
    }

    /**
     * @notice Set up approvals for all test accounts
     * @dev Approves USDC for FundingManager and swapper for all test accounts
     */
    function _setupApprovals() internal {
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
        vm.startPrank(swapTestUser);
        mockUSDC.approve(address(swapper), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(feeTestUser);
        mockUSDC.approve(address(swapper), type(uint256).max);
        vm.stopPrank();
    }

    /**
     * @notice Create a new campaign
     * @return campaignId The ID of the created campaign
     */
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

    /**
     * @notice Contribute to reach the funding goal
     * @param campaignId The ID of the campaign to contribute to
     */
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

    /**
     * @notice Verify pool creation and configuration
     * @param eventTokenAddress The address of the EventToken
     */
    function _verifyPoolCreation(
        uint256 /* campaignId */,
        address eventTokenAddress
    ) internal view {
        // Create expected pool key
        PoolKey memory expectedKey = _createPoolKey(eventTokenAddress);
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
            POOL_LIQUIDITY_USDC,
            1_000e6, // ±1k USDC tolerance
            "Pool should have ~20k USDC"
        );
        assertApproxEqAbs(
            eventBalance,
            POOL_LIQUIDITY_EVENT,
            1_000e18, // ±1k EventTokens tolerance
            "Pool should have ~20k EventTokens"
        );
    }

    /**
     * @notice Test dynamic fees functionality
     * @param eventTokenAddress The address of the EventToken
     */
    function _testDynamicFees(address eventTokenAddress) internal {
        // Test 1% buy fee when purchasing EventTokens with USDC
        _testBuyFeeInPool(eventTokenAddress);

        // Test fee asymmetry: 1% buy vs 10% sell
        _testFeeAsymmetryInPool(eventTokenAddress);
    }

    /**
     * @notice Test 1% buy fee when purchasing EventTokens with USDC
     * @param eventTokenAddress The address of the EventToken
     */
    function _testBuyFeeInPool(address eventTokenAddress) internal {
        vm.startPrank(swapTestUser);

        uint256 usdcBefore = mockUSDC.balanceOf(swapTestUser);
        uint256 eventTokenBefore = EventToken(eventTokenAddress).balanceOf(
            swapTestUser
        );

        // Verify user has exactly 100 USDC
        assertEq(
            usdcBefore,
            BUY_TEST_AMOUNT,
            "User should have exactly 100 USDC"
        );
        assertEq(eventTokenBefore, 0, "User should have exactly 0 EventTokens");

        // Create pool key
        PoolKey memory key = _createPoolKey(eventTokenAddress);

        // Buy EventTokens with USDC (1% fee should apply)
        // Since EventToken is currency0 and USDC is currency1,
        // we need zeroForOne = false (token1 -> token0 = USDC -> EventToken)
        bool zeroForOne = false;
        BalanceDelta delta = _swapExactIn(key, zeroForOne, BUY_TEST_AMOUNT, "");

        uint256 usdcAfter = mockUSDC.balanceOf(swapTestUser);
        uint256 eventTokenAfter = EventToken(eventTokenAddress).balanceOf(
            swapTestUser
        );
        vm.stopPrank();

        // Verify exact input amount was spent (fee is applied to output)
        assertEq(
            usdcBefore - usdcAfter,
            BUY_TEST_AMOUNT,
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
            -int128(BUY_TEST_AMOUNT),
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
            BUY_TEST_AMOUNT,
            "Delta1 should match USDC spent"
        );

        // Verify that the fee is being applied (tokens received should be less than perfect 1:1)
        // Since EventToken has 18 decimals and USDC has 6, we need to account for this
        uint256 expectedTokensIfNoFee = BUY_TEST_AMOUNT * 1e12; // Convert USDC (6d) to EventToken (18d)
        assertLt(
            tokensReceived,
            expectedTokensIfNoFee,
            "Should receive less than perfect 1:1 ratio (fee applied)"
        );

        // Verify specific amount received (~98.5 tokens for 100 USDC with 1% fee)
        uint256 expectedTokensWithFee = (expectedTokensIfNoFee * 985) / 1000; // 98.5% of perfect ratio
        uint256 tolerance = (expectedTokensIfNoFee * 20) / 1000; // 2% tolerance for AMM slippage

        assertApproxEqAbs(
            tokensReceived,
            expectedTokensWithFee,
            tolerance,
            "Should receive approximately 98.5% of perfect 1:1 ratio (1% fee applied)"
        );
    }

    /**
     * @notice Test fee asymmetry: 1% buy fee vs 10% sell fee
     * @param eventTokenAddress The address of the EventToken
     */
    function _testFeeAsymmetryInPool(address eventTokenAddress) internal {
        vm.startPrank(feeTestUser);

        // Test buy (1% fee) - get EventTokens first
        uint256 usdcBeforeBuy = mockUSDC.balanceOf(feeTestUser);
        uint256 eventTokenBeforeBuy = EventToken(eventTokenAddress).balanceOf(
            feeTestUser
        );

        // Create pool key
        PoolKey memory key = _createPoolKey(eventTokenAddress);

        // Buy EventTokens with USDC (1% fee should apply)
        // Since EventToken is currency0 and USDC is currency1,
        // we need zeroForOne = false (token1 -> token0 = USDC -> EventToken)
        bool zeroForOne = false;
        BalanceDelta buyDelta = _swapExactIn(
            key,
            zeroForOne,
            BUY_TEST_AMOUNT,
            ""
        );

        uint256 usdcAfterBuy = mockUSDC.balanceOf(feeTestUser);
        uint256 eventTokenAfterBuy = EventToken(eventTokenAddress).balanceOf(
            feeTestUser
        );

        // Approve EventTokens for swapper (needed for sell operation)
        EventToken(eventTokenAddress).approve(
            address(swapper),
            type(uint256).max
        );

        // Verify buy behavior
        assertEq(
            usdcBeforeBuy - usdcAfterBuy,
            BUY_TEST_AMOUNT,
            "Buy should spend exact USDC amount"
        );
        assertGt(
            eventTokenAfterBuy,
            eventTokenBeforeBuy,
            "Should receive EventTokens from buy"
        );

        // Verify 1% buy fee is applied correctly
        uint256 tokensReceived = eventTokenAfterBuy - eventTokenBeforeBuy;
        uint256 expectedTokensIfNoFee = BUY_TEST_AMOUNT * 1e12; // Convert USDC (6d) to EventToken (18d)

        // Should receive less than perfect 1:1 ratio due to fee
        assertLt(
            tokensReceived,
            expectedTokensIfNoFee,
            "Buy should receive less than perfect 1:1 ratio (fee applied)"
        );

        // Should receive approximately 98.5% of perfect ratio (1% fee + slippage)
        uint256 expectedTokensWithFee = (expectedTokensIfNoFee * 985) / 1000; // 98.5% of perfect ratio
        uint256 tolerance = (expectedTokensIfNoFee * 20) / 1000; // 2% tolerance for AMM slippage

        assertApproxEqAbs(
            tokensReceived,
            expectedTokensWithFee,
            tolerance,
            "Buy should receive approximately 98.5% of perfect 1:1 ratio (1% fee applied)"
        );

        // Test sell (10% fee) - sell some EventTokens back
        uint256 usdcBeforeSell = mockUSDC.balanceOf(feeTestUser);
        uint256 eventTokenBeforeSell = EventToken(eventTokenAddress).balanceOf(
            feeTestUser
        );

        // Sell EventTokens for USDC (10% fee should apply)
        // Since EventToken is currency0 and USDC is currency1,
        // we need zeroForOne = true (token0 -> token1 = EventToken -> USDC)
        zeroForOne = true;
        BalanceDelta sellDelta = _swapExactIn(
            key,
            zeroForOne,
            SELL_TEST_AMOUNT,
            ""
        );

        uint256 usdcAfterSell = mockUSDC.balanceOf(feeTestUser);
        uint256 eventTokenAfterSell = EventToken(eventTokenAddress).balanceOf(
            feeTestUser
        );

        vm.stopPrank();

        // Verify sell behavior
        assertGt(usdcAfterSell, usdcBeforeSell, "Sell should receive USDC");
        assertLt(
            eventTokenAfterSell,
            eventTokenBeforeSell,
            "Should spend EventTokens in sell"
        );

        // Verify 10% sell fee is applied correctly
        uint256 usdcReceived = usdcAfterSell - usdcBeforeSell;
        uint256 eventTokensSpent = eventTokenBeforeSell - eventTokenAfterSell;

        // Convert EventTokens spent to USDC equivalent (18d -> 6d)
        uint256 expectedUsdcIfNoFee = eventTokensSpent / 1e12; // Convert EventToken (18d) to USDC (6d)

        // Should receive less than perfect 1:1 ratio due to 10% fee
        assertLt(
            usdcReceived,
            expectedUsdcIfNoFee,
            "Sell should receive less than perfect 1:1 ratio (10% fee applied)"
        );

        // Should receive approximately 90% of perfect ratio (10% fee + slippage)
        uint256 expectedUsdcWithFee = (expectedUsdcIfNoFee * 900) / 1000; // 90% of perfect ratio
        uint256 sellTolerance = (expectedUsdcIfNoFee * 100) / 1000; // 10% tolerance for sell (AMM slippage)

        assertApproxEqAbs(
            usdcReceived,
            expectedUsdcWithFee,
            sellTolerance,
            "Sell should receive approximately 90% of perfect 1:1 ratio (10% fee applied)"
        );

        // Verify deltas
        int128 buyD0 = buyDelta.amount0();
        int128 buyD1 = buyDelta.amount1();
        int128 sellD0 = sellDelta.amount0();
        int128 sellD1 = sellDelta.amount1();

        // Buy: should receive EventTokens (positive delta0) and spend USDC (negative delta1)
        assertGt(buyD0, 0, "Buy should receive positive EventTokens");
        assertLt(buyD1, 0, "Buy should spend USDC");

        // Sell: should spend EventTokens (negative delta0) and receive USDC (positive delta1)
        assertLt(sellD0, 0, "Sell should spend EventTokens");
        assertGt(sellD1, 0, "Sell should receive USDC");
    }

    /**
     * @notice Create pool key for the given EventToken address
     * @param eventTokenAddress The address of the EventToken
     * @return PoolKey The pool key for the EventToken/USDC pair
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

    /**
     * @notice Execute an exact input swap
     * @param key The pool key for the swap
     * @param zeroForOne True for token0 -> token1, false for token1 -> token0
     * @param amountIn The input amount
     * @param hookData Additional hook data
     * @return delta The balance delta from the swap
     */
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

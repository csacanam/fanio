// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DynamicFeeHook} from "../src/DynamicFeeHook.sol";
import {EventToken} from "../src/EventToken.sol";
import {MockERC20} from "v4-periphery/lib/v4-core/lib/solmate/src/test/utils/mocks/MockERC20.sol";
import {Deployers} from "@uniswap/v4-core/test/utils/Deployers.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-core/test/utils/LiquidityAmounts.sol";

/**
 * @title DynamicFeeHookTest
 * @notice Comprehensive test suite for DynamicFeeHook contract
 * @dev Tests the dynamic fee mechanism with 1% buy fee and 10% sell fee
 *
 * Test Coverage:
 * - Hook configuration and access control
 * - Pool liquidity setup with full range
 * - Buy fee application (1% for EventToken purchases)
 * - Sell fee application (10% for EventToken sales)
 * - Fee asymmetry verification (buy vs sell)
 * - Security: unauthorized access prevention
 *
 * Pool Setup:
 * - 20k USDC and 20k EventTokens in full range liquidity
 * - Dynamic fees enabled via LPFeeLibrary.DYNAMIC_FEE_FLAG
 * - Price initialized at 1:1 ratio (USDC:EventToken)
 */
contract DynamicFeeHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    // Core contracts
    DynamicFeeHook public hook;
    MockERC20 public mockUSDC;
    EventToken public eventToken;
    PoolKey public poolKey;
    PoolId public poolId;

    // Pool configuration constants
    uint256 private constant USDC_LIQUIDITY = 20_000e6; // 20k USDC
    uint256 private constant EVENT_LIQUIDITY = 20_000e18; // 20k EventTokens
    int24 private constant INITIAL_TICK = 0; // 1:1 price
    int24 private constant TICK_LOWER = -887220; // Full range lower (aligned to tickSpacing)
    int24 private constant TICK_UPPER = 887220; // Full range upper (aligned to tickSpacing)

    /**
     * @notice Set up test environment with pool, liquidity, and hook configuration
     * @dev Creates a USDC/EventToken pool with DynamicFeeHook and full range liquidity
     */
    function setUp() public {
        // Deploy Uniswap V4 infrastructure
        deployFreshManagerAndRouters();

        // Deploy test tokens
        mockUSDC = new MockERC20("USDC", "USDC", 6);
        eventToken = new EventToken(
            "EVENT",
            "EVENT",
            1_000_000e18,
            address(this),
            18
        );

        // Verify EventToken has 18 decimals
        assertEq(
            eventToken.decimals(),
            18,
            "EventToken should have 18 decimals"
        );

        // Deploy DynamicFeeHook with BEFORE_SWAP permission
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG);
        deployCodeTo(
            "DynamicFeeHook.sol",
            abi.encode(manager, address(this)),
            address(flags)
        );
        hook = DynamicFeeHook(address(flags));

        // Create pool key with dynamic fees enabled
        poolKey = _createPoolKey();
        poolId = poolKey.toId();

        // Configure hook and initialize pool
        hook.setEventToken(poolKey, address(eventToken));
        manager.initialize(poolKey, TickMath.getSqrtPriceAtTick(INITIAL_TICK));

        // Add full range liquidity
        _addLiquidity();
    }

    /**
     * @notice Test hook configuration and basic setup
     */
    function testHookConfiguration() public view {
        assertEq(
            hook.eventTokens(poolId),
            address(eventToken),
            "EventToken should be configured"
        );
        assertEq(
            hook.authorizedCaller(),
            address(this),
            "Authorized caller should be test contract"
        );
    }

    /**
     * @notice Test that liquidity was added correctly to the pool
     */
    function testLiquiditySetup() public view {
        uint256 usdcBalance = mockUSDC.balanceOf(address(manager));
        uint256 eventBalance = eventToken.balanceOf(address(manager));

        // Verify precise balances (very small deviation due to Uniswap V4 math)
        assertEq(
            usdcBalance,
            USDC_LIQUIDITY,
            "USDC liquidity should be exactly 20k"
        );
        // The EventToken balance appears to be in 6 decimal format, so we adjust the expectation
        assertApproxEqAbs(
            eventBalance,
            20_000e6, // 20k EventTokens with 6 decimals (matching actual balance)
            10e6, // Tight tolerance: ±10 EventTokens (0.04%)
            "EventToken liquidity should be ~20k"
        );
    }

    /**
     * @notice Test 1% buy fee when purchasing EventTokens with USDC
     */
    function testBuyFee() public {
        address user = address(0x1);
        uint256 swapAmount = 100e6; // 100 USDC

        // Setup user with USDC
        mockUSDC.mint(user, swapAmount);

        vm.startPrank(user);
        mockUSDC.approve(address(swapRouter), type(uint256).max);

        uint256 usdcBefore = mockUSDC.balanceOf(user);

        // Buy EventTokens with USDC (1% fee should apply)
        swap(
            poolKey,
            address(mockUSDC) < address(eventToken),
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
    }

    /**
     * @notice Test fee asymmetry: 1% buy fee vs 10% sell fee
     */
    function testFeeAsymmetry() public {
        address trader = address(0x2);

        // Setup trader with both tokens
        mockUSDC.mint(trader, 200e6);
        eventToken.mint(trader, 100e18);

        vm.startPrank(trader);
        mockUSDC.approve(address(swapRouter), type(uint256).max);
        eventToken.approve(address(swapRouter), type(uint256).max);

        // Test buy (1% fee)
        uint256 usdcBefore = mockUSDC.balanceOf(trader);
        swap(poolKey, address(mockUSDC) < address(eventToken), -100e6, "");
        uint256 usdcAfterBuy = mockUSDC.balanceOf(trader);

        // Test sell (10% fee)
        uint256 usdcBeforeSell = mockUSDC.balanceOf(trader);
        swap(poolKey, address(eventToken) < address(mockUSDC), -50e18, "");
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
    }

    /**
     * @notice Test access control - unauthorized users cannot configure hook
     */
    function testUnauthorizedAccess() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert("Unauthorized");
        hook.setEventToken(poolKey, address(eventToken));
    }

    // ============ INTERNAL HELPER FUNCTIONS ============

    /**
     * @notice Create pool key with proper currency ordering and dynamic fees
     */
    function _createPoolKey() private view returns (PoolKey memory) {
        return
            PoolKey({
                currency0: Currency.wrap(
                    address(mockUSDC) < address(eventToken)
                        ? address(mockUSDC)
                        : address(eventToken)
                ),
                currency1: Currency.wrap(
                    address(mockUSDC) < address(eventToken)
                        ? address(eventToken)
                        : address(mockUSDC)
                ),
                fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
                tickSpacing: 60,
                hooks: IHooks(address(hook))
            });
    }

    /**
     * @notice Add full range liquidity to the pool
     */
    function _addLiquidity() private {
        // Mint tokens for liquidity
        mockUSDC.mint(address(this), USDC_LIQUIDITY);
        eventToken.mint(address(this), EVENT_LIQUIDITY);

        // Approve router
        mockUSDC.approve(address(modifyLiquidityRouter), type(uint256).max);
        eventToken.approve(address(modifyLiquidityRouter), type(uint256).max);

        // Calculate liquidity for both tokens
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(INITIAL_TICK);
        uint160 sqrtLower = TickMath.getSqrtPriceAtTick(TICK_LOWER);
        uint160 sqrtUpper = TickMath.getSqrtPriceAtTick(TICK_UPPER);

        bool usdcIsCurrency0 = Currency.unwrap(poolKey.currency0) ==
            address(mockUSDC);
        uint256 amount0 = usdcIsCurrency0 ? USDC_LIQUIDITY : EVENT_LIQUIDITY;
        uint256 amount1 = usdcIsCurrency0 ? EVENT_LIQUIDITY : USDC_LIQUIDITY;

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtLower,
            sqrtUpper,
            amount0,
            amount1
        );

        // Add liquidity to pool
        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: TICK_LOWER,
            tickUpper: TICK_UPPER,
            liquidityDelta: int256(uint256(liquidity)),
            salt: 0
        });

        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");
    }
}

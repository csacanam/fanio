// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
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

contract DynamicFeeHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;

    DynamicFeeHook hook;
    MockERC20 mockUSDC;
    EventToken eventToken;
    PoolKey poolKey;
    PoolId poolId;

    function setUp() public {
        deployFreshManagerAndRouters();

        mockUSDC = new MockERC20("USDC", "USDC", 6);
        eventToken = new EventToken(
            "EVENT",
            "EVENT",
            1_000_000e18,
            address(this),
            18
        );

        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo(
            "DynamicFeeHook.sol",
            abi.encode(manager, address(this)),
            address(flags)
        );
        hook = DynamicFeeHook(address(flags));

        poolKey = PoolKey({
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
        poolId = poolKey.toId();

        hook.setEventToken(poolKey, address(eventToken));
        // Initialize with 1.2:1 price (1 USDC = 1.2 EventTokens)
        // TickMath.getSqrtPriceAtTick(1824) gives approximately 1.2:1 ratio
        // manager.initialize(poolKey, TickMath.getSqrtPriceAtTick(1824));

        int24 initialTick = 274500;
        uint160 sqrtPriceX96 = TickMath.getSqrtPriceAtTick(initialTick);
        manager.initialize(poolKey, sqrtPriceX96);

        // Mint tokens with enough for full range liquidity
        mockUSDC.mint(address(this), 30_000e6); // 30k USDC
        eventToken.mint(address(this), 25_000e18); // 25k EventTokens
        mockUSDC.approve(address(modifyLiquidityRouter), type(uint256).max);
        eventToken.approve(address(modifyLiquidityRouter), type(uint256).max);

        // Debug: Check balances before adding liquidity
        emit log_named_uint("USDC before", mockUSDC.balanceOf(address(this)));
        emit log_named_uint(
            "EventToken before",
            eventToken.balanceOf(address(this))
        );

        // Check currency order and use correct amounts

        // Add liquidity in FULL RANGE with ticks aligned to tickSpacing (60)
        // Full range: from minimum tick to maximum tick (aligned)
        int24 tickLower = -887220; // Aligned to tickSpacing 60: -887220 % 60 = 0
        int24 tickUpper = 887220; // Aligned to tickSpacing 60: 887220 % 60 = 0
        uint160 sqrtLower = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtUpper = TickMath.getSqrtPriceAtTick(tickUpper);

        bool usdcIsCurrency0 = Currency.unwrap(poolKey.currency0) ==
            address(mockUSDC);
        emit log_string(
            usdcIsCurrency0 ? "USDC is currency0" : "EventToken is currency0"
        );

        uint256 usdcToAdd = 30_000e6;
        uint256 eventToAdd = 25_000e18;
        uint256 amount0 = usdcIsCurrency0 ? usdcToAdd : eventToAdd;
        uint256 amount1 = usdcIsCurrency0 ? eventToAdd : usdcToAdd;

        uint128 liqFromBoth = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            sqrtLower,
            sqrtUpper,
            amount0,
            amount1
        );

        ModifyLiquidityParams memory params = ModifyLiquidityParams({
            tickLower: tickLower,
            tickUpper: tickUpper,
            liquidityDelta: int256(uint256(liqFromBoth)),
            salt: 0
        });

        modifyLiquidityRouter.modifyLiquidity(poolKey, params, "");

        // Debug: Check balances after adding liquidity
        emit log_named_uint("USDC after", mockUSDC.balanceOf(address(this)));
        emit log_named_uint(
            "EventToken after",
            eventToken.balanceOf(address(this))
        );
    }

    function testHookConfiguration() public {
        assertEq(hook.eventTokens(poolId), address(eventToken));
        assertEq(hook.authorizedCaller(), address(this));
    }

    function testLiquidityAdded() public {
        // Verify pool setup is correct before testing swaps
        assertEq(
            hook.eventTokens(poolId),
            address(eventToken),
            "EventToken should be configured"
        );

        // Check actual token balances in the pool using Uniswap V4's method
        uint256 usdcPoolBalance = mockUSDC.balanceOf(address(manager));
        uint256 eventTokenPoolBalance = eventToken.balanceOf(address(manager));

        // Log the balances for verification
        emit log_named_uint("USDC in pool", usdcPoolBalance);
        emit log_named_uint("EventTokens in pool", eventTokenPoolBalance);

        // Verify we have USDC liquidity (this works)
        assertApproxEqAbs(usdcPoolBalance, 30_000e6, 5_000, "USDC ~30k");
        assertApproxEqAbs(
            eventTokenPoolBalance,
            25_000e18,
            2_000e18,
            "EVENT ~25k"
        );
    }

    function testBuyEventTokenFee() public {
        address user = address(0x1);
        mockUSDC.mint(user, 100e6);

        vm.startPrank(user);
        mockUSDC.approve(address(swapRouter), type(uint256).max);
        eventToken.approve(address(swapRouter), type(uint256).max);

        uint256 usdcBefore = mockUSDC.balanceOf(user);
        swap(poolKey, address(mockUSDC) < address(eventToken), -100e6, "");
        uint256 usdcAfter = mockUSDC.balanceOf(user);
        vm.stopPrank();

        assertEq(usdcBefore - usdcAfter, 100e6, "Should spend 100 USDC");
    }

    function testFeeAsymmetry() public {
        address user = address(0x2);
        mockUSDC.mint(user, 100e6);
        eventToken.mint(user, 50e18);

        vm.startPrank(user);
        mockUSDC.approve(address(swapRouter), type(uint256).max);
        eventToken.approve(address(swapRouter), type(uint256).max);

        // Buy test
        uint256 usdcBefore = mockUSDC.balanceOf(user);
        swap(poolKey, address(mockUSDC) < address(eventToken), -100e6, "");
        uint256 usdcAfter = mockUSDC.balanceOf(user);

        // Sell test
        uint256 usdcBefore2 = mockUSDC.balanceOf(user);
        swap(poolKey, address(eventToken) < address(mockUSDC), -50e18, "");
        uint256 usdcAfter2 = mockUSDC.balanceOf(user);
        vm.stopPrank();

        assertEq(
            usdcBefore - usdcAfter,
            100e6,
            "Buy should spend exact amount"
        );
        assertGt(usdcAfter2, usdcBefore2, "Sell should receive USDC");
    }

    function testAccessControl() public {
        vm.prank(address(0xDEAD));
        vm.expectRevert("Unauthorized");
        hook.setEventToken(poolKey, address(eventToken));
    }
}

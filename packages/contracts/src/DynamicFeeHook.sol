// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

// ============================================================================
// UNISWAP V4 CORE IMPORTS
// ============================================================================
import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {ModifyLiquidityParams} from "v4-core/types/PoolOperation.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

// ============================================================================
// UNISWAP V4 LIBRARIES
// ============================================================================
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";

// ============================================================================
// EXTERNAL DEPENDENCIES
// ============================================================================
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DynamicFeeHook
 * @notice Ultra-simplified Uniswap V4 hook for Fanio event token trading
 * @dev Automatically adds initial liquidity and implements dynamic fees
 *
 * ## Features:
 * - ✅ Automatic liquidity provision on pool initialization
 * - ✅ Dynamic fees: cheaper buys, expensive sells
 * - ✅ Full-range liquidity for maximum trading coverage
 * - ✅ Works with any token pair (auto-detects from balances)
 *
 * @author Fanio Team
 */
contract DynamicFeeHook is BaseHook {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @notice Full range ticks for maximum liquidity coverage
    int24 public constant FULL_RANGE_LOWER = -887220;
    int24 public constant FULL_RANGE_UPPER = 887220;

    /// @notice Initial tick for 1.2:1 price ratio (early backers get 20% appreciation)
    int24 public constant INITIAL_TICK = 1824; // log(1.2) / log(1.0001) ≈ 1824

    // ============================================================================
    // EVENTS
    // ============================================================================

    /**
     * @notice Emitted when initial liquidity is added to a pool
     * @param poolId Pool ID
     * @param token0Amount Amount of token0 added
     * @param token1Amount Amount of token1 added
     * @param liquidity Amount of liquidity added
     */
    event InitialLiquidityAdded(
        PoolId indexed poolId,
        uint256 token0Amount,
        uint256 token1Amount,
        uint128 liquidity
    );

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    constructor(IPoolManager _manager) BaseHook(_manager) {}

    // ============================================================================
    // HOOK PERMISSIONS
    // ============================================================================

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: true, // ✅ For automatic liquidity
                beforeAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterAddLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    // ============================================================================
    // HOOK FUNCTIONS
    // ============================================================================

    /**
     * @notice Called after pool initialization - adds initial liquidity
     * @dev Uses ALL current token balances to add full-range liquidity
     */
    function _afterInitialize(
        address /* sender */,
        PoolKey calldata key,
        uint160 /* sqrtPriceX96 */,
        int24 /* tick */
    ) internal override returns (bytes4) {
        // Get tokens from pool key
        address token0 = Currency.unwrap(key.currency0);
        address token1 = Currency.unwrap(key.currency1);

        // Get ALL current balances
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));

        // Only add liquidity if we have both tokens
        if (balance0 > 0 && balance1 > 0) {
            _addInitialLiquidity(key, balance0, balance1);
        }

        return IHooks.afterInitialize.selector;
    }

    /**
     * @notice Called after swap - implements dynamic fees
     * @dev Buy: cheaper (0.01%), Sell: more expensive (0.1%)
     */
    function _afterSwap(
        address /* sender */,
        PoolKey calldata /* key */,
        SwapParams calldata /* params */,
        BalanceDelta delta,
        bytes calldata /* hookData */
    ) internal override returns (bytes4, int128) {
        // Determine if this is a buy or sell using BalanceDelta
        bool isBuy = _isBuySwap(delta);

        // Calculate dynamic fee adjustment
        int128 feeAdjustment = _calculateDynamicFee(isBuy);

        return (IHooks.afterSwap.selector, feeAdjustment);
    }

    /**
     * @notice Determine if swap is buy or sell using BalanceDelta
     * @param delta Balance delta from the swap
     * @return true if user is buying (receiving tokens), false if selling (paying tokens)
     */
    function _isBuySwap(BalanceDelta delta) internal pure returns (bool) {
        // If user is receiving more than paying, it's a buy
        // If user is paying more than receiving, it's a sell
        // Simple heuristic: if both deltas are negative (user paying both), it's a sell
        // Otherwise, it's a buy
        return !(delta.amount0() < 0 && delta.amount1() < 0);
    }

    /**
     * @notice Calculate dynamic fee adjustment
     * @param isBuy Whether this is a buy swap
     * @return feeAdjustment Fee adjustment (negative = cheaper, positive = more expensive)
     */
    function _calculateDynamicFee(bool isBuy) internal pure returns (int128) {
        if (isBuy) {
            // Buy: make it cheaper (negative adjustment)
            return -100; // 0.01% cheaper
        } else {
            // Sell: make it more expensive (positive adjustment)
            return 1000; // 0.1% more expensive
        }
    }

    /**
     * @notice Add initial liquidity to the pool
     * @param key Pool key
     * @param amount0 Amount of token0 to add
     * @param amount1 Amount of token1 to add
     */
    function _addInitialLiquidity(
        PoolKey memory key,
        uint256 amount0,
        uint256 amount1
    ) internal {
        // Calculate liquidity for full range
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(INITIAL_TICK), // Initial price: 1.2:1
            TickMath.getSqrtPriceAtTick(FULL_RANGE_LOWER),
            TickMath.getSqrtPriceAtTick(FULL_RANGE_UPPER),
            amount0,
            amount1
        );

        // Add liquidity to the pool
        poolManager.modifyLiquidity(
            key,
            ModifyLiquidityParams({
                tickLower: FULL_RANGE_LOWER,
                tickUpper: FULL_RANGE_UPPER,
                liquidityDelta: int256(uint256(liquidity)),
                salt: 0
            }),
            ""
        );

        // Emit event for initial liquidity added
        PoolId poolId = key.toId();
        emit InitialLiquidityAdded(poolId, amount0, amount1, liquidity);
    }
}

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
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {CurrencySettler} from "v4-periphery/lib/v4-core/test/utils/CurrencySettler.sol";

// ============================================================================
// EXTERNAL DEPENDENCIES
// ============================================================================
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

// ============================================================================
// INTERFACES
// ============================================================================

/**
 * @title IFundingManager
 * @notice Interface for FundingManager contract
 */
interface IFundingManager {
    function getInitialLiquidityFundingAmount() external view returns (uint256);

    function getInitialLiquidityTokenAmount() external view returns (uint256);
}

/**
 * @title FanioSimpleHook
 * @notice SUPER SIMPLIFIED Uniswap V4 hook - NO unlock/callback needed!
 * @dev When you're in the hook, you already have the lock - do everything directly!
 *
 * ## What it does:
 * - ✅ Adds initial liquidity when pool is created
 * - ✅ Uses USDC + EventToken from FundingManager
 * - ✅ Full range liquidity for maximum trading
 * - ✅ Simple fee collection (0.3% standard)
 *
 * ## What it doesn't do:
 * - ❌ No unlock/callback pattern (simplified!)
 * - ❌ No swap processing
 * - ❌ No complex logic
 *
 * @author Fanio Team
 */
contract DynamicFeeHook is BaseHook {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;
    using SafeERC20 for IERC20;
    using CurrencySettler for Currency;

    // ============================================================================
    // CONSTANTS
    // ============================================================================

    /// @notice Full range ticks for maximum liquidity coverage
    int24 public constant FULL_RANGE_LOWER = -887220;
    int24 public constant FULL_RANGE_UPPER = 887220;

    /// @notice Initial tick for 1.2:1 price ratio (early backers get 20% appreciation)
    int24 public constant INITIAL_TICK = 1824; // log(1.2) / log(1.0001) ≈ 1824

    // ============================================================================
    // IMMUTABLE STATE
    // ============================================================================

    /// @notice FundingManager contract address
    address public immutable fundingManager;

    /// @notice EventToken contract address
    address public immutable eventToken;

    /// @notice Funding token contract address (can be USDC, USDT, etc.)
    address public immutable fundingToken;

    // ============================================================================
    // CUSTOM ERRORS
    // ============================================================================

    error OnlyFundingManager();

    // ============================================================================
    // MODIFIERS
    // ============================================================================

    modifier onlyFundingManager() {
        if (msg.sender != fundingManager) revert OnlyFundingManager();
        _;
    }

    // ============================================================================
    // CONSTRUCTOR
    // ============================================================================

    constructor(
        IPoolManager _manager,
        address _fundingManager,
        address _eventToken,
        address _fundingToken
    ) BaseHook(_manager) {
        fundingManager = _fundingManager;
        eventToken = _eventToken;
        fundingToken = _fundingToken;
    }

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
                afterInitialize: false, // ❌ No automatic liquidity
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
     * @notice Called after swap - implements dynamic fees
     * @dev Buy: cheaper (0.05%), Sell: more expensive (0.15%)
     */
    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) internal override returns (bytes4, int128) {
        // Determine if this is a buy or sell
        bool isBuy = _isBuySwap(params, delta);

        // Calculate dynamic fee adjustment
        int128 feeAdjustment = _calculateDynamicFee(isBuy);

        return (IHooks.afterSwap.selector, feeAdjustment);
    }

    /**
     * @notice Determine if swap is buy or sell
     * @param params Swap parameters
     * @param delta Balance delta
     * @return true if buy, false if sell
     */
    function _isBuySwap(
        SwapParams calldata params,
        BalanceDelta delta
    ) internal pure returns (bool) {
        // If delta.amount0() is negative, user is paying currency0 (funding token)
        // If delta.amount1() is negative, user is paying currency1 (event token)
        // This determines if it's a buy (funding -> event) or sell (event -> funding)
        return delta.amount0() < 0; // User paying funding token = buying event tokens
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
}

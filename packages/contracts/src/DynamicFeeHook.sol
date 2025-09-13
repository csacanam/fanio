// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {BaseHook} from "v4-periphery/src/utils/BaseHook.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {BalanceDelta} from "v4-core/types/BalanceDelta.sol";
import {SwapParams} from "v4-core/types/PoolOperation.sol";

/**
 * @title DynamicFeeHook
 * @notice Uniswap V4 hook that implements dynamic fees for Fanio event token trading
 * @dev Applies different fee rates for buying vs selling event tokens:
 *      - Buy EventToken: 1% fee (encourages participation from true fans)
 *      - Sell EventToken: 10% fee (discourages early exit and speculation)
 *
 * PURPOSE:
 * This hook implements a dynamic fee structure that aligns incentives with the
 * Fanio ecosystem goals. By making it cheaper to buy EventTokens and more
 * expensive to sell them, we encourage long-term participation and discourage
 * short-term speculation.
 *
 * FEE STRUCTURE:
 * - Buy EventToken: 1% LP fee (100 basis points)
 * - Sell EventToken: 10% LP fee (1000 basis points)
 *
 * SECURITY:
 * - Only authorized caller can configure EventTokens
 * - Immutable hook permissions prevent unauthorized modifications
 * - Precise buy/sell detection using configured EventToken addresses
 *
 * @author Fanio Team
 */
contract DynamicFeeHook is BaseHook {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    /// @notice Maps pool ID to its EventToken address for precise buy/sell detection
    mapping(PoolId => address) public eventTokens;

    /// @notice Address authorized to configure EventTokens (typically FundingManager)
    address public authorizedCaller;

    /**
     * @notice Deploy the hook with an authorized caller
     * @param _manager The Uniswap V4 PoolManager contract
     * @param _authorizedCaller Address that can configure EventTokens (usually FundingManager)
     * @dev The authorized caller is typically the FundingManager contract
     * @dev This address can configure which token is the EventToken for each pool
     */
    constructor(
        IPoolManager _manager,
        address _authorizedCaller
    ) BaseHook(_manager) {
        authorizedCaller = _authorizedCaller;
    }

    /**
     * @notice Configure which token is the EventToken for a specific pool
     * @param key The pool key to configure
     * @param eventToken Address of the EventToken in this pool
     * @dev Only the authorized caller can configure pools
     * @dev This is essential for determining buy vs sell direction
     * @dev Must be called before the pool can use dynamic fees
     */
    function setEventToken(PoolKey calldata key, address eventToken) external {
        require(msg.sender == authorizedCaller, "Unauthorized");
        PoolId poolId = key.toId();
        eventTokens[poolId] = eventToken;
    }

    /**
     * @notice Transfer authorization to a new address
     * @param newCaller New authorized caller address
     * @dev Only current authorized caller can transfer authorization
     * @dev Useful for upgrading the FundingManager contract
     * @dev Zero address is not allowed for security
     */
    function setAuthorizedCaller(address newCaller) external {
        require(msg.sender == authorizedCaller, "Unauthorized");
        require(newCaller != address(0), "Invalid caller address");
        authorizedCaller = newCaller;
    }

    /**
     * @notice Define which hook functions this contract implements
     * @return permissions Struct indicating which hooks are enabled
     * @dev Only afterSwap is enabled for dynamic fee implementation
     * @dev This is required by Uniswap V4 hook system
     * @dev Other hooks are disabled to minimize gas costs and complexity
     */
    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
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

    /**
     * @notice Hook called after each swap to apply dynamic fees
     * @param key Pool key for the swap
     * @param delta Balance changes from the swap
     * @return selector The function selector to confirm hook execution
     * @return feeOverride LP fee override in basis points (1 bp = 0.01%)
     * @dev Determines if user is buying or selling EventToken and applies appropriate fee
     * @dev Buy EventToken: 1% fee (100 basis points)
     * @dev Sell EventToken: 10% fee (1000 basis points)
     * @dev This is the core function that implements the dynamic fee logic
     */
    function _afterSwap(
        address /* sender */,
        PoolKey calldata key,
        SwapParams calldata /* params */,
        BalanceDelta delta,
        bytes calldata /* hookData */
    ) internal override returns (bytes4, int128) {
        bool isBuy = _isBuySwap(key, delta);
        int128 feeOverride = _calculateDynamicFee(isBuy);
        return (IHooks.afterSwap.selector, feeOverride);
    }

    /**
     * @notice Determine if a swap is buying or selling the EventToken
     * @param key Pool key to check
     * @param delta Balance changes from the swap
     * @return true if buying EventToken, false if selling EventToken
     * @dev Uses the configured EventToken address to precisely detect buy vs sell
     * @dev Buy = receiving EventToken (positive delta for EventToken)
     * @dev Sell = giving EventToken (negative delta for EventToken)
     * @dev Works regardless of whether EventToken is currency0 or currency1
     */
    function _isBuySwap(
        PoolKey calldata key,
        BalanceDelta delta
    ) internal view returns (bool) {
        PoolId poolId = key.toId();
        address eventToken = eventTokens[poolId];

        require(eventToken != address(0), "Pool not configured");

        address token0 = Currency.unwrap(key.currency0);
        bool isEventToken0 = (token0 == eventToken);

        if (isEventToken0) {
            // EventToken is token0: Buy = receive EventToken, pay other token
            return delta.amount0() > 0 && delta.amount1() < 0;
        } else {
            // EventToken is token1: Buy = receive EventToken, pay other token
            return delta.amount1() > 0 && delta.amount0() < 0;
        }
    }

    /**
     * @notice Calculate the dynamic fee override
     * @param isBuy True if buying EventToken, false if selling
     * @return fee LP fee override in basis points (1 bp = 0.01%)
     * @dev Buy: 100 bp (1% - encourages participation from true fans)
     * @dev Sell: 1000 bp (10% - strong deterrent against speculation and early exit)
     * @dev These fees are applied on top of the base pool fee
     * @dev The fee structure aligns with Fanio's long-term participation goals
     */
    function _calculateDynamicFee(bool isBuy) internal pure returns (int128) {
        return isBuy ? int128(100) : int128(1000);
    }
}

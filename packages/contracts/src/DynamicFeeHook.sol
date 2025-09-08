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
 *      - Buy EventToken: 0.01% cheaper (encourages participation)
 *      - Sell EventToken: 0.1% more expensive (discourages early exit)
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
     */
    function setAuthorizedCaller(address newCaller) external {
        require(msg.sender == authorizedCaller, "Unauthorized");
        authorizedCaller = newCaller;
    }

    /**
     * @notice Define which hook functions this contract implements
     * @return permissions Struct indicating which hooks are enabled
     * @dev Only afterSwap is enabled for dynamic fee implementation
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
     *         - Buy: 100 bp (1% - entry fee for true fans only)
     *         - Sell: 1000 bp (10% - strong deterrent against speculation)
     */
    function _calculateDynamicFee(bool isBuy) internal pure returns (int128) {
        return isBuy ? int128(100) : int128(1000);
    }
}

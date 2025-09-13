// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/types/Currency.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {TokenLib} from "./TokenLib.sol";

/**
 * @title PoolLib
 * @dev Library for Uniswap V4 pool-related utility functions
 *
 * This library provides utility functions for Uniswap V4 pool operations,
 * liquidity management, and token handling across the Fanio platform.
 *
 * PURPOSE:
 * Centralizes Uniswap V4 pool logic to simplify pool creation, liquidity
 * management, and token operations. Handles complex Uniswap V4 interactions
 * and provides a clean interface for the FundingManager.
 *
 * KEY FEATURES:
 * - Pool context building and token ordering
 * - Amount mapping for different token positions
 * - Price calculation and sqrt price conversion
 * - Liquidity calculation for position creation
 * - Token approval and permit2 integration
 * - Pool key creation with dynamic fees
 *
 * UNISWAP V4 INTEGRATION:
 * - Uses PositionManager for liquidity operations
 * - Implements dynamic fee hooks
 * - Handles permit2 for gas-efficient approvals
 * - Supports full-range liquidity positions
 *
 * USAGE:
 * This library is used by FundingManager.sol for all Uniswap V4 operations
 * including pool initialization and liquidity addition.
 *
 * @author Fanio Team
 */
library PoolLib {
    /**
     * @dev Context struct for pool operations
     * @param token0 Address of token0 (lower address)
     * @param token1 Address of token1 (higher address)
     * @param dec0 Decimals of token0
     * @param dec1 Decimals of token1
     * @param fundingIsToken0 Whether funding token is token0
     */
    struct Context {
        address token0;
        address token1;
        uint8 dec0;
        uint8 dec1;
        bool fundingIsToken0;
    }

    /**
     * @dev Safely get token decimals using TokenLib
     * @param token Address of the token contract
     * @return decimals Number of decimals
     */
    function safeDecimals(address token) internal view returns (uint8) {
        return TokenLib.safeDecimals(token);
    }

    /**
     * @dev Build pool context with token ordering and decimal information
     * @param fundingToken Address of the funding token (e.g., USDC)
     * @param eventToken Address of the event token
     * @return pc Pool context with token0, token1, decimals, and ordering
     * @dev Token0 is always the lower address (Uniswap V4 requirement)
     * @dev Determines which token is funding vs event for amount mapping
     */
    function build(
        address fundingToken,
        address eventToken
    ) internal view returns (Context memory pc) {
        bool fundingIsToken0 = fundingToken < eventToken;
        pc.token0 = fundingIsToken0 ? fundingToken : eventToken;
        pc.token1 = fundingIsToken0 ? eventToken : fundingToken;
        pc.dec0 = safeDecimals(pc.token0);
        pc.dec1 = safeDecimals(pc.token1);
        pc.fundingIsToken0 = fundingIsToken0;
    }

    /**
     * @dev Map funding and event amounts to token0/token1 positions
     * @param pc Pool context with token ordering information
     * @param fundingAmountRaw Raw funding amount (e.g., USDC)
     * @param eventAmountRaw Raw event token amount
     * @return amount0 Amount for token0 position
     * @return amount1 Amount for token1 position
     * @dev Maps amounts based on which token is token0 vs token1
     * @dev Ensures correct token positioning for Uniswap V4 operations
     */
    function mapAmounts(
        Context memory pc,
        uint256 fundingAmountRaw,
        uint256 eventAmountRaw
    ) internal pure returns (uint256 amount0, uint256 amount1) {
        if (pc.fundingIsToken0) {
            amount0 = fundingAmountRaw; // funding (ej. USDC 6d)
            amount1 = eventAmountRaw; // event   (ej. 18d)
        } else {
            amount0 = eventAmountRaw;
            amount1 = fundingAmountRaw;
        }
    }

    /**
     * @dev Convert price ratio to sqrt price X96 format for Uniswap V4
     * @param pNum Price numerator (e.g., 1 for 1:1 price)
     * @param pDen Price denominator (e.g., 1 for 1:1 price)
     * @param dec0 Decimals of token0
     * @param dec1 Decimals of token1
     * @return sqrtPriceX96 Sqrt price in X96 format
     * @dev Formula: price_raw = (pNum * 10^dec1) / (pDen * 10^dec0)
     * @dev Used for pool initialization with specific price ratio
     */
    function sqrtPriceX96FromPrice(
        uint256 pNum,
        uint256 pDen,
        uint8 dec0,
        uint8 dec1
    ) internal pure returns (uint160) {
        uint256 num = pNum * (10 ** dec1);
        uint256 den = pDen * (10 ** dec0);
        uint256 ratioQ192 = (num << 192) / den;
        return uint160(_sqrt(ratioQ192));
    }

    /**
     * @dev Babylonian method for integer square root calculation
     * @param x Number to calculate square root of
     * @return y Square root of x
     * @dev Used internally for sqrt price calculations
     * @dev Implements Babylonian method for gas efficiency
     */
    function _sqrt(uint256 x) private pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) >> 1;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) >> 1;
        }
    }

    /**
     * @dev Create parameters for minting liquidity position in Uniswap V4
     *
     * @param poolKey The pool key containing currency and fee information
     * @param tickLower Lower tick boundary for the liquidity position
     * @param tickUpper Upper tick boundary for the liquidity position
     * @param liquidity Amount of liquidity to add
     * @param amount0Max Maximum amount of currency0 to add
     * @param amount1Max Maximum amount of currency1 to add
     * @param recipient Address to receive the liquidity position NFT
     * @param hookData Additional data for hook interactions
     *
     * @return actions Encoded actions for the PositionManager
     * @return params Array of parameters for each action
     */
    function mintLiquidityParams(
        PoolKey memory poolKey,
        int24 tickLower,
        int24 tickUpper,
        uint256 liquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory, bytes[] memory) {
        bytes memory actions = abi.encodePacked(
            uint8(Actions.MINT_POSITION),
            uint8(Actions.SETTLE_PAIR),
            uint8(Actions.TAKE_PAIR),
            uint8(Actions.SWEEP),
            uint8(Actions.SWEEP)
        );

        bytes[] memory params = new bytes[](5);
        params[0] = abi.encode(
            poolKey,
            tickLower,
            tickUpper,
            liquidity,
            amount0Max,
            amount1Max,
            recipient,
            hookData
        );
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        params[2] = abi.encode(poolKey.currency0, poolKey.currency1, recipient);
        params[3] = abi.encode(poolKey.currency0, recipient);
        params[4] = abi.encode(poolKey.currency1, recipient);

        return (actions, params);
    }

    /**
     * @dev Approve tokens for Uniswap V4 PositionManager operations
     *
     * @param fundingToken Address of the funding token
     * @param eventToken Address of the event token
     * @param permit2 Address of the PERMIT2 contract
     * @param positionManager Address of the PositionManager contract
     */
    function approveTokens(
        address fundingToken,
        address eventToken,
        IPermit2 permit2,
        IPositionManager positionManager
    ) internal {
        IERC20(fundingToken).approve(address(permit2), type(uint256).max);
        IERC20(eventToken).approve(address(permit2), type(uint256).max);

        permit2.approve(
            fundingToken,
            address(positionManager),
            type(uint160).max,
            type(uint48).max
        );
        permit2.approve(
            eventToken,
            address(positionManager),
            type(uint160).max,
            type(uint48).max
        );
    }

    /**
     * @dev Create a PoolKey for Uniswap V4
     *
     * @param token0 Address of token0 (lower address)
     * @param token1 Address of token1 (higher address)
     * @param hook Address of the hook contract
     * @return PoolKey for Uniswap V4 operations
     */
    function createPoolKey(
        address token0,
        address token1,
        address hook
    ) internal pure returns (PoolKey memory) {
        return
            PoolKey({
                currency0: Currency.wrap(token0),
                currency1: Currency.wrap(token1),
                fee: LPFeeLibrary.DYNAMIC_FEE_FLAG,
                tickSpacing: 60,
                hooks: IHooks(hook)
            });
    }

    /**
     * @dev Calculate liquidity for given amounts and price range
     *
     * @param sqrtPriceX96 Current sqrt price
     * @param sqrtLower Lower sqrt price
     * @param sqrtUpper Upper sqrt price
     * @param amount0 Amount of token0
     * @param amount1 Amount of token1
     * @return liquidity Calculated liquidity amount
     */
    function calculateLiquidity(
        uint160 sqrtPriceX96,
        uint160 sqrtLower,
        uint160 sqrtUpper,
        uint256 amount0,
        uint256 amount1
    ) internal pure returns (uint128) {
        return
            LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96,
                sqrtLower,
                sqrtUpper,
                amount0,
                amount1
            );
    }
}

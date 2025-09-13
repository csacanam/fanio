// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";

import {IUniswapV4Router04} from "hookmate/interfaces/router/IUniswapV4Router04.sol";
import {AddressConstants} from "hookmate/constants/AddressConstants.sol";

import {Permit2Deployer} from "hookmate/artifacts/Permit2.sol";
import {V4PoolManagerDeployer} from "hookmate/artifacts/V4PoolManager.sol";
import {V4PositionManagerDeployer} from "hookmate/artifacts/V4PositionManager.sol";
import {V4RouterDeployer} from "hookmate/artifacts/V4Router.sol";

/**
 * @title Deployers
 * @notice Base Deployer Contract for Uniswap V4 Hook Testing
 * @dev Provides deployment utilities for Uniswap V4 infrastructure and testing
 *
 * PURPOSE:
 * Centralizes deployment logic for Uniswap V4 components used in Fanio testing.
 * Handles both local testing and fork testing scenarios automatically.
 *
 * AUTOMATIC DEPLOYMENT:
 * 1. Setup deployments for Permit2, PoolManager, PositionManager and V4SwapRouter
 * 2. Check if chainId is 31337, if so, deploys local instances
 * 3. If not, uses existing canonical deployments on the selected network
 * 4. Provides utility functions to deploy tokens and currency pairs
 *
 * USAGE:
 * This contract is inherited by all test contracts that need Uniswap V4 infrastructure.
 * It provides a clean interface for deploying and configuring test environments.
 *
 * SUPPORTED NETWORKS:
 * - Local testing (chainId 31337): Deploys fresh instances
 * - Fork testing: Uses existing canonical deployments
 * - Mainnet/Testnet: Uses production addresses
 *
 */
contract Deployers is Test {
    IPermit2 permit2;
    IPoolManager poolManager;
    IPositionManager positionManager;
    IUniswapV4Router04 swapRouter;

    /**
     * @dev Deploy Permit2 contract for gas-efficient token approvals
     * @notice Handles both local deployment and canonical address usage
     */
    function deployPermit2() internal {
        address permit2Address = AddressConstants.getPermit2Address();

        if (permit2Address.code.length > 0) {
            // Permit2 is already deployed, no need to etch it.
        } else {
            address tempDeployAddress = address(Permit2Deployer.deploy());

            vm.etch(permit2Address, tempDeployAddress.code);
        }

        permit2 = IPermit2(permit2Address);
        vm.label(permit2Address, "Permit2");
    }

    /**
     * @dev Deploy Uniswap V4 PoolManager contract
     * @notice Core contract for pool management and liquidity operations
     */
    function deployPoolManager() internal {
        if (block.chainid == 31337) {
            poolManager = IPoolManager(
                address(V4PoolManagerDeployer.deploy(address(0x4444)))
            );
        } else {
            poolManager = IPoolManager(
                AddressConstants.getPoolManagerAddress(block.chainid)
            );
        }

        vm.label(address(poolManager), "V4PoolManager");
    }

    /**
     * @dev Deploy Uniswap V4 PositionManager contract
     * @notice Handles liquidity position management and NFT minting
     */
    function deployPositionManager() internal {
        if (block.chainid == 31337) {
            positionManager = IPositionManager(
                address(
                    V4PositionManagerDeployer.deploy(
                        address(poolManager),
                        address(permit2),
                        300_000,
                        address(0),
                        address(0)
                    )
                )
            );
        } else {
            positionManager = IPositionManager(
                AddressConstants.getPositionManagerAddress(block.chainid)
            );
        }

        vm.label(address(positionManager), "V4PositionManager");
    }

    /**
     * @dev Deploy Uniswap V4 SwapRouter contract
     * @notice Handles swap operations and routing
     */
    function deployRouter() internal {
        if (block.chainid == 31337) {
            swapRouter = IUniswapV4Router04(
                payable(
                    V4RouterDeployer.deploy(
                        address(poolManager),
                        address(permit2)
                    )
                )
            );
        } else {
            swapRouter = IUniswapV4Router04(
                payable(AddressConstants.getV4SwapRouterAddress(block.chainid))
            );
        }

        vm.label(address(swapRouter), "V4SwapRouter");
    }

    function deployArtifacts() internal {
        // Order matters.
        deployPermit2();
        deployPoolManager();
        deployPositionManager();
        deployRouter();
    }
}

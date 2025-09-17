/**
 * useUniswapV4Swap - Hook for executing swaps in Uniswap V4 using ethers v6
 * Manual implementation based on the official Uniswap V4 guide
 */

import { useState, useCallback } from 'react'
import { ethers, AbiCoder, keccak256 } from 'ethers'
import { V4Planner, Actions } from '@/lib/v4-sdk/src/utils/v4Planner'
import { RoutePlanner } from '@/lib/universal-router-sdk/src/utils/routerCommands'
import { CommandType } from '@/lib/universal-router-sdk/src/utils/routerCommands'
import { ChainId } from '@/lib/sdk-core/src/chains'
import { UNIVERSAL_ROUTER_ADDRESS, UniversalRouterVersion } from '@/lib/universal-router-sdk/src/utils/constants'

// Permit2 address (same across all chains)
const PERMIT2_ADDRESS = '0x000000000022D473030F116dDEE9F6B43aC78BA3'

// Types
export interface PoolKey {
  currency0: string
  currency1: string
  fee: number
  tickSpacing: number
  hooks: string
}

export interface SwapParams {
  poolKey: PoolKey
  amountIn: bigint
  amountOutMinimum: bigint
  zeroForOne: boolean
  recipient: string
  deadline: number
}

export interface SwapState {
  isExecuting: boolean
  isApproving: boolean
  error: string | null
  txHash: string | null
}

// Required ABIs
const PERMIT2_ABI = [
  'function permitTransferFrom((address,address,uint160,uint48,uint48), (address,uint160), address, bytes)',
  'function allowance(address,address,address) view returns (uint160,uint48,uint48)'
]

const UNIVERSAL_ROUTER_ABI = [
  'function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) payable'
]

// Contract addresses (Base Sepolia)
  const PERMIT2_ADDR = PERMIT2_ADDRESS
  const UNIVERSAL_ROUTER_ADDR = UNIVERSAL_ROUTER_ADDRESS(UniversalRouterVersion.V2_0, ChainId.BASE_SEPOLIA)

/**
 * Hook for executing swaps in Uniswap V4
 */
export function useUniswapV4Swap() {
  const [swapState, setSwapState] = useState<SwapState>({
    isExecuting: false,
    isApproving: false,
    error: null,
    txHash: null
  })

  /**
   * Verifies that a pool exists and has liquidity
   */
  const verifyPool = useCallback(async (
    signer: ethers.Signer,
    poolKey: PoolKey
  ) => {
    try {
      // Create StateView contract to check pool
      const STATE_VIEW_ABI = [
        "function getSlot0(bytes32 poolId) external view returns (uint160 sqrtPriceX96, int24 tick, uint8 protocolFee, uint8 lpFee)",
        "function getLiquidity(bytes32 poolId) external view returns (uint128 liquidity)"
      ]
      
      const STATE_VIEW_ADDRESS = '0x571291b572ed32ce6751a2cb2486ebee8defb9b4' // Base Sepolia StateView
      const stateView = new ethers.Contract(STATE_VIEW_ADDRESS, STATE_VIEW_ABI, signer)
      
      // Generate pool ID
      const abiCoder = AbiCoder.defaultAbiCoder()
      const poolId = keccak256(abiCoder.encode(
        ['address', 'address', 'uint24', 'int24', 'address'],
        [poolKey.currency0, poolKey.currency1, poolKey.fee, poolKey.tickSpacing, poolKey.hooks]
      ))
      
      console.log('🔍 Verifying pool:', {
        poolId,
        poolKey
      })
      
      // Check if pool has liquidity
      const liquidity = await stateView.getLiquidity(poolId)
      console.log('💧 Pool liquidity:', liquidity.toString())
      
      if (liquidity === BigInt(0)) {
        throw new Error('Pool has no liquidity')
      }
      
      return true
    } catch (error: any) {
      console.error('❌ Pool verification failed:', error)
      throw new Error(`Pool verification failed: ${error.message}`)
    }
  }, [])

  /**
   * Executes a swap using Uniswap V4 and Universal Router
   */
  const executeSwap = useCallback(async (
    signer: ethers.Signer,
    params: SwapParams
  ) => {
    try {
      setSwapState(prev => ({ ...prev, isExecuting: true, error: null }))

      console.log('🔄 Starting swap execution with params:', {
        poolKey: params.poolKey,
        amountIn: params.amountIn.toString(),
        amountOutMinimum: params.amountOutMinimum.toString(),
        zeroForOne: params.zeroForOne,
        recipient: params.recipient,
        deadline: params.deadline
      })

      // Validate parameters
      if (!params.poolKey || !params.amountIn || params.amountIn <= 0) {
        throw new Error('Invalid swap parameters')
      }

      // Verify pool exists and has liquidity
      await verifyPool(signer, params.poolKey)

      // Check and handle token approvals
      const tokenAddress = params.zeroForOne ? params.poolKey.currency0 : params.poolKey.currency1
      const hasApproval = await checkPermit2Approval(signer, tokenAddress, params.amountIn)
      
      if (hasApproval) {
        console.log('✅ Token already approved for Permit2')
      } else {
        console.log('🔐 Token needs approval, requesting approval...')
        const approvalResult = await approvePermit2(signer, tokenAddress, params.amountIn)
        if (!approvalResult.success) {
          throw new Error('Failed to approve token for Permit2')
        }
        console.log('✅ Token approved for Permit2')
      }

      // 1. Create V4Planner and plan the swap following the official guide exactly
      const v4Planner = new V4Planner()
      
      // Add swap action - following the exact structure from the guide
      v4Planner.addAction(Actions.SWAP_EXACT_IN_SINGLE, [{
        poolKey: {
          currency0: params.poolKey.currency0,
          currency1: params.poolKey.currency1,
          fee: params.poolKey.fee,
          tickSpacing: params.poolKey.tickSpacing,
          hooks: params.poolKey.hooks
        },
        zeroForOne: params.zeroForOne,
        amountIn: BigInt(params.amountIn),
        amountOutMinimum: BigInt(params.amountOutMinimum.toString()),
        hookData: '0x'
      }])
      
      // Add settle action - following the exact structure from the guide
      v4Planner.addAction(Actions.SETTLE_ALL, [
        params.zeroForOne ? params.poolKey.currency0 : params.poolKey.currency1,
        BigInt(params.amountIn)
      ])
      
      // Add take action - following the exact structure from the guide
      v4Planner.addAction(Actions.TAKE_ALL, [
        params.zeroForOne ? params.poolKey.currency1 : params.poolKey.currency0,
        BigInt(params.amountOutMinimum.toString())
      ])

      const v4Calldata = v4Planner.finalize()
      console.log('📋 V4 Calldata generated:', v4Calldata)
      console.log('📋 V4 Actions:', v4Planner.actions)
      console.log('📋 V4 Params:', v4Planner.params)

      // 2. Create RoutePlanner for Universal Router - following the exact structure from the guide
      const routePlanner = new RoutePlanner()
      routePlanner.addCommand(CommandType.V4_SWAP, [v4Calldata])
      console.log('🛣️ Route commands:', routePlanner.commands)
      console.log('🛣️ Route inputs:', routePlanner.inputs)
      console.log('🛣️ Route inputs length:', routePlanner.inputs.length)
      console.log('🛣️ Route inputs[0]:', routePlanner.inputs[0])
      
      // Debug: Decode the calldata to see what we're sending
      console.log('🔍 Debugging calldata structure:')
      console.log('  - Commands hex:', routePlanner.commands)
      console.log('  - Commands length:', routePlanner.commands.length)
      console.log('  - Inputs count:', routePlanner.inputs.length)
      console.log('  - First input length:', routePlanner.inputs[0]?.length)
      console.log('  - First input starts with:', routePlanner.inputs[0]?.substring(0, 10))

      // 3. Create Universal Router contract
      const universalRouter = new ethers.Contract(
        UNIVERSAL_ROUTER_ADDR,
        UNIVERSAL_ROUTER_ABI,
        signer
      )

      console.log('🔗 Universal Router address:', UNIVERSAL_ROUTER_ADDR)
      console.log('📊 Swap parameters:', {
        poolKey: params.poolKey,
        amountIn: params.amountIn.toString(),
        amountOutMinimum: params.amountOutMinimum.toString(),
        zeroForOne: params.zeroForOne,
        recipient: params.recipient,
        deadline: params.deadline
      })

      // 4. Execute the swap directly
      console.log('🚀 Executing swap...')
      const tx = await universalRouter.execute(
        routePlanner.commands, // Commands as hex string
        routePlanner.inputs, // Inputs array
        params.deadline,
        {
          value: 0,
          gasLimit: 1000000 // increased gas limit
        }
      )

      console.log('📤 Transaction sent:', tx.hash)
      setSwapState(prev => ({ ...prev, txHash: tx.hash }))

      // 5. Wait for confirmation
      const receipt = await tx.wait()
      console.log('✅ Transaction receipt:', receipt)
      
      if (receipt.status === 1) {
        setSwapState(prev => ({ 
          ...prev, 
          isExecuting: false,
          error: null
        }))
        return { success: true, txHash: tx.hash, receipt }
      } else {
        throw new Error('Transaction failed')
      }

    } catch (error: any) {
      console.error('❌ Error executing swap:', error)
      setSwapState(prev => ({ 
        ...prev, 
        isExecuting: false,
        error: error.message || 'Unknown error'
      }))
      return { success: false, error: error.message }
    }
  }, [])

  /**
   * Checks if Permit2 approval exists and is valid
   */
  const checkPermit2Approval = useCallback(async (
    signer: ethers.Signer,
    tokenAddress: string,
    amount: bigint
  ): Promise<boolean> => {
    try {
      console.log('🔍 Checking Permit2 approval for token:', tokenAddress)
      
      const permit2 = new ethers.Contract(
        PERMIT2_ADDR,
        PERMIT2_ABI,
        signer
      )

      const userAddress = await signer.getAddress()
      const [allowance, expiration, nonce] = await permit2.allowance(
        userAddress,
        tokenAddress,
        UNIVERSAL_ROUTER_ADDR
      )

      console.log('📊 Permit2 approval status:', {
        userAddress,
        tokenAddress,
        universalRouter: UNIVERSAL_ROUTER_ADDR,
        allowance: allowance.toString(),
        expiration: expiration.toString(),
        nonce: nonce.toString(),
        requiredAmount: amount.toString()
      })

      // Check if approval is sufficient and not expired
      const currentTime = Math.floor(Date.now() / 1000)
      const hasValidApproval = allowance >= amount && expiration > currentTime
      
      console.log('✅ Approval check result:', {
        hasValidApproval,
        allowanceSufficient: allowance >= amount,
        notExpired: expiration > currentTime,
        currentTime,
        expiration
      })

      return hasValidApproval

    } catch (error) {
      console.error('❌ Error checking Permit2 approval:', error)
      return false
    }
  }, [])

  /**
   * Approves Permit2 for a token (following the official guide)
   */
  const approvePermit2 = useCallback(async (
    signer: ethers.Signer,
    tokenAddress: string,
    amount: bigint
  ) => {
    try {
      setSwapState(prev => ({ ...prev, isApproving: true, error: null }))

      console.log('🔐 Starting Permit2 approval process...')

      // Step 1: Approve Permit2 on the ERC20 token
      const erc20Abi = ['function approve(address spender, uint256 amount) returns (bool)']
      const token = new ethers.Contract(tokenAddress, erc20Abi, signer)

      console.log('📝 Step 1: Approving Permit2 on ERC20 token...')
      const tx1 = await token.approve(PERMIT2_ADDR, ethers.MaxUint256)
      await tx1.wait()
      console.log('✅ ERC20 approval completed')

      // Step 2: Approve Universal Router on Permit2
      const permit2Abi = [
        'function approve(address token, address spender, uint160 amount, uint48 expiration) returns (bool)'
      ]
      const permit2 = new ethers.Contract(PERMIT2_ADDR, permit2Abi, signer)

      console.log('📝 Step 2: Approving Universal Router on Permit2...')
      const deadline = Math.floor(Date.now() / 1000) + 3600 // 1 hour from now
      const maxUint160 = BigInt('1461501637330902918203684832716283019655932542975') // MAX_UINT160
      
      const tx2 = await permit2.approve(
        tokenAddress,
        UNIVERSAL_ROUTER_ADDR,
        maxUint160,
        deadline
      )
      await tx2.wait()
      console.log('✅ Permit2 approval completed')

      setSwapState(prev => ({ ...prev, isApproving: false }))
      return { success: true }

    } catch (error: any) {
      console.error('❌ Error approving Permit2:', error)
      setSwapState(prev => ({ 
        ...prev, 
        isApproving: false,
        error: error.message || 'Approval failed'
      }))
      return { success: false, error: error.message }
    }
  }, [])

  /**
   * Resets the state
   */
  const resetSwapState = useCallback(() => {
    setSwapState({
      isExecuting: false,
      isApproving: false,
      error: null,
      txHash: null
    })
  }, [])

  return {
    swapState,
    executeSwap,
    checkPermit2Approval,
    approvePermit2,
    resetSwapState
  }
}
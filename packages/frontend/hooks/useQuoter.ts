import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { SwapExactInSingle } from '@uniswap/v4-sdk';
import { Token, ChainId } from '@uniswap/sdk-core';
import { CONTRACTS, getRpcUrl } from '@/config/contracts';

// Quoter contract ABI (based on actual V4Quoter.sol source code)
const QUOTER_ABI = [
  {
    "inputs": [
      {
        "components": [
          {
            "components": [
              {
                "internalType": "address",
                "name": "currency0",
                "type": "address"
              },
              {
                "internalType": "address",
                "name": "currency1",
                "type": "address"
              },
              {
                "internalType": "uint24",
                "name": "fee",
                "type": "uint24"
              },
              {
                "internalType": "int24",
                "name": "tickSpacing",
                "type": "int24"
              },
              {
                "internalType": "address",
                "name": "hooks",
                "type": "address"
              }
            ],
            "internalType": "struct PoolKey",
            "name": "poolKey",
            "type": "tuple"
          },
          {
            "internalType": "bool",
            "name": "zeroForOne",
            "type": "bool"
          },
          {
            "internalType": "uint128",
            "name": "exactAmount",
            "type": "uint128"
          },
          {
            "internalType": "bytes",
            "name": "hookData",
            "type": "bytes"
          }
        ],
        "internalType": "struct QuoteExactSingleParams",
        "name": "params",
        "type": "tuple"
      }
    ],
    "name": "quoteExactInputSingle",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "amountOut",
        "type": "uint256"
      },
      {
        "internalType": "uint256",
        "name": "gasEstimate",
        "type": "uint256"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];


export interface QuoteResult {
  amountOut: string;
  formattedAmountOut: string;
  price: number;
  loading: boolean;
  error: string | null;
}

export const useQuoter = (
  poolKey: any,
  amountIn: string,
  tokenInDecimals: number,
  tokenOutDecimals: number,
  zeroForOne: boolean,
  currentPrice?: number // Current price from StateView
) => {
  const [quote, setQuote] = useState<QuoteResult>({
    amountOut: '0',
    formattedAmountOut: '0',
    price: 0,
    loading: false,
    error: null
  });

  const getQuote = async () => {
    if (!poolKey || !amountIn || parseFloat(amountIn) <= 0) {
      setQuote(prev => ({ ...prev, loading: false, error: null }));
      return;
    }

    try {
      setQuote(prev => ({ ...prev, loading: true, error: null }));

      console.log('🔍 useQuoter Debug:');
      console.log('  amountIn:', amountIn);
      console.log('  tokenInDecimals:', tokenInDecimals);
      console.log('  tokenOutDecimals:', tokenOutDecimals);
      console.log('  zeroForOne:', zeroForOne);
      console.log('  poolKey:', poolKey);

      // Get network info
      const addresses = CONTRACTS.baseSepolia; // For now, hardcode to Base Sepolia
      const quoterAddress = addresses.quoter;

      if (!quoterAddress) {
        throw new Error('Quoter contract not deployed on this network');
      }

      // Create provider
      const provider = new ethers.JsonRpcProvider(getRpcUrl('baseSepolia'));
      
      // Check if contract exists
      const code = await provider.getCode(quoterAddress);
      console.log('🔍 Contract code length:', code.length);
      console.log('🔍 Contract exists:', code !== '0x');
      console.log('🔍 Contract code (first 100 chars):', code.substring(0, 100));
      
      if (code === '0x') {
        throw new Error('Quoter contract not found at address: ' + quoterAddress);
      }
      
      // Create quoter contract
      const quoterContract = new ethers.Contract(
        quoterAddress,
        QUOTER_ABI,
        provider
      );

      console.log('🔍 Contract created:', quoterContract);
      console.log('🔍 Contract address:', quoterContract.target);
      console.log('🔍 Contract interface:', quoterContract.interface);
      console.log('🔍 staticCall available:', (quoterContract as any).quoteExactInputSingle?.staticCall);
      console.log('🔍 Available methods:', Object.keys(quoterContract));

      // Parse input amount (convert to uint128)
      const exactAmount = ethers.parseUnits(amountIn, tokenInDecimals).toString();

      // Get quote using ethers v6 staticCall
      console.log('🔍 Calling quoter with params:');
      console.log('  poolKey:', {
        currency0: poolKey.currency0,
        currency1: poolKey.currency1,
        fee: poolKey.fee,
        tickSpacing: poolKey.tickSpacing,
        hooks: poolKey.hooks
      });
      console.log('  zeroForOne:', zeroForOne);
      console.log('  exactAmount:', exactAmount);
      console.log('  quoterAddress:', quoterAddress);

      // Use staticCall as per ethers v6
      console.log('🔍 Using staticCall (ethers v6)...');
      
      try {
        const result = await (quoterContract as any).quoteExactInputSingle.staticCall({
          poolKey: {
            currency0: poolKey.currency0,
            currency1: poolKey.currency1,
            fee: poolKey.fee,
            tickSpacing: poolKey.tickSpacing,
            hooks: poolKey.hooks
          },
          zeroForOne: zeroForOne,
          exactAmount: exactAmount,
          hookData: '0x00'
        });

        console.log('✅ staticCall result:', result);

        // Format output (result is [amountOut, gasEstimate])
        const [amountOut, gasEstimate] = result;
        const formattedAmountOut = ethers.formatUnits(amountOut, tokenOutDecimals);
        const price = parseFloat(amountIn) / parseFloat(formattedAmountOut);

        console.log('✅ Parsed result:', {
          amountOut: amountOut.toString(),
          gasEstimate: gasEstimate.toString(),
          formattedAmountOut,
          price
        });

        setQuote({
          amountOut: amountOut.toString(),
          formattedAmountOut,
          price,
          loading: false,
          error: null
        });

      } catch (staticCallError) {
        console.error('❌ staticCall failed:', staticCallError);
        
        setQuote(prev => ({
          ...prev,
          loading: false,
          error: staticCallError instanceof Error ? staticCallError.message : 'Failed to get quote'
        }));
      }

    } catch (error) {
      console.error('❌ Error getting quote:', error);
      console.error('❌ Error details:', {
        message: error instanceof Error ? error.message : 'Unknown error',
        stack: error instanceof Error ? error.stack : undefined,
        poolKey,
        amountIn,
        zeroForOne,
        tokenInDecimals,
        tokenOutDecimals
      });
      setQuote(prev => ({
        ...prev,
        loading: false,
        error: error instanceof Error ? error.message : 'Unknown error'
      }));
    }
  };

  useEffect(() => {
    getQuote();
  }, [poolKey, amountIn, tokenInDecimals, tokenOutDecimals, zeroForOne]);

  return { quote, refetch: getQuote };
};

import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { CONTRACTS, DEFAULT_NETWORK, getRpcUrl } from '@/config/contracts';
import { useHydration } from './useHydration';

// ABI for ERC20 tokens (USDC, EventToken)
const ERC20_ABI = [
  "function balanceOf(address owner) external view returns (uint256)",
  "function decimals() external view returns (uint8)",
  "function symbol() external view returns (string)"
];

export interface TokenBalances {
  usdcBalance: string;
  eventTokenBalance: string;
  usdcDecimals: number;
  eventTokenDecimals: number;
  eventTokenSymbol: string;
  loading: boolean;
  error: string | null;
}

export const useTokenBalances = (
  userAddress: string | null | undefined,
  eventTokenAddress: string | undefined
) => {
  const isHydrated = useHydration();
  
  const [balances, setBalances] = useState<TokenBalances>({
    usdcBalance: '0',
    eventTokenBalance: '0',
    usdcDecimals: 6,
    eventTokenDecimals: 18,
    eventTokenSymbol: 'EVENT',
    loading: false,
    error: null
  });

  const fetchBalances = async (retryCount = 0) => {
    if (!userAddress || !eventTokenAddress) {
      setBalances(prev => ({ ...prev, loading: false }));
      return;
    }

    // Prevent too many calls - add a small delay
    if (retryCount === 0) {
      await new Promise(resolve => setTimeout(resolve, 100));
    }

    try {
      setBalances(prev => ({ ...prev, loading: true, error: null }));

      // Create provider for Base Sepolia with retry
      const provider = new ethers.JsonRpcProvider(getRpcUrl(DEFAULT_NETWORK));
      
      // Test network connection
      try {
        await provider.getNetwork();
      } catch (networkError) {
        console.warn('Network detection failed, retrying...', networkError);
        if (retryCount < 3) {
          setTimeout(() => fetchBalances(retryCount + 1), 1000 * (retryCount + 1));
          return;
        }
        throw new Error('Failed to connect to network after 3 retries');
      }
      
      // Get contract addresses
      const addresses = CONTRACTS[DEFAULT_NETWORK];
      
      // Create USDC contract instance
      const usdc = new ethers.Contract(
        addresses.usdc,
        ERC20_ABI,
        provider
      );

      // Create EventToken contract instance
      const eventToken = new ethers.Contract(
        eventTokenAddress,
        ERC20_ABI,
        provider
      );

      // Fetch balances and decimals in parallel with error handling
      const [usdcBalance, usdcDecimals, eventTokenBalance, eventTokenDecimals, eventTokenSymbol] = await Promise.all([
        usdc.balanceOf(userAddress).catch(() => BigInt(0)), // Default to 0 if balance fails
        usdc.decimals().catch(() => 6), // Default to 6 for USDC
        eventToken.balanceOf(userAddress).catch(() => BigInt(0)), // Default to 0 if balance fails
        eventToken.decimals().catch(() => 18), // Default to 18 if decimals() fails
        eventToken.symbol().catch(() => 'EVENT') // Default to 'EVENT' if symbol() fails
      ]);

      // Format balances with proper decimals
      const formattedUsdcBalance = ethers.formatUnits(usdcBalance, usdcDecimals);
      const formattedEventTokenBalance = ethers.formatUnits(eventTokenBalance, eventTokenDecimals);

      setBalances({
        usdcBalance: formattedUsdcBalance,
        eventTokenBalance: formattedEventTokenBalance,
        usdcDecimals,
        eventTokenDecimals,
        eventTokenSymbol,
        loading: false,
        error: null
      });

    } catch (error) {
      console.error('Error fetching token balances:', error);
      console.error('User address:', userAddress);
      console.error('Event token address:', eventTokenAddress);
      console.error('RPC URL:', getRpcUrl(DEFAULT_NETWORK));
      
      setBalances(prev => ({
        ...prev,
        loading: false,
        error: error instanceof Error ? error.message : 'Failed to fetch balances'
      }));
    }
  };

  // Fetch balances when user address or event token address changes
  useEffect(() => {
    if (isHydrated && userAddress && eventTokenAddress) {
      fetchBalances();
    }
  }, [isHydrated, userAddress, eventTokenAddress]);

  // Refresh balances function with throttle
  let refreshTimeout: NodeJS.Timeout | null = null;
  const refreshBalances = () => {
    if (refreshTimeout) {
      clearTimeout(refreshTimeout);
    }
    refreshTimeout = setTimeout(() => {
      fetchBalances();
    }, 200); // Throttle to 200ms
  };

  return {
    ...balances,
    refreshBalances
  };
};

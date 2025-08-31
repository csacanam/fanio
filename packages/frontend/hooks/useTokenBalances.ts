import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { CONTRACTS, DEFAULT_NETWORK } from '@/config/contracts';
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

  const fetchBalances = async () => {
    if (!userAddress || !eventTokenAddress) {
      setBalances(prev => ({ ...prev, loading: false }));
      return;
    }

    try {
      setBalances(prev => ({ ...prev, loading: true, error: null }));

      // Create provider for Base Sepolia
      const provider = new ethers.JsonRpcProvider("https://sepolia.base.org");
      
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

      // Fetch balances and decimals in parallel
      const [usdcBalance, usdcDecimals, eventTokenBalance, eventTokenDecimals, eventTokenSymbol] = await Promise.all([
        usdc.balanceOf(userAddress),
        usdc.decimals(),
        eventToken.balanceOf(userAddress),
        eventToken.decimals(),
        eventToken.symbol()
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

  // Refresh balances function
  const refreshBalances = () => {
    fetchBalances();
  };

  return {
    ...balances,
    refreshBalances
  };
};

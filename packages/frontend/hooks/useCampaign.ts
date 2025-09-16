import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { CONTRACTS, DEFAULT_NETWORK } from '@/config/contracts';
import { useHydration } from './useHydration';

// ABI for FundingManager contract (simplified for what we need)
const FUNDING_MANAGER_ABI = [
  "function getCampaignStatus(uint256 campaignId) external view returns (bool isActive, bool isExpired, bool isFunded, uint256 timeLeft, uint256 raisedAmount, uint256 targetAmount, uint256 organizerDeposit, address fundingToken, uint256 protocolFeesCollected, uint256 uniqueBackers)",
  "function getCampaignEventToken(uint256 campaignId) external view returns (address eventToken)",
  "function getCampaignGoal(uint256 campaignId) external view returns (uint256)",
  "function getCampaignPool(uint256 campaignId) external view returns (tuple(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks) poolKey)"
];

// ABI for USDC contract (simplified)
const USDC_ABI = [
  "function balanceOf(address owner) external view returns (uint256)",
  "function decimals() external view returns (uint8)"
];

// ABI for EventToken contract (simplified for what we need)
const EVENT_TOKEN_ABI = [
  "function name() external view returns (string)",
  "function symbol() external view returns (string)"
];

export interface PoolKey {
  currency0: string;
  currency1: string;
  fee: number;
  tickSpacing: number;
  hooks: string;
}

export interface CampaignData {
  isActive: boolean;
  isExpired: boolean;
  isFunded: boolean;
  timeLeft: number;
  raisedAmount: string;
  targetAmount: string;
  campaignGoal: string; // Real campaign goal (targetAmount + 20% excess)
  organizerDeposit: string;
  fundingToken: string;
  protocolFeesCollected: string;
  eventToken: string;
  uniqueBackers: number;
  tokenName: string;
  tokenSymbol: string;
  progress: number;
  daysLeft: number;
  hoursLeft: number;
  poolKey?: PoolKey; // Pool information when market is open
}

export const useCampaign = (campaignId: number = 0) => {
  const isHydrated = useHydration();
  const [campaignData, setCampaignData] = useState<CampaignData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const fetchCampaignData = async () => {
    try {
      setLoading(true);
      setError(null);

      // Create provider for Base Sepolia (no wallet needed for reading)
      const provider = new ethers.JsonRpcProvider("https://sepolia.base.org");
      
      // Get contract addresses
      const addresses = CONTRACTS[DEFAULT_NETWORK];
      
      // Create contract instances
      const fundingManager = new ethers.Contract(
        addresses.fundingManager,
        FUNDING_MANAGER_ABI,
        provider
      );

      const usdc = new ethers.Contract(
        addresses.usdc,
        USDC_ABI,
        provider
      );

      // Get campaign status
      const status = await fundingManager.getCampaignStatus(campaignId);
      
      // Get campaign goal (real target for closing)
      const campaignGoal = await fundingManager.getCampaignGoal(campaignId);
      
      // Get event token
      const eventToken = await fundingManager.getCampaignEventToken(campaignId);
      
      // Get EventToken name and symbol
      let tokenName = "Event Token";
      let tokenSymbol = "EVT";
      
      if (eventToken !== ethers.ZeroAddress) {
        try {
          const eventTokenContract = new ethers.Contract(
            eventToken,
            EVENT_TOKEN_ABI,
            provider
          );
          
          tokenName = await eventTokenContract.name();
          tokenSymbol = await eventTokenContract.symbol();
        } catch (err) {
          console.warn('Could not fetch EventToken name/symbol, using defaults');
        }
      }

      // Get pool information if campaign is funded (market is open)
      let poolKey: PoolKey | undefined = undefined;
      if (status.isFunded) {
        try {
          const poolData = await fundingManager.getCampaignPool(campaignId);
          poolKey = {
            currency0: poolData.currency0,
            currency1: poolData.currency1,
            fee: Number(poolData.fee),
            tickSpacing: Number(poolData.tickSpacing),
            hooks: poolData.hooks
          };
          
          // Log pool information to console
          console.log('🏊 Pool Information (Market Open):');
          console.log('  PoolKey:', poolKey);
          console.log('  Currency0:', poolKey.currency0);
          console.log('  Currency1:', poolKey.currency1);
          console.log('  Fee:', poolKey.fee);
          console.log('  Tick Spacing:', poolKey.tickSpacing);
          console.log('  Hooks:', poolKey.hooks);
          
          // Calculate and log PoolId
          const poolId = ethers.keccak256(ethers.AbiCoder.defaultAbiCoder().encode(
            ['address', 'address', 'uint24', 'int24', 'address'],
            [poolKey.currency0, poolKey.currency1, poolKey.fee, poolKey.tickSpacing, poolKey.hooks]
          ));
          console.log('  PoolId:', poolId);
          
        } catch (err) {
          console.warn('Could not fetch pool information:', err);
        }
      }
      
      // Get USDC decimals
      const usdcDecimals = await usdc.decimals();

      // Format amounts
      const raisedAmount = ethers.formatUnits(status.raisedAmount, usdcDecimals);
      const targetAmount = ethers.formatUnits(status.targetAmount, usdcDecimals);
      const campaignGoalFormatted = ethers.formatUnits(campaignGoal, usdcDecimals);
      const organizerDeposit = ethers.formatUnits(status.organizerDeposit, usdcDecimals);
      const protocolFeesCollected = ethers.formatUnits(status.protocolFeesCollected, usdcDecimals);


      // Calculate progress based on real campaign goal (not organizer target)
      const progress = campaignGoal > 0 
        ? Number((status.raisedAmount * BigInt(10000)) / campaignGoal) / 100 // Multiply by 10000, then divide by 100 to get 2 decimal places
        : 0;

      // Calculate time remaining
      const timeLeft = Number(status.timeLeft);
      const daysLeft = Math.floor(timeLeft / (24 * 60 * 60));
      const hoursLeft = Math.floor((timeLeft % (24 * 60 * 60)) / (60 * 60));

      const data: CampaignData = {
        isActive: status.isActive,
        isExpired: status.isExpired,
        isFunded: status.isFunded,
        timeLeft,
        raisedAmount,
        targetAmount,
        campaignGoal: campaignGoalFormatted,
        organizerDeposit,
        fundingToken: status.fundingToken,
        protocolFeesCollected,
        eventToken,
        uniqueBackers: Number(status.uniqueBackers),
        tokenName,
        tokenSymbol,
        progress,
        daysLeft,
        hoursLeft,
        poolKey
      };

      setCampaignData(data);
    } catch (err) {
      console.error('Error fetching campaign data:', err);
      setError(null); // No error message needed
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (isHydrated && campaignId !== undefined) {
      fetchCampaignData();
    }
  }, [isHydrated, campaignId]);

  return {
    campaignData,
    loading,
    error,
    refetch: fetchCampaignData
  };
};

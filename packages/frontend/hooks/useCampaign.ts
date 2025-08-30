import { useState, useEffect } from 'react';
import { ethers } from 'ethers';
import { CONTRACTS, DEFAULT_NETWORK } from '@/config/contracts';

// ABI for FundingManager contract (simplified for what we need)
const FUNDING_MANAGER_ABI = [
  "function getCampaignStatus(uint256 campaignId) external view returns (bool isActive, bool isExpired, bool isFunded, uint256 timeLeft, uint256 raisedAmount, uint256 targetAmount, uint256 organizerDeposit, address fundingToken, uint256 protocolFeesCollected, uint256 uniqueBackers)",
  "function getCampaignEventToken(uint256 campaignId) external view returns (address eventToken)"
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

export interface CampaignData {
  isActive: boolean;
  isExpired: boolean;
  isFunded: boolean;
  timeLeft: number;
  raisedAmount: string;
  targetAmount: string;
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
}

export const useCampaign = (campaignId: number = 0) => {
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
      
      // Get USDC decimals
      const usdcDecimals = await usdc.decimals();

      // Format amounts
      const raisedAmount = ethers.formatUnits(status.raisedAmount, usdcDecimals);
      const targetAmount = ethers.formatUnits(status.targetAmount, usdcDecimals);
      const organizerDeposit = ethers.formatUnits(status.organizerDeposit, usdcDecimals);
      const protocolFeesCollected = ethers.formatUnits(status.protocolFeesCollected, usdcDecimals);

      // Calculate progress
      const progress = status.targetAmount > 0 
        ? Number((status.raisedAmount * BigInt(100)) / status.targetAmount)
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
        organizerDeposit,
        fundingToken: status.fundingToken,
        protocolFeesCollected,
        eventToken,
        uniqueBackers: Number(status.uniqueBackers),
        tokenName,
        tokenSymbol,
        progress,
        daysLeft,
        hoursLeft
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
    fetchCampaignData();
  }, [campaignId]);

  return {
    campaignData,
    loading,
    error,
    refetch: fetchCampaignData
  };
};

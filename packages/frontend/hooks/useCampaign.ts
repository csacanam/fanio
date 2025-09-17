import { useState, useEffect } from 'react';
import { ethers, formatUnits, JsonRpcProvider, ZeroAddress, keccak256, AbiCoder } from 'ethers';
import { CONTRACTS, DEFAULT_NETWORK, getRpcUrl } from '@/config/contracts';
import { useHydration } from './useHydration';

// ABI for FundingManager contract (simplified for what we need)
const FUNDING_MANAGER_ABI = [
  "function getCampaignStatus(uint256 campaignId) external view returns (bool isActive, bool isExpired, bool isFunded, uint256 timeLeft, uint256 raisedAmount, uint256 targetAmount, uint256 organizerDeposit, address fundingToken, uint256 protocolFeesCollected, uint256 uniqueBackers)",
  "function getCampaignEventToken(uint256 campaignId) external view returns (address eventToken)",
  "function getCampaignGoal(uint256 campaignId) external view returns (uint256)",
  "function getCampaignPool(uint256 campaignId) external view returns (tuple(address currency0, address currency1, uint24 fee, int24 tickSpacing, address hooks) poolKey)"
];

// ABI for Uniswap V4 StateView contract
const STATE_VIEW_ABI = [
  "function getSlot0(bytes32 poolId) external view returns (uint160 sqrtPriceX96, int24 tick, uint8 protocolFee, uint8 lpFee)",
  "function getLiquidity(bytes32 poolId) external view returns (uint128 liquidity)"
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

export interface PoolSlot0 {
  sqrtPriceX96: string;
  tick: number;
  protocolFee: number;
  lpFee: number;
}

export interface PoolLiquidity {
  liquidity: string;
}

export interface PoolPrice {
  price1Per0: number;
  price0Per1: number;
}

// Helper function to calculate price from tick
function priceFromTick(tick: number, dec0: number, dec1: number): PoolPrice {
  const price1Per0 = Math.pow(1.0001, tick) * Math.pow(10, dec0 - dec1);
  return { price1Per0, price0Per1: 1 / price1Per0 };
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
  poolSlot0?: PoolSlot0; // Pool slot0 data when market is open
  poolLiquidity?: PoolLiquidity; // Pool liquidity data when market is open
  poolPrice?: PoolPrice; // Pool price calculated from tick when market is open
  isEventTokenCurrency0?: boolean; // Whether EventToken is currency0 in the pool
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
      const provider = new JsonRpcProvider(getRpcUrl(DEFAULT_NETWORK));
      
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
      
      if (eventToken !== ZeroAddress) {
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
      let poolSlot0: PoolSlot0 | undefined = undefined;
      let poolLiquidity: PoolLiquidity | undefined = undefined;
      let poolPrice: PoolPrice | undefined = undefined;
      let isEventTokenCurrency0: boolean | undefined = undefined;
      
      if (status.isFunded) {
        try {
          const poolData = await fundingManager.getCampaignPool(campaignId);
          console.log('🏊 Pool data from contract:', poolData);
          
          // Handle dynamic fee flag (0x800000 = 8388608)
          const DYNAMIC_FEE_FLAG = 0x800000; // 8388608 in decimal
          const isDynamicFee = Number(poolData.fee) === DYNAMIC_FEE_FLAG;
          
          poolKey = {
            currency0: poolData.currency0,
            currency1: poolData.currency1,
            fee: isDynamicFee ? DYNAMIC_FEE_FLAG : Number(poolData.fee),
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
          const poolId = keccak256(AbiCoder.defaultAbiCoder().encode(
            ['address', 'address', 'uint24', 'int24', 'address'],
            [poolKey.currency0, poolKey.currency1, poolKey.fee, poolKey.tickSpacing, poolKey.hooks]
          ));
          console.log('  PoolId:', poolId);
          
          // Get pool slot0 information using StateView
          try {
            const stateViewContract = new ethers.Contract(
              addresses.stateView,
              STATE_VIEW_ABI,
              provider
            );
            
            const slot0Data = await stateViewContract.getSlot0(poolId);
            poolSlot0 = {
              sqrtPriceX96: slot0Data.sqrtPriceX96.toString(),
              tick: Number(slot0Data.tick),
              protocolFee: Number(slot0Data.protocolFee),
              lpFee: Number(slot0Data.lpFee)
            };
            
            // Get pool liquidity
            const liquidityData = await stateViewContract.getLiquidity(poolId);
            poolLiquidity = {
              liquidity: liquidityData.toString()
            };
            
            // Calculate price from tick
            // We need to determine which token is which based on the pool key
            isEventTokenCurrency0 = poolKey.currency0.toLowerCase() === eventToken.toLowerCase();
            const eventTokenDecimals = 18; // EventToken always has 18 decimals
            const usdcDecimals = 6; // USDC has 6 decimals
            if (isEventTokenCurrency0) {
              // EventToken is currency0, USDC is currency1
              poolPrice = priceFromTick(poolSlot0.tick, eventTokenDecimals, usdcDecimals);
            } else {
              // USDC is currency0, EventToken is currency1
              poolPrice = priceFromTick(poolSlot0.tick, usdcDecimals, eventTokenDecimals);
            }
            
            // Log slot0 information to console
            console.log('📊 Pool Slot0 Information:');
            console.log('  sqrtPriceX96:', poolSlot0.sqrtPriceX96);
            console.log('  Tick:', poolSlot0.tick);
            console.log('  Protocol Fee:', poolSlot0.protocolFee);
            console.log('  LP Fee:', poolSlot0.lpFee);
            console.log('  Liquidity:', poolLiquidity.liquidity);
            
            // Log calculated price information
            if (poolPrice) {
              console.log('💰 Pool Price Information:');
              console.log('  Raw price1Per0:', poolPrice.price1Per0);
              console.log('  Raw price0Per1:', poolPrice.price0Per1);
              
              if (isEventTokenCurrency0) {
                // EventToken is currency0, USDC is currency1
                // price1Per0 = USDC per EventToken
                // price0Per1 = EventToken per USDC
                console.log('  USDC per EventToken:', poolPrice.price1Per0);
                console.log('  EventToken per USDC:', poolPrice.price0Per1);
              } else {
                // USDC is currency0, EventToken is currency1
                // price1Per0 = EventToken per USDC
                // price0Per1 = USDC per EventToken
                console.log('  EventToken per USDC:', poolPrice.price1Per0);
                console.log('  USDC per EventToken:', poolPrice.price0Per1);
              }
            }
            
          } catch (slot0Err) {
            console.warn('Could not fetch pool slot0 information:', slot0Err);
          }
          
        } catch (err) {
          console.warn('Could not fetch pool information:', err);
        }
      }
      
      // Get USDC decimals
      const usdcDecimals = await usdc.decimals();

      // Format amounts
      const raisedAmount = formatUnits(status.raisedAmount, usdcDecimals);
      const targetAmount = formatUnits(status.targetAmount, usdcDecimals);
      const campaignGoalFormatted = formatUnits(campaignGoal, usdcDecimals);
      const organizerDeposit = formatUnits(status.organizerDeposit, usdcDecimals);
      const protocolFeesCollected = formatUnits(status.protocolFeesCollected, usdcDecimals);


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
        poolKey,
        poolSlot0,
        poolLiquidity,
        poolPrice,
        isEventTokenCurrency0
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

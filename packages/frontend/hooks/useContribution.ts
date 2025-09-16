import { useState } from 'react';
import { ethers } from 'ethers';
import { CONTRACTS, DEFAULT_NETWORK, getExplorerUrl } from '@/config/contracts';

// ABI for FundingManager contract (simplified for contribution)
const FUNDING_MANAGER_ABI = [
  "function contribute(uint256 campaignId, uint256 amount) external",
  "function getCampaignStatus(uint256 campaignId) external view returns (bool isActive, bool isExpired, bool isFunded, uint256 timeLeft, uint256 raisedAmount, uint256 targetAmount, uint256 organizerDeposit, address fundingToken, uint256 protocolFeesCollected, uint256 uniqueBackers)"
];

// ABI for USDC contract (simplified for approval and transfer)
const USDC_ABI = [
  "function approve(address spender, uint256 amount) external returns (bool)",
  "function allowance(address owner, address spender) external view returns (uint256)",
  "function balanceOf(address owner) external view returns (uint256)",
  "function decimals() external view returns (uint8)"
];

export const useContribution = (campaignId: number = 0) => {
  const [isApproving, setIsApproving] = useState(false);
  const [isContributing, setIsContributing] = useState(false);
  const [isApproved, setIsApproved] = useState(false);
  const [approvalPending, setApprovalPending] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [transactionHash, setTransactionHash] = useState<string | null>(null);

  // Separate approve function
  const approveUSDC = async (amount: string, userAddress: string) => {
    try {
      setIsApproving(true);
      setError(null);
      setSuccess(null); // Reset success message
      setTransactionHash(null); // Reset transaction hash

      // Create provider and signer
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();

      // Get contract addresses
      const addresses = CONTRACTS[DEFAULT_NETWORK];
      
      // Create USDC contract instance
      const usdc = new ethers.Contract(
        addresses.usdc,
        USDC_ABI,
        signer
      );

      // Convert amount to wei (USDC has 6 decimals)
      const amountWei = ethers.parseUnits(amount, 6);

      // Check USDC balance
      const balance = await usdc.balanceOf(userAddress);
      console.log('User USDC balance:', ethers.formatUnits(balance, 6), 'USDC');
      console.log('Required amount:', amount, 'USDC');
      
      if (balance < amountWei) {
        throw new Error(`Insufficient USDC balance. You have ${ethers.formatUnits(balance, 6)} USDC, but trying to contribute ${amount} USDC.`);
      }

      // Check current allowance
      const currentAllowance = await usdc.allowance(userAddress, addresses.fundingManager);
      console.log('Current allowance:', ethers.formatUnits(currentAllowance, 6), 'USDC');
      
      // Always approve to ensure fresh allowance and proper state management
      console.log('Approving USDC spend...');
      setApprovalPending(true); // Set pending state
      
      const approveTx = await usdc.approve(addresses.fundingManager, amountWei);
      console.log('Approval transaction sent, waiting for confirmation...');
      
      // Wait for confirmation and get receipt
      const receipt = await approveTx.wait();
      console.log('Transaction receipt received:', receipt);
      
      // Poll for allowance update until confirmed or timeout
      console.log('Polling for allowance update...');
      let newAllowance;
      let attempts = 0;
      const maxAttempts = 10; // Maximum attempts to prevent infinite loop
      
      while (attempts < maxAttempts) {
        // Wait 1 second between attempts
        if (attempts > 0) {
          await new Promise(resolve => setTimeout(resolve, 1000));
        }
        
        newAllowance = await usdc.allowance(userAddress, addresses.fundingManager);
        console.log(`Allowance check ${attempts + 1}:`, ethers.formatUnits(newAllowance, 6), 'USDC');
        
        if (newAllowance >= amountWei) {
          console.log('Allowance confirmed successfully!');
          setIsApproved(true);
          setApprovalPending(false);
          return; // Exit early on success
        }
        
        attempts++;
        console.log(`Attempt ${attempts}/${maxAttempts}...`);
      }
      
      // If we get here, allowance was never confirmed
      console.log('Allowance never confirmed after all attempts');
      setApprovalPending(false);
      throw new Error('Approval confirmed but blockchain is taking time to update. Please wait a moment.');
    } catch (err: any) {
      console.error('Approval error:', err);
      
      // Provide user-friendly error messages
      let userMessage = 'Failed to approve USDC spend.';
      
      if (err.message) {
        if (err.message.includes('user rejected') || err.message.includes('User denied') || err.message.includes('ACTION_REJECTED')) {
          userMessage = 'Transaction was cancelled. Please try again when you\'re ready.';
        } else if (err.message.includes('insufficient funds')) {
          userMessage = 'Insufficient funds in your wallet. Please check your USDC balance.';
        } else if (err.message.includes('network error')) {
          userMessage = 'Network error. Please check your connection.';
        } else if (err.message.includes('allowance was never updated')) {
          userMessage = 'Approval confirmed but blockchain is taking time to update. Please wait a moment.';
        } else {
          userMessage = err.message;
        }
      }
      
      setError(userMessage);
      setApprovalPending(false); // Reset pending state on error
    } finally {
      setIsApproving(false);
    }
  };

  // Function to check and update allowance state
  const checkAllowanceState = async (userAddress: string, amount: string) => {
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const addresses = CONTRACTS[DEFAULT_NETWORK];
      
      const usdc = new ethers.Contract(
        addresses.usdc,
        USDC_ABI,
        signer
      );

      const amountWei = ethers.parseUnits(amount, 6);
      const currentAllowance = await usdc.allowance(userAddress, addresses.fundingManager);
      const hasEnoughAllowance = currentAllowance >= amountWei;
      
      console.log('Allowance check:', {
        current: ethers.formatUnits(currentAllowance, 6),
        required: amount,
        hasEnough: hasEnoughAllowance
      });
      
      // Update the approved state based on current allowance
      setIsApproved(hasEnoughAllowance);
      
      return hasEnoughAllowance;
    } catch (error) {
      console.error('Error checking allowance state:', error);
      setIsApproved(false);
      return false;
    }
  };

  const contribute = async (amount: string, userAddress: string) => {
    try {
      setIsContributing(true);
      setError(null);
      setSuccess(null);
      setTransactionHash(null); // Reset transaction hash

      // Create provider and signer
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();

      // Get contract addresses
      const addresses = CONTRACTS[DEFAULT_NETWORK];
      
      // Create contract instances
      const fundingManager = new ethers.Contract(
        addresses.fundingManager,
        FUNDING_MANAGER_ABI,
        signer
      );

      const usdc = new ethers.Contract(
        addresses.usdc,
        USDC_ABI,
        signer
      );

      // Convert amount to wei (USDC has 6 decimals)
      const amountWei = ethers.parseUnits(amount, 6);

      // Check current allowance and update state
      const hasEnoughAllowance = await checkAllowanceState(userAddress, amount);
      if (!hasEnoughAllowance) {
        throw new Error('Insufficient USDC allowance. Please approve USDC spend first.');
      }

      // Make contribution
      console.log(`Contributing ${amount} USDC to campaign ${campaignId}...`);
      console.log('Campaign ID:', campaignId);
      console.log('Amount in wei:', amountWei.toString());
      console.log('FundingManager address:', addresses.fundingManager);
      
      // Additional validation: Check if campaign is still active
      try {
        const campaignStatus = await fundingManager.getCampaignStatus(campaignId);
        console.log('Campaign status:', campaignStatus);
        
        if (!campaignStatus.isActive) {
          throw new Error('Campaign is no longer active. Please check the campaign status.');
        }
        
        if (campaignStatus.isExpired) {
          throw new Error('Campaign has expired. Contributions are no longer accepted.');
        }
        
        if (campaignStatus.isFunded) {
          throw new Error('Campaign is already fully funded. No more contributions needed.');
        }
      } catch (statusError: any) {
        if (statusError.message.includes('Campaign')) {
          throw statusError; // Re-throw our custom campaign errors
        }
        console.warn('Could not verify campaign status, proceeding with contribution...');
      }
      
      const contributeTx = await fundingManager.contribute(campaignId, amountWei);
      
      // Wait for confirmation
      const receipt = await contributeTx.wait();
      console.log('Contribution confirmed - Full receipt:', receipt);
      
      // Get transaction hash safely
      const txHash = receipt?.hash || receipt?.transactionHash || 'Unknown';
      console.log('Transaction hash:', txHash);

      // Poll for raised amount update until confirmed or timeout
      console.log('Polling for raised amount update...');
      let newRaisedAmount;
      let attempts = 0;
      const maxAttempts = 15; // Increased attempts for better reliability
      const baseDelay = 2000; // Start with 2 seconds delay
      
      // Get initial raised amount for comparison
      const initialStatus = await fundingManager.getCampaignStatus(campaignId);
      const initialRaisedAmount = initialStatus.raisedAmount;
      console.log('Initial raised amount:', ethers.formatUnits(initialRaisedAmount, 6), 'USDC');
      
      while (attempts < maxAttempts) {
        // Wait with increasing delay for better reliability
        if (attempts > 0) {
          const delay = baseDelay + (attempts * 1000); // 2s, 3s, 4s, 5s...
          console.log(`Waiting ${delay}ms before attempt ${attempts + 1}...`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
        
        const campaignStatus = await fundingManager.getCampaignStatus(campaignId);
        newRaisedAmount = campaignStatus.raisedAmount;
        console.log(`Raised amount check ${attempts + 1}:`, ethers.formatUnits(newRaisedAmount, 6), 'USDC');
        
        // Check if raised amount increased by at least our contribution
        if (newRaisedAmount >= initialRaisedAmount + amountWei) {
          console.log('Contribution confirmed successfully!');
          setTransactionHash(txHash);
          setSuccess(`Successfully contributed ${amount} USDC!`);
          return; // Exit early on success
        }
        
        attempts++;
        console.log(`Attempt ${attempts}/${maxAttempts}...`);
      }
      
      // If we get here, raised amount was never confirmed
      console.log('Contribution never confirmed after all attempts');
      throw new Error('Contribution confirmed but blockchain is taking time to update. Please wait a moment.');

    } catch (err: any) {
      console.error('Contribution error:', err);
      
      // Translate technical errors to user-friendly messages
      let userMessage = 'Failed to contribute.';
      
      if (err.message) {
        if (err.message.includes('execution reverted')) {
          // Check for specific contract error messages from FundingManager
          if (err.message.includes('Contribution would exceed maximum allowed amount')) {
            userMessage = 'This contribution would exceed the campaign goal. The campaign closes when it reaches 130 USDC.';
          } else if (err.message.includes('Campaign is not active')) {
            userMessage = 'This campaign is no longer active. Contributions are not accepted.';
          } else if (err.message.includes('Campaign already funded')) {
            userMessage = 'This campaign is already fully funded. No more contributions needed.';
          } else if (err.message.includes('Amount must be positive')) {
            userMessage = 'Contribution amount must be greater than 0.';
          } else if (err.message.includes('Transfer failed')) {
            userMessage = 'USDC transfer failed. Please check your balance.';
          } else if (err.message.includes('Deposit transfer failed')) {
            userMessage = 'Deposit transfer failed. Please check your balance.';
          } else if (err.message.includes('Target amount must be positive')) {
            userMessage = 'Invalid campaign configuration.';
          } else if (err.message.includes('Duration must be positive')) {
            userMessage = 'Invalid campaign configuration.';
          } else if (err.message.includes('Invalid funding token')) {
            userMessage = 'Invalid campaign configuration.';
          } else if (err.message.includes('Invalid protocol wallet')) {
            userMessage = 'Invalid contract configuration.';
          } else if (err.message.includes('Invalid funding manager address')) {
            userMessage = 'Invalid token configuration.';
          } else if (err.message.includes('Cannot mint to zero address')) {
            userMessage = 'Token minting failed.';
          } else if (err.message.includes('Exceeds max supply')) {
            userMessage = 'Token minting failed.';
          } else if (err.message.includes('Only FundingManager can mint')) {
            userMessage = 'Token minting failed.';
          } else {
            userMessage = 'The transaction failed. Please check the campaign status.';
          }
        } else if (err.message.includes('insufficient funds')) {
          userMessage = 'Insufficient funds in your wallet. Please check your USDC balance.';
        } else if (err.message.includes('user rejected') || err.message.includes('User denied') || err.message.includes('ACTION_REJECTED')) {
          userMessage = 'Transaction was cancelled.';
        } else if (err.message.includes('network error')) {
          userMessage = 'Network error. Please check your connection.';
        } else if (err.message.includes('insufficient allowance')) {
          userMessage = 'USDC approval required. Please approve USDC spend first.';
        } else {
          userMessage = err.message;
        }
      }
      
      setError(userMessage);
    } finally {
      setIsContributing(false);
    }
  };

  const resetMessages = () => {
    setError(null);
    setSuccess(null);
  };

  // Function to check allowance when amount changes
  const checkAllowanceForAmount = async (amount: string, userAddress: string) => {
    if (!amount || parseFloat(amount) <= 0 || !userAddress) return;
    
    try {
      await checkAllowanceState(userAddress, amount);
    } catch (error) {
      console.error('Error checking allowance for amount:', error);
    }
  };

  return {
    contribute,
    approveUSDC,
    checkAllowanceForAmount,
    isApproving,
    isContributing,
    isApproved,
    approvalPending,
    error,
    success,
    resetMessages,
    transactionHash,
    explorerUrl: getExplorerUrl(DEFAULT_NETWORK)
  };
};

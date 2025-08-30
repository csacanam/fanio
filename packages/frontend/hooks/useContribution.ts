import { useState } from 'react';
import { ethers } from 'ethers';
import { CONTRACTS, DEFAULT_NETWORK } from '@/config/contracts';

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

  // Separate approve function
  const approveUSDC = async (amount: string, userAddress: string) => {
    try {
      setIsApproving(true);
      setError(null);

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
      throw new Error('Approval transaction confirmed but allowance was never updated. Please try again.');
    } catch (err: any) {
      console.error('Approval error:', err);
      
      // Provide user-friendly error messages
      let userMessage = 'Failed to approve USDC spend. Please try again.';
      
      if (err.message) {
        if (err.message.includes('user rejected') || err.message.includes('User denied') || err.message.includes('ACTION_REJECTED')) {
          userMessage = 'Transaction was cancelled. Please try again when you\'re ready.';
        } else if (err.message.includes('insufficient funds')) {
          userMessage = 'Insufficient funds in your wallet. Please check your USDC balance.';
        } else if (err.message.includes('network error')) {
          userMessage = 'Network error. Please check your connection and try again.';
        } else if (err.message.includes('allowance was never updated')) {
          userMessage = 'Approval confirmed but blockchain is taking time to update. Please wait a moment and try again.';
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

  const contribute = async (amount: string, userAddress: string) => {
    try {
      setIsContributing(true);
      setError(null);
      setSuccess(null);

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

      // Check current allowance
      const currentAllowance = await usdc.allowance(userAddress, addresses.fundingManager);
      console.log('Current allowance:', ethers.formatUnits(currentAllowance, 6), 'USDC');
      
      // Verify we have sufficient allowance
      if (currentAllowance < amountWei) {
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
      console.log('Receipt type:', typeof receipt);
      console.log('Receipt keys:', Object.keys(receipt || {}));
      
      // Get transaction hash safely
      const txHash = receipt?.hash || receipt?.transactionHash || 'Unknown';
      console.log('Transaction hash:', txHash);

      setSuccess(`Successfully contributed ${amount} USDC! Transaction: ${txHash.slice(0, 10)}...`);

    } catch (err: any) {
      console.error('Contribution error:', err);
      
      // Translate technical errors to user-friendly messages
      let userMessage = 'Failed to contribute. Please try again.';
      
      if (err.message) {
        if (err.message.includes('execution reverted')) {
          userMessage = 'The transaction failed. This usually means the campaign is no longer active or there was an issue with the contract. Please try again or contact support.';
        } else if (err.message.includes('insufficient funds')) {
          userMessage = 'Insufficient funds in your wallet. Please check your USDC balance.';
        } else if (err.message.includes('user rejected') || err.message.includes('User denied') || err.message.includes('ACTION_REJECTED')) {
          userMessage = 'Transaction was cancelled. Please try again when you\'re ready.';
        } else if (err.message.includes('network error')) {
          userMessage = 'Network error. Please check your connection and try again.';
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

  return {
    contribute,
    approveUSDC,
    isApproving,
    isContributing,
    isApproved,
    approvalPending,
    error,
    success,
    resetMessages
  };
};

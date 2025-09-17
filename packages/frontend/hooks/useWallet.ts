import { useState, useEffect } from 'react';
import { ethers } from 'ethers';

// Network configuration - easy to change for future multichain support
export const SUPPORTED_NETWORKS = {
  baseSepolia: {
    chainId: '0x14a34', // 84532 in hex
    chainName: 'Base Sepolia',
    rpcUrl: 'https://sepolia.base.org',
    blockExplorer: 'https://sepolia.basescan.org',
    nativeCurrency: {
      name: 'ETH',
      symbol: 'ETH',
      decimals: 18
    }
  }
  // Future networks can be added here:
  // polygon: { ... },
  // arbitrum: { ... }
};

export const DEFAULT_NETWORK = 'baseSepolia';

export interface WalletState {
  isConnected: boolean;
  address: string | null;
  network: string | null;
  isCorrectNetwork: boolean;
  isConnecting: boolean;
  error: string | null;
  signer: ethers.Signer | null;
}

export const useWallet = () => {
  const [walletState, setWalletState] = useState<WalletState>({
    isConnected: false,
    address: null,
    network: null,
    isCorrectNetwork: false,
    isConnecting: false,
    error: null,
    signer: null
  });

  // Check if MetaMask is installed
  const isMetaMaskInstalled = () => {
    return typeof window !== 'undefined' && window.ethereum && window.ethereum.isMetaMask;
  };

  // Add mounted state to prevent hydration mismatch
  const [mounted, setMounted] = useState(false);

  // Get current network info
  const getCurrentNetwork = async () => {
    if (!window.ethereum) return null;
    
    try {
      const chainId = await window.ethereum.request({ method: 'eth_chainId' });
      return chainId;
    } catch (error) {
      console.error('Error getting current network:', error);
      return null;
    }
  };

  // Check if current network is supported
  const checkNetworkSupport = (chainId: string) => {
    const supportedChainIds = Object.values(SUPPORTED_NETWORKS).map(network => network.chainId);
    return supportedChainIds.includes(chainId);
  };

  // Switch to Base Sepolia network
  const switchToBaseSepolia = async () => {
    if (!window.ethereum) {
      throw new Error('MetaMask is not installed');
    }

    try {
      const network = SUPPORTED_NETWORKS[DEFAULT_NETWORK];
      
      // Try to switch network
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: network.chainId }]
      });
      
      return true;
    } catch (switchError: any) {
      // If the network doesn't exist, add it
      if (switchError.code === 4902) {
        try {
          const network = SUPPORTED_NETWORKS[DEFAULT_NETWORK];
          
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [{
              chainId: network.chainId,
              chainName: network.chainName,
              rpcUrls: [network.rpcUrl],
              blockExplorerUrls: [network.blockExplorer],
              nativeCurrency: network.nativeCurrency
            }]
          });
          
          return true;
        } catch (addError) {
          throw new Error('Failed to add Base Sepolia network to MetaMask');
        }
      } else {
        throw new Error('Failed to switch to Base Sepolia network');
      }
    }
  };

  // Connect wallet
  const connectWallet = async () => {
    if (!isMetaMaskInstalled()) {
      setWalletState(prev => ({
        ...prev,
        error: 'MetaMask is not installed. Please install MetaMask to continue.'
      }));
      return;
    }

    try {
      setWalletState(prev => ({ ...prev, isConnecting: true, error: null }));

      // Request account access
      const accounts = await window.ethereum!.request({ method: 'eth_requestAccounts' });
      const address = accounts[0];

      // Get current network
      const currentChainId = await getCurrentNetwork();
      const isCorrectNetwork = checkNetworkSupport(currentChainId || '');

      // Create provider and signer
      const provider = new ethers.BrowserProvider(window.ethereum!);
      const signer = await provider.getSigner();

      setWalletState({
        isConnected: true,
        address,
        network: currentChainId,
        isCorrectNetwork,
        isConnecting: false,
        error: null,
        signer
      });

      // If not on correct network, switch automatically
      if (!isCorrectNetwork) {
        await switchToBaseSepolia();
        // Update state after switch
        const newChainId = await getCurrentNetwork();
        setWalletState(prev => ({
          ...prev,
          network: newChainId,
          isCorrectNetwork: checkNetworkSupport(newChainId || '')
        }));
      }

    } catch (error: any) {
      setWalletState(prev => ({
        ...prev,
        isConnecting: false,
        error: error.message || 'Failed to connect wallet'
      }));
    }
  };

  // Disconnect wallet
  const disconnectWallet = () => {
    setWalletState({
      isConnected: false,
      address: null,
      network: null,
      isCorrectNetwork: false,
      isConnecting: false,
      error: null,
      signer: null
    });
  };

  // Listen for account changes
  useEffect(() => {
    if (!window.ethereum) return;

    const handleAccountsChanged = (accounts: string[]) => {
      if (accounts.length === 0) {
        // User disconnected
        disconnectWallet();
      } else {
        // Account changed
        setWalletState(prev => ({
          ...prev,
          address: accounts[0]
        }));
      }
    };

    const handleChainChanged = async () => {
      // Reload page when chain changes (MetaMask requirement)
      window.location.reload();
    };

    window.ethereum!.on('accountsChanged', handleAccountsChanged);
    window.ethereum!.on('chainChanged', handleChainChanged);

    return () => {
      window.ethereum!.removeListener('accountsChanged', handleAccountsChanged);
      window.ethereum!.removeListener('chainChanged', handleChainChanged);
    };
  }, []);

  // Mark component as mounted to prevent hydration mismatch
  useEffect(() => {
    setMounted(true);
  }, []);

  // Check initial connection state
  useEffect(() => {
    if (!mounted) return; // Don't run until mounted
    
    const checkInitialState = async () => {
      if (!isMetaMaskInstalled()) return;

      try {
        const accounts = await window.ethereum!.request({ method: 'eth_accounts' });
        if (accounts.length > 0) {
          const address = accounts[0];
          const currentChainId = await getCurrentNetwork();
          const isCorrectNetwork = checkNetworkSupport(currentChainId || '');

          // Create provider and signer
          const provider = new ethers.BrowserProvider(window.ethereum!);
          const signer = await provider.getSigner();

          setWalletState({
            isConnected: true,
            address,
            network: currentChainId,
            isCorrectNetwork,
            isConnecting: false,
            error: null,
            signer
          });
        }
      } catch (error) {
        console.error('Error checking initial wallet state:', error);
      }
    };

    checkInitialState();
  }, [mounted]);

  // Return safe values during SSR to prevent hydration mismatch
  if (!mounted) {
    return {
      isConnected: false,
      address: null,
      network: null,
      isCorrectNetwork: false,
      isConnecting: false,
      error: null,
      signer: null,
      connectWallet: () => {},
      disconnectWallet: () => {},
      switchToBaseSepolia: async () => false,
      isMetaMaskInstalled: () => false
    };
  }

  return {
    ...walletState,
    connectWallet,
    disconnectWallet,
    switchToBaseSepolia,
    isMetaMaskInstalled
  };
};

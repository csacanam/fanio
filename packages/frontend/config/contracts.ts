// Auto-generated contract configuration
// Updated on: 2025-08-30T19:30:00.493Z
// Network: Base Sepolia

export const CONTRACTS = {
  local: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder for local
    usdc: "0x0000000000000000000000000000000000000000" // Placeholder for local
  },
  baseSepolia: {
    fundingManager: "0x6323521927814f819ab99c7c46d75944c77467ae",
    usdc: "0x7de9a0c146Cc6A92F2592C5E4e2331B263De88B1"
  }
} as const;

export type Network = keyof typeof CONTRACTS;
export type ContractAddresses = typeof CONTRACTS[Network];

// Helper function to get current network addresses
export const getContractAddresses = (network: Network): ContractAddresses => {
  return CONTRACTS[network];
};

// Default to Base Sepolia for now
export const DEFAULT_NETWORK: Network = "baseSepolia";

// Network explorer URLs
export const EXPLORERS = {
  local: "http://localhost:8545", // Placeholder for local
  baseSepolia: "https://sepolia.basescan.org"
} as const;

// Helper function to get explorer URL for a network
export const getExplorerUrl = (network: Network): string => {
  return EXPLORERS[network];
};

// Auto-generated contract configuration
// Updated on: 2025-08-31T13:19:17.533Z
// Network: Base Sepolia

export const CONTRACTS = {
  local: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder for local
    usdc: "0x0000000000000000000000000000000000000000" // Placeholder for local
  },
  baseSepolia: {
    fundingManager: "0x9df821771376a87c7e6d3a9f210c962b406722ff",
    usdc: "0x036CbD53842c5426634e7929541eC2318f3dCF7e"
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

export const EXPLORERS = {
  local: "http://localhost:8545", // Placeholder for local
  baseSepolia: "https://sepolia.basescan.org"
} as const;

export const getExplorerUrl = (network: Network): string => {
  return EXPLORERS[network];
};

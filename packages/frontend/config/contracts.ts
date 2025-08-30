// Auto-generated contract configuration
// Updated on: 2025-08-30T18:10:15.321Z
// Network: Base Sepolia

export const CONTRACTS = {
  local: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder for local
    usdc: "0x0000000000000000000000000000000000000000" // Placeholder for local
  },
  baseSepolia: {
    fundingManager: "0x7ee59a734175464de7ca9f54d7b199b4e2d19e01",
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

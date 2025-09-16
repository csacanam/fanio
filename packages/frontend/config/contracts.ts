// Auto-generated contract configuration
// Updated on: 2025-09-16T03:06:28.469Z
// Network: Base Sepolia (84532)

export const CONTRACTS = {
  local: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder for local
    usdc: "0x0000000000000000000000000000000000000000", // Placeholder for local
    stateView: "0x0000000000000000000000000000000000000000" // Placeholder for local
  },
  baseSepolia: {
    fundingManager: "0x4b840c5893f32420966421678cbeaa01894dde03",
    usdc: "0xC8310baA6444e135f7BC54D698F0EE32Fa0621a3",
    stateView: "0x571291b572ed32ce6751a2cb2486ebee8defb9b4"
  },
  baseMainnet: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder
    usdc: "0x0000000000000000000000000000000000000000", // Placeholder
    stateView: "0x0000000000000000000000000000000000000000" // Placeholder
  },
  ethereumMainnet: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder
    usdc: "0x0000000000000000000000000000000000000000", // Placeholder
    stateView: "0x0000000000000000000000000000000000000000" // Placeholder
  },
  sepolia: {
    fundingManager: "0x0000000000000000000000000000000000000000", // Placeholder
    usdc: "0x0000000000000000000000000000000000000000", // Placeholder
    stateView: "0x0000000000000000000000000000000000000000" // Placeholder
  }
} as const;

export type Network = keyof typeof CONTRACTS;
export type ContractAddresses = typeof CONTRACTS[Network];

// Helper function to get current network addresses
export const getContractAddresses = (network: Network): ContractAddresses => {
  return CONTRACTS[network];
};

// Default to the deployed network
export const DEFAULT_NETWORK: Network = "baseSepolia";

export const EXPLORERS = {
  local: "http://localhost:8545",
  baseSepolia: "https://sepolia.basescan.org",
  baseMainnet: "https://basescan.org",
  ethereumMainnet: "https://etherscan.io",
  sepolia: "https://sepolia.etherscan.io"
} as const;

export const RPC_URLS = {
  local: "http://localhost:8545",
  baseSepolia: "https://sepolia.base.org",
  baseMainnet: "https://mainnet.base.org",
  ethereumMainnet: "https://eth.llamarpc.com",
  sepolia: "https://sepolia.llamarpc.com"
} as const;

export const getExplorerUrl = (network: Network): string => {
  return EXPLORERS[network];
};

export const getRpcUrl = (network: Network): string => {
  return RPC_URLS[network];
};

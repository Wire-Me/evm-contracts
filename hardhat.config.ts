import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'dotenv/config'
import "./scripts/deploy/deployAllTask"
import "./scripts/deploy/deployTokensTask"

const sepoliaAccounts = [process.env.SEPOLIA_PRIVATE_KEY_1, process.env.SEPOLIA_PRIVATE_KEY_2]
  .filter((key): key is string => Boolean(key));

const baseAccounts = [process.env.BASE_PRIVATE_KEY_1, process.env.BASE_PRIVATE_KEY_2]
  .filter((key): key is string => Boolean(key));

const bscTestnetAccounts = [process.env.BSC_TESTNET_PRIVATE_KEY_1]
  .filter((key): key is string => Boolean(key));

const bscAccounts = [process.env.BSC_PRIVATE_KEY_1]
  .filter((key): key is string => Boolean(key));

const config: HardhatUserConfig = {
  // localhost by default - see deployAllTask.ts for the check that fails fast with a clear
  // error if nothing's actually listening there instead of a cryptic connection error.
  defaultNetwork: "localhost",
  // Keep these settings in sync with contracts-manager's hardhat.config.ts and foundry.toml -
  // they govern the real deployed bytecode size (FxEscrowMulti doesn't fit under EIP-170
  // without the optimizer on) and evm target. See README.md's Deployment section for why.
  solidity: {
    version: "0.8.30",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    sepolia: {
      // No RPC key in source (this repo is public): set SEPOLIA_RPC_URL in .env, else a public endpoint is used.
      url: process.env.SEPOLIA_RPC_URL || "https://ethereum-sepolia-rpc.publicnode.com",
      accounts: sepoliaAccounts
    },
    localhost: {
      url: process.env.ETH_LOCAL_NODE_URL || "http://127.0.0.1:8545", // when deploying to localhost deploy to the ETH node container
    },
    base: {
      chainId: 8453,
      url: process.env.BASE_RPC_URL || "https://mainnet.base.org",
      accounts: baseAccounts
    },
    bscTestnet: {
      chainId: 97,
      url: process.env.BSC_TESTNET_RPC_URL || "https://data-seed-prebsc-1-s1.bnbchain.org:8545",
      accounts: bscTestnetAccounts
    },
    bsc: {
      chainId: 56,
      url: process.env.BSC_RPC_URL || "https://bsc-dataseed.bnbchain.org",
      accounts: bscAccounts
    }
  },
  paths: {
    sources: "./src"
  }
};

export default config;

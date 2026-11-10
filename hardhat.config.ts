import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'dotenv/config'

const config: HardhatUserConfig = {
  solidity: "0.8.23",
  networks: {
    sepolia: {
      // No RPC key in source (this repo is public): set SEPOLIA_RPC_URL in .env, else a public endpoint is used.
      url: process.env.SEPOLIA_RPC_URL || "https://ethereum-sepolia-rpc.publicnode.com",
      accounts: [`${process.env.SEPOLIA_PRIVATE_KEY_1}`,`${process.env.SEPOLIA_PRIVATE_KEY_2}`]
    },
    localhost: {
      url: process.env.ETH_LOCAL_NODE_URL, // when deploying to localhost deploy to the ETH node container
    }
  },
  paths: {
    sources: "./lib"
  }
};

export default config;

import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'dotenv/config'

const config: HardhatUserConfig = {
  solidity: "0.8.23",
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/16a91573c45d4467b517aba983248451",
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

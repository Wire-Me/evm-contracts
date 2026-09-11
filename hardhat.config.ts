import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import 'dotenv/config'
import "./scripts/deploy/deployAllTask"

const sepoliaAccounts = [process.env.SEPOLIA_PRIVATE_KEY_1, process.env.SEPOLIA_PRIVATE_KEY_2]
  .filter((key): key is string => Boolean(key));

const config: HardhatUserConfig = {
  solidity: "0.8.30",
  networks: {
    sepolia: {
      url: "https://sepolia.infura.io/v3/16a91573c45d4467b517aba983248451",
      accounts: sepoliaAccounts
    },
    localhost: {
      url: process.env.ETH_LOCAL_NODE_URL || "http://127.0.0.1:8545", // when deploying to localhost deploy to the ETH node container
    }
  },
  paths: {
    sources: "./src"
  }
};

export default config;

import type { HardhatRuntimeEnvironment } from "hardhat/types";
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

export interface DeployTestStablecoinParams {
  name: string;
  symbol: string;
  decimals: number;
}

/// Deploys a TestStablecoin - a stand-in for USDC/USDT on chains without the real token. See
/// TestStablecoin.sol: not for mainnet, where the canonical tokens already exist.
export async function deployTestStablecoin(
  hre: HardhatRuntimeEnvironment,
  signer: HardhatEthersSigner,
  params: DeployTestStablecoinParams,
) {
  const factory = await hre.ethers.getContractFactory("TestStablecoin", signer);
  const contract = await factory.deploy(params.name, params.symbol, params.decimals);
  await contract.waitForDeployment();
  return contract;
}

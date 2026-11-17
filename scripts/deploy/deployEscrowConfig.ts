import type { HardhatRuntimeEnvironment } from "hardhat/types";
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

export interface DeployEscrowConfigParams {
  usdcErc20Address: string;
  usdtErc20Address: string;
}

/// Deploys EscrowConfig, which maps a token symbol to its ERC20 contract address for
/// FxEscrowMulti / ProxyFxEscrowMulti to read from.
export async function deployEscrowConfig(
  hre: HardhatRuntimeEnvironment,
  signer: HardhatEthersSigner,
  params: DeployEscrowConfigParams,
) {
  const factory = await hre.ethers.getContractFactory("EscrowConfig", signer);
  const contract = await factory.deploy(params.usdcErc20Address, params.usdtErc20Address);
  await contract.waitForDeployment();
  return contract;
}

import type { HardhatRuntimeEnvironment } from "hardhat/types";
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

export interface DeployWalletConfigParams {
  fxEscrowMultiContractAddress: string;
  usdcErc20Address: string;
  usdtErc20Address: string;
}

/// Deploys WalletConfig - tells a SmartWalletMulti proxy which escrow contract and ERC20
/// tokens it should use. Deploy the escrow (ProxyFxEscrowMulti) first; its address is a
/// constructor arg here.
export async function deployWalletConfig(
  hre: HardhatRuntimeEnvironment,
  signer: HardhatEthersSigner,
  params: DeployWalletConfigParams,
) {
  const factory = await hre.ethers.getContractFactory("WalletConfig", signer);
  const contract = await factory.deploy(
    params.fxEscrowMultiContractAddress,
    params.usdcErc20Address,
    params.usdtErc20Address,
  );
  await contract.waitForDeployment();
  return contract;
}

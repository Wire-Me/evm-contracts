import type { HardhatRuntimeEnvironment } from "hardhat/types";
import type { Signer } from "ethers";

export interface DeployProxySmartWalletMultiParams {
  implementationAddress: string;
  adminAddress: string;
  walletConfigAddress: string;
}

/// Deploys a ProxySmartWalletMulti - one per user/broker. Deprecated (see README.md); kept for
/// the existing tx-conductor-driven wallet-per-user flow, not for new usage.
export async function deployProxySmartWalletMulti(
  hre: HardhatRuntimeEnvironment,
  signer: Signer,
  params: DeployProxySmartWalletMultiParams,
) {
  const factory = await hre.ethers.getContractFactory("ProxySmartWalletMulti", signer);
  const contract = await factory.deploy(
    params.implementationAddress,
    params.adminAddress,
    params.walletConfigAddress,
  );
  await contract.waitForDeployment();
  return contract;
}

import type { HardhatRuntimeEnvironment } from "hardhat/types";
import type { Signer } from "ethers";

/// Deploys the SmartWalletMulti implementation contract. Deprecated in favor of Openfort
/// embedded wallets (see README.md), but still needed - tx-conductor still deploys a
/// ProxySmartWalletMulti per user/broker pointing at this implementation. Takes no constructor
/// args; per-wallet state lives on the proxy.
export async function deploySmartWalletMulti(hre: HardhatRuntimeEnvironment, signer: Signer) {
  const factory = await hre.ethers.getContractFactory("SmartWalletMulti", signer);
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  return contract;
}

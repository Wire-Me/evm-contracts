import type { HardhatRuntimeEnvironment } from "hardhat/types";
import type { Signer } from "ethers";

/// Deploys the FxEscrowMulti implementation contract. Takes no constructor args - all
/// per-deployment state (admin, config, broker deposit params) lives on the proxy, set in
/// ProxyFxEscrowMulti's constructor instead. Deploy once per implementation upgrade, then point
/// existing proxies at it via setImplementation.
export async function deployFxEscrowMulti(hre: HardhatRuntimeEnvironment, signer: Signer) {
  const factory = await hre.ethers.getContractFactory("FxEscrowMulti", signer);
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  return contract;
}

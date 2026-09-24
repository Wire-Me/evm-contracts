import type { HardhatRuntimeEnvironment } from "hardhat/types";
import type { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

export interface DeployProxyFxEscrowMultiParams {
  implementationAddress: string;
  adminAddress: string;
  escrowConfigAddress: string;
  brokerDepositAmount: bigint | number;
  expirationDurationForNonBrokers: bigint | number;
}

/// Deploys ProxyFxEscrowMulti - the contract actually used in production, delegatecalling into
/// whichever FxEscrowMulti implementation address it's pointed at.
///
/// The constructor takes 5 args (implementation, admin, config, brokerDepositAmount,
/// expirationDurationForNonBrokers) - see ProxyFxEscrowMulti.sol. Keep this function's
/// signature and the .sol constructor in sync in the same change; this is the single source of
/// truth callers (contracts-manager included) should use instead of hand-rolling the arg list.
export async function deployProxyFxEscrowMulti(
  hre: HardhatRuntimeEnvironment,
  signer: HardhatEthersSigner,
  params: DeployProxyFxEscrowMultiParams,
) {
  const factory = await hre.ethers.getContractFactory("ProxyFxEscrowMulti", signer);
  const contract = await factory.deploy(
    params.implementationAddress,
    params.adminAddress,
    params.escrowConfigAddress,
    params.brokerDepositAmount,
    params.expirationDurationForNonBrokers,
  );
  await contract.waitForDeployment();
  return contract;
}

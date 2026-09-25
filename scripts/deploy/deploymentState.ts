import { existsSync, readFileSync, writeFileSync } from "fs";
import { resolve } from "path";
import type { HardhatRuntimeEnvironment } from "hardhat/types";

export const STATE_FILE_NAME = "deployments.json";
export const STATE_FILE_PATH = resolve(__dirname, "../..", STATE_FILE_NAME);

/// Addresses of the ERC20s this network's escrow is configured against, keyed by token symbol.
/// On local/testnet these are TestStablecoin deployments; on mainnet they're the canonical
/// USDC/USDT contracts, which this repo never deploys.
export type TokenAddresses = Record<string, string>;

/// Addresses of the WireMe contracts deployed to this network, keyed by contract name.
export type ContractAddresses = Record<string, string>;

export interface NetworkDeploymentState {
  chainId?: number;
  updatedAt?: string;
  tokens?: TokenAddresses;
  contracts?: ContractAddresses;
}

export type DeploymentState = Record<string, NetworkDeploymentState>;

/// Reads the state file, returning an empty state if it doesn't exist yet - the deploy tasks
/// create it on first write rather than requiring it to be seeded by hand.
export function readDeploymentState(): DeploymentState {
  if (!existsSync(STATE_FILE_PATH)) {
    return {};
  }

  const raw = readFileSync(STATE_FILE_PATH, "utf8").trim();
  if (raw === "") {
    return {};
  }

  try {
    return JSON.parse(raw) as DeploymentState;
  } catch (err) {
    throw new Error(
      `${STATE_FILE_NAME} exists but isn't valid JSON (${(err as Error).message}). ` +
      `Fix or delete it - the deploy tasks recreate it from scratch if it's missing.`,
    );
  }
}

export function readNetworkState(network: string): NetworkDeploymentState {
  return readDeploymentState()[network] ?? {};
}

export function stateFileExists(): boolean {
  return existsSync(STATE_FILE_PATH);
}

/// Merges `entry` into the given network's record and writes the file back. Merging rather than
/// replacing means recording tokens doesn't wipe previously recorded contracts, and vice versa.
export function recordDeployment(network: string, entry: NetworkDeploymentState): void {
  const state = readDeploymentState();
  const existing = state[network] ?? {};

  state[network] = {
    ...existing,
    ...entry,
    tokens: { ...existing.tokens, ...entry.tokens },
    contracts: { ...existing.contracts, ...entry.contracts },
    updatedAt: new Date().toISOString(),
  };

  writeFileSync(STATE_FILE_PATH, `${JSON.stringify(state, null, 2)}\n`, "utf8");
}

/// Splits recorded addresses into those that actually have bytecode on the connected chain and
/// those that don't. A recorded address with no code almost always means the chain was reset
/// (restarting `hardhat node` wipes state while the file keeps the old addresses), so the caller
/// can tell the difference between "already deployed" and "stale record".
export async function partitionByOnChainCode(
  hre: HardhatRuntimeEnvironment,
  addresses: Record<string, string>,
): Promise<{ live: Record<string, string>; stale: Record<string, string> }> {
  const live: Record<string, string> = {};
  const stale: Record<string, string> = {};

  for (const [name, address] of Object.entries(addresses)) {
    const code = await hre.ethers.provider.getCode(address);
    const hasContractCode = code !== "0x";

    if (hasContractCode) {
      live[name] = address;
    } else {
      stale[name] = address;
    }
  }

  return { live, stale };
}

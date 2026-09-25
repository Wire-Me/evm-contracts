import type { HardhatRuntimeEnvironment } from "hardhat/types";

/// Fails fast with an actionable message when targeting `localhost` with nothing listening, rather
/// than letting a cryptic connection error surface partway through a deploy sequence.
export async function assertLocalNodeRunning(hre: HardhatRuntimeEnvironment): Promise<void> {
  const isLocalNetwork = hre.network.name === "localhost";
  if (!isLocalNetwork) {
    return;
  }

  const url = (hre.network.config as { url?: string }).url ?? "the configured localhost RPC";

  try {
    await hre.ethers.provider.getBlockNumber();
  } catch {
    throw new Error(
      `No local node detected at ${url}. Start one first with \`npx hardhat node\` ` +
      `(in a separate terminal - it needs to keep running), then re-run this task.`,
    );
  }
}

import type { HardhatRuntimeEnvironment } from "hardhat/types";

/// USDC and USDT have 18 decimals on BNB Smart Chain (the Binance-Peg tokens) and 6 on every other
/// chain WireMe runs on, so stand-in tokens match the real ones on the chain they're deployed to.
const STABLECOIN_DECIMALS_BY_CHAIN_ID: Record<number, number> = {
  56: 18, // BNB Smart Chain
  97: 18, // BNB Smart Chain testnet
};

const DEFAULT_STABLECOIN_DECIMALS = 6;

export function stablecoinDecimalsForChain(chainId: number): number {
  return STABLECOIN_DECIMALS_BY_CHAIN_ID[chainId] ?? DEFAULT_STABLECOIN_DECIMALS;
}

/// Reads decimals() from a deployed ERC20, real or stand-in.
export async function readTokenDecimals(hre: HardhatRuntimeEnvironment, tokenAddress: string): Promise<number> {
  const token = new hre.ethers.Contract(tokenAddress, ["function decimals() view returns (uint8)"], hre.ethers.provider);
  return Number(await token.decimals());
}

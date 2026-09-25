import { task } from "hardhat/config";
import { deployTestStablecoin } from "./deployTestStablecoin";
import { assertLocalNodeRunning } from "./assertLocalNodeRunning";
import {
  STATE_FILE_NAME,
  partitionByOnChainCode,
  readNetworkState,
  recordDeployment,
  stateFileExists,
} from "./deploymentState";

const STABLECOIN_DECIMALS = 6;

/// Chain ids where real USDC/USDT already exist and deploying a stand-in would be both wasteful
/// and misleading. Guarded rather than forbidden outright so a deliberate override is still
/// possible, but it can't happen by accident.
const MAINNET_CHAIN_IDS = new Set([
  1,      // Ethereum
  8453,   // Base
  10,     // Optimism
  137,    // Polygon
  42161,  // Arbitrum One
]);

const TOKENS_TO_DEPLOY = [
  { key: "USDC", name: "Test USD Coin", symbol: "USDC" },
  { key: "USDT", name: "Test Tether USD", symbol: "USDT" },
];

/// Deploys TestStablecoin stand-ins for USDC and USDT and records their addresses in
/// deployments.json, so `deploy-all` can pick them up without addresses being passed by hand.
///
/// Checks the recorded state first: tokens already deployed and still present on chain are reused
/// rather than redeployed (redeploying would orphan every balance minted against the old one).
/// A recorded address with no bytecode means the chain was reset, so it redeploys and replaces the
/// stale record.
task("deploy-tokens", "Deploys TestStablecoin stand-ins for USDC/USDT and records them in deployments.json")
  .addFlag("redeploy", "Deploy fresh tokens even if live ones are already recorded for this network")
  .addFlag("allowMainnet", "Required to deploy stand-in tokens to a mainnet chain id")
  .setAction(async (args: { redeploy: boolean; allowMainnet: boolean }, hre) => {
    await assertLocalNodeRunning(hre);

    const network = hre.network.name;
    const chainId = Number((await hre.ethers.provider.getNetwork()).chainId);

    if (MAINNET_CHAIN_IDS.has(chainId) && !args.allowMainnet) {
      throw new Error(
        `Refusing to deploy stand-in tokens to ${network} (chain id ${chainId}): real USDC and ` +
        `USDT already exist there. Record their canonical addresses under "${network}".tokens in ` +
        `${STATE_FILE_NAME} instead - look them up from the issuers, don't copy them from memory. ` +
        `Pass --allow-mainnet only if you genuinely intend to deploy a throwaway token to mainnet.`,
      );
    }

    const [signer] = await hre.ethers.getSigners();
    if (!signer) {
      throw new Error(`No signer available for ${network}. Configure an account (see .env.example).`);
    }

    if (!stateFileExists()) {
      console.log(`No ${STATE_FILE_NAME} yet - it'll be created by this deploy.`);
    }

    const recordedTokens = readNetworkState(network).tokens ?? {};
    const { live, stale } = await partitionByOnChainCode(hre, recordedTokens);

    if (Object.keys(stale).length > 0) {
      console.log(
        `Recorded token addresses for ${network} have no bytecode on chain id ${chainId} - the ` +
        `chain was probably reset. Replacing them:`,
      );
      for (const [key, address] of Object.entries(stale)) {
        console.log(`  ${key}: ${address} (stale)`);
      }
    }

    const alreadyDeployed = TOKENS_TO_DEPLOY.filter(({ key }) => live[key]);
    if (alreadyDeployed.length === TOKENS_TO_DEPLOY.length && !args.redeploy) {
      console.log(`Tokens already deployed on ${network} (chain id ${chainId}) and still live:`);
      for (const { key } of TOKENS_TO_DEPLOY) {
        console.log(`  ${key}: ${live[key]}`);
      }
      console.log("\nNothing to do. Pass --redeploy to deploy fresh ones anyway.");
      return;
    }

    console.log(
      `Deploying stand-in tokens to ${network} (chain id ${chainId}) as ${await signer.getAddress()}`,
    );

    const deployedTokens: Record<string, string> = {};

    for (const { key, name, symbol } of TOKENS_TO_DEPLOY) {
      const reuseExisting = live[key] && !args.redeploy;
      if (reuseExisting) {
        deployedTokens[key] = live[key];
        console.log(`  ${key}: ${live[key]} (reused)`);
        continue;
      }

      const token = await deployTestStablecoin(hre, signer, { name, symbol, decimals: STABLECOIN_DECIMALS });
      deployedTokens[key] = await token.getAddress();
      console.log(`  ${key}: ${deployedTokens[key]} (${symbol}, ${STABLECOIN_DECIMALS} decimals)`);
    }

    recordDeployment(network, { chainId, tokens: deployedTokens });

    console.log(
      `\nRecorded in ${STATE_FILE_NAME} under "${network}". ` +
      `Run \`npm run deploy-all${network === "localhost" ? "" : `:${network}`}\` next - it reads ` +
      `these addresses from the state file.`,
    );
    console.log(
      "Mint yourself a balance with: " +
      `cast send <token> "mint(address,uint256)" <recipient> 1000000000 --rpc-url <url>`,
    );
  });

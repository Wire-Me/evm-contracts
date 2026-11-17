import { task } from "hardhat/config";
import type { HardhatRuntimeEnvironment } from "hardhat/types";
import { deployEscrowConfig } from "./deployEscrowConfig";
import { deployFxEscrowMulti } from "./deployFxEscrowMulti";
import { deployProxyFxEscrowMulti } from "./deployProxyFxEscrowMulti";
import { deployWalletConfig } from "./deployWalletConfig";
import { deploySmartWalletMulti } from "./deploySmartWalletMulti";
import { assertLocalNodeRunning } from "./assertLocalNodeRunning";
import {
  STATE_FILE_NAME,
  partitionByOnChainCode,
  readNetworkState,
  recordDeployment,
  stateFileExists,
} from "./deploymentState";
import { readTokenDecimals } from "./tokenDecimals";

// In whole tokens. The proxy takes it in base units, so it's scaled by the tokens' own decimals
// (6 on Base, 18 on BNB Smart Chain); the proxy has no setter, so it must be right at deploy.
const DEFAULT_MINIMUM_BROKER_DEPOSIT_TOKENS = 500n;
const DEFAULT_EXPIRATION_DURATION_FOR_NON_BROKERS_SECONDS = 48n * 60n * 60n; // 48 hours

/// Bootstraps a network with the shared (non-per-user) contracts: EscrowConfig, FxEscrowMulti + its
/// proxy, WalletConfig, and the SmartWalletMulti implementation. ProxySmartWalletMulti and
/// per-currency ProxyFxEscrowMulti instances beyond the first are deployed separately, one per
/// user/broker/token - not part of this bootstrap.
///
/// Token addresses come from deployments.json (written by `deploy-tokens`), or from
/// USDC_ERC20_ADDRESS / USDT_ERC20_ADDRESS if you want to override what's recorded. Deployed
/// addresses are recorded back into deployments.json under the network's name.
/// ADMIN_ADDRESS defaults to the deploying signer if unset.
task("deploy-all", "Deploys EscrowConfig, FxEscrowMulti + proxy, WalletConfig, and SmartWalletMulti")
  .setAction(async (_args, hre) => {
    await assertLocalNodeRunning(hre);

    const network = hre.network.name;
    const chainId = Number((await hre.ethers.provider.getNetwork()).chainId);

    const [signer] = await hre.ethers.getSigners();
    if (!signer) {
      throw new Error(`No signer available for ${network}. Configure an account (see .env.example).`);
    }

    if (!stateFileExists()) {
      console.log(`No ${STATE_FILE_NAME} yet - it'll be created by this deploy.`);
    }

    const networkState = readNetworkState(network);
    const recordedTokens = networkState.tokens ?? {};

    const usdcErc20Address = process.env.USDC_ERC20_ADDRESS || recordedTokens.USDC;
    const usdtErc20Address = process.env.USDT_ERC20_ADDRESS || recordedTokens.USDT;

    if (!usdcErc20Address || !usdtErc20Address) {
      throw new Error(
        `No USDC/USDT addresses for ${network}. Either run \`deploy-tokens\` to deploy stand-ins ` +
        `(local/testnet), record the canonical token addresses under "${network}".tokens in ` +
        `${STATE_FILE_NAME} (mainnet), or set USDC_ERC20_ADDRESS and USDT_ERC20_ADDRESS.`,
      );
    }

    const tokenSource = process.env.USDC_ERC20_ADDRESS || process.env.USDT_ERC20_ADDRESS
      ? "environment (overriding the state file)"
      : STATE_FILE_NAME;

    const { stale: staleTokens } = await partitionByOnChainCode(hre, {
      USDC: usdcErc20Address,
      USDT: usdtErc20Address,
    });

    if (Object.keys(staleTokens).length > 0) {
      console.warn(
        `\nWARNING: these token addresses have no bytecode on chain id ${chainId}:`,
      );
      for (const [key, address] of Object.entries(staleTokens)) {
        console.warn(`  ${key}: ${address}`);
      }
      console.warn(
        "The contracts below will deploy fine (their constructors only store the addresses), but " +
        "any escrow operation that moves tokens will revert. If this is a local chain that was " +
        "restarted, run `deploy-tokens` first.\n",
      );
    }

    const { live: existingContracts } = await partitionByOnChainCode(hre, networkState.contracts ?? {});
    if (Object.keys(existingContracts).length > 0) {
      console.log(`Already recorded and live on ${network} - these records will be replaced:`);
      for (const [name, address] of Object.entries(existingContracts)) {
        console.log(`  ${name}: ${address}`);
      }
      console.log("");
    }

    const signerAddress = await signer.getAddress();
    const adminAddress = process.env.ADMIN_ADDRESS || signerAddress;

    const brokerDepositAmount = process.env.MINIMUM_BROKER_DEPOSIT_AMOUNT
      ? BigInt(process.env.MINIMUM_BROKER_DEPOSIT_AMOUNT)
      : DEFAULT_MINIMUM_BROKER_DEPOSIT_TOKENS * 10n ** BigInt(await readEscrowTokenDecimals(hre, usdcErc20Address, usdtErc20Address));

    const expirationDurationForNonBrokers = process.env.EXPIRATION_DURATION_FOR_NON_BROKERS_SECONDS
      ? BigInt(process.env.EXPIRATION_DURATION_FOR_NON_BROKERS_SECONDS)
      : DEFAULT_EXPIRATION_DURATION_FOR_NON_BROKERS_SECONDS;

    console.log(`Deploying to ${network} (chain id ${chainId}) as ${signerAddress} (admin = ${adminAddress})`);
    console.log(`Tokens from ${tokenSource}:`);
    console.log(`  USDC: ${usdcErc20Address}`);
    console.log(`  USDT: ${usdtErc20Address}\n`);

    const escrowConfig = await deployEscrowConfig(hre, signer, { usdcErc20Address, usdtErc20Address });
    console.log(`EscrowConfig:                 ${await escrowConfig.getAddress()}`);

    const fxEscrowMultiImpl = await deployFxEscrowMulti(hre, signer);
    console.log(`FxEscrowMulti (impl):         ${await fxEscrowMultiImpl.getAddress()}`);

    const escrowProxy = await deployProxyFxEscrowMulti(hre, signer, {
      implementationAddress: await fxEscrowMultiImpl.getAddress(),
      adminAddress,
      escrowConfigAddress: await escrowConfig.getAddress(),
      brokerDepositAmount,
      expirationDurationForNonBrokers,
    });
    console.log(`ProxyFxEscrowMulti:           ${await escrowProxy.getAddress()}`);

    const walletConfig = await deployWalletConfig(hre, signer, {
      fxEscrowMultiContractAddress: await escrowProxy.getAddress(),
      usdcErc20Address,
      usdtErc20Address,
    });
    console.log(`WalletConfig:                 ${await walletConfig.getAddress()}`);

    const smartWalletMultiImpl = await deploySmartWalletMulti(hre, signer);
    console.log(`SmartWalletMulti (impl):      ${await smartWalletMultiImpl.getAddress()}`);

    recordDeployment(network, {
      chainId,
      tokens: { USDC: usdcErc20Address, USDT: usdtErc20Address },
      contracts: {
        EscrowConfig: await escrowConfig.getAddress(),
        FxEscrowMulti: await fxEscrowMultiImpl.getAddress(),
        ProxyFxEscrowMulti: await escrowProxy.getAddress(),
        WalletConfig: await walletConfig.getAddress(),
        SmartWalletMulti: await smartWalletMultiImpl.getAddress(),
      },
    });

    console.log(`\nRecorded in ${STATE_FILE_NAME} under "${network}".`);
    console.log(
      "Per-user/broker ProxySmartWalletMulti instances (deprecated layer, see README.md) are " +
      "deployed separately via deployProxySmartWalletMulti, not part of this bootstrap.",
    );
  });

// The escrow has one broker deposit minimum for both tokens, so they must share decimals.
async function readEscrowTokenDecimals(hre: HardhatRuntimeEnvironment, usdcAddress: string, usdtAddress: string) {
  let usdcDecimals: number;
  let usdtDecimals: number;
  try {
    [usdcDecimals, usdtDecimals] = await Promise.all([
      readTokenDecimals(hre, usdcAddress),
      readTokenDecimals(hre, usdtAddress),
    ]);
  } catch (error) {
    throw new Error(
      `Could not read decimals() from the USDC/USDT contracts (${(error as Error).message}). The broker ` +
      `deposit minimum depends on them, so set MINIMUM_BROKER_DEPOSIT_AMOUNT in base units to deploy anyway.`,
    );
  }
  if (usdcDecimals !== usdtDecimals) {
    throw new Error(
      `USDC has ${usdcDecimals} decimals and USDT ${usdtDecimals}, but the escrow has one broker deposit ` +
      `minimum for both. Set MINIMUM_BROKER_DEPOSIT_AMOUNT explicitly.`,
    );
  }
  return usdcDecimals;
}

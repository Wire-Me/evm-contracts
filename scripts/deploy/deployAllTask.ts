import { task } from "hardhat/config";
import { deployEscrowConfig } from "./deployEscrowConfig";
import { deployFxEscrowMulti } from "./deployFxEscrowMulti";
import { deployProxyFxEscrowMulti } from "./deployProxyFxEscrowMulti";
import { deployWalletConfig } from "./deployWalletConfig";
import { deploySmartWalletMulti } from "./deploySmartWalletMulti";

const DEFAULT_MINIMUM_BROKER_DEPOSIT = 500n * 10n ** 6n; // 500 units of a 6-decimal stablecoin
const DEFAULT_EXPIRATION_DURATION_FOR_NON_BROKERS_SECONDS = 48n * 60n * 60n; // 48 hours

/// Bootstraps a fresh network with the shared (non-per-user) contracts: EscrowConfig,
/// FxEscrowMulti + its proxy, WalletConfig, and the SmartWalletMulti implementation.
/// ProxySmartWalletMulti and per-currency ProxyFxEscrowMulti instances beyond the first are
/// deployed separately, one per user/broker/token - not part of this bootstrap.
///
/// Requires USDC_ERC20_ADDRESS and USDT_ERC20_ADDRESS in the environment (real token addresses
/// on the target network - this task doesn't deploy mock tokens). ADMIN_ADDRESS defaults to the
/// deploying signer if unset.
task("deploy-all", "Deploys EscrowConfig, FxEscrowMulti + proxy, WalletConfig, and SmartWalletMulti")
  .setAction(async (_args, hre) => {
    const [signer] = await hre.ethers.getSigners();
    if (!signer) {
      throw new Error("No signer available. Configure an account for this network (see .env.example).");
    }

    const usdcErc20Address = process.env.USDC_ERC20_ADDRESS;
    const usdtErc20Address = process.env.USDT_ERC20_ADDRESS;
    if (!usdcErc20Address || !usdtErc20Address) {
      throw new Error("Set USDC_ERC20_ADDRESS and USDT_ERC20_ADDRESS in your .env before running deploy-all.");
    }

    const signerAddress = await signer.getAddress();
    const adminAddress = process.env.ADMIN_ADDRESS || signerAddress;

    const brokerDepositAmount = process.env.MINIMUM_BROKER_DEPOSIT_AMOUNT
      ? BigInt(process.env.MINIMUM_BROKER_DEPOSIT_AMOUNT)
      : DEFAULT_MINIMUM_BROKER_DEPOSIT;

    const expirationDurationForNonBrokers = process.env.EXPIRATION_DURATION_FOR_NON_BROKERS_SECONDS
      ? BigInt(process.env.EXPIRATION_DURATION_FOR_NON_BROKERS_SECONDS)
      : DEFAULT_EXPIRATION_DURATION_FOR_NON_BROKERS_SECONDS;

    console.log(`Deploying to ${hre.network.name} as ${signerAddress} (admin = ${adminAddress})`);

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

    console.log(
      "\nDone. Per-user/broker ProxySmartWalletMulti instances (deprecated layer, see " +
      "README.md) are deployed separately via deployProxySmartWalletMulti, not part of this " +
      "bootstrap.",
    );
  });

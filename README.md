# WireMe EVM Contracts

Solidity contracts implementing WireMe's crypto-to-fiat escrow flow: a user locks stablecoins
in escrow, a broker makes an offer, and funds release to the broker on completion or back to
the user if withdrawn early or returned by an admin. This repo holds the contract source and
its Foundry test suite. It does not deploy anything itself - see [Deployment](#deployment).

## Architecture

All of WireMe's own contracts live under `src/fx-contracts/`, split into two layers:

**`fx-escrow/`** - the escrow itself, and the only layer still under active development.
- `AbstractFxEscrowMulti.sol` - core logic: creating escrows and offers, the
  freeze/defrost/return/withdraw lifecycle, broker security deposits, platform fees, and admin
  authorization lists.
- `FxEscrowMultiStorage.sol` - the storage layout, kept in its own contract so it stays stable
  across upgrades (the proxy and the implementation must agree on slot order).
- `FxEscrowMulti.sol` - the concrete implementation contract deployed behind the proxy.
- `proxy/ProxyFxEscrowMulti.sol` - the contract actually deployed and interacted with in
  production. Delegatecalls into whichever implementation address `setImplementation` points at.
- `configuration/EscrowConfig.sol` - maps a token symbol (`keccak256("USDC")`, etc.) to its
  ERC20 contract address.

**`smart-wallet/`** - **deprecated**, see [Deprecated: smart-wallet layer](#deprecated-smart-wallet-layer)
below before touching anything here.

`src/EscrowStructs.sol` holds the shared structs (`FXEscrow`, `FXEscrowOffer`, `BrokerDeposit`,
etc.) used across both layers.

### Actor model

Every state-changing escrow function is gated by one of three modifiers:

- `onlyAdmin` - a single admin address (freeze/defrost/return escrows, manage authorization
  lists, withdraw platform fees, confiscate/freeze broker deposits, swap the config contract).
- `onlyAuthorizedUsers` - addresses explicitly allow-listed via `addAuthorizedUser` (create
  escrows, mark funds received, extend/withdraw their own escrows).
- `onlyAuthorizedBrokers` - addresses allow-listed via `addAuthorizedBroker` (make offers,
  withdraw after completion, manage their security deposit).

Authorization is a plain address allow-list (`isAuthorizedUser`/`isAuthorizedBroker`) - the
escrow contract doesn't care what kind of account or contract is calling it, only whether that
address has been added. That's what makes the smart-wallet deprecation possible: any address the
backend controls can be authorized directly, with or without a wallet contract in front of it.

## Trade lifecycle

In escrow terms the two sides are "user" and "broker"; in trade terms they're seller and buyer -
the seller (user) deposits stablecoins and receives fiat off-chain, the buyer (broker) pays fiat
off-chain and receives the stablecoins. Every trade follows the same tree, and a dispute can only
branch off after the seller commits via `linkOfferToEscrow` - before that point either side can
still walk away.

```mermaid
flowchart TD
    A["createEscrow<br/><i>seller deposits stablecoins</i>"] --> B["createOfferWithExpiration<br/><i>buyer offers to buy them</i>"]
    B --> C{{"linkOfferToEscrow<br/><i>seller commits - COMMIT POINT</i>"}}

    A -.-> X(["withdrawEscrowEarly<br/><i>seller cancels, gets funds back</i>"])
    B -.-> X

    C --> D["markFundsAsReceived<br/><i>seller confirms buyer's off-chain payment</i>"]
    D --> E(["withdrawEscrowAfterCompletion<br/><i>buyer withdraws the stablecoins</i>"])

    C -.->|dispute raised| F["freezeEscrow<br/><i>admin holds funds during review</i>"]
    F --> G{"admin reviews evidence"}
    G -->|buyer did pay| H["markFundsAsReceivedAdmin"]
    H --> E
    G -->|buyer didn't pay| I["returnEscrow"]
    I --> J(["withdrawEscrowAfterReturn<br/><i>seller gets funds back</i>"])

    classDef terminal fill:#2f7a3d,color:#fff,stroke:#1e4f27
    classDef dispute fill:#8a4b08,color:#fff,stroke:#5c3205
    class X,E,J terminal
    class F,G,H,I dispute
```

- **Before the commit point** (`createEscrow` -> `createOfferWithExpiration`): an outstanding
  offer doesn't lock anything in - `withdrawEscrowEarly` works right up until `linkOfferToEscrow`
  is called, regardless of whether an offer exists yet.
- **The commit point** (`linkOfferToEscrow`): the seller picks an offer and locks the trade in.
  This is the only admin-free action that closes off cancellation - after this,
  `withdrawEscrowEarly` and `extendEscrow` both revert.
- **Sunny day**: `markFundsAsReceived` (seller confirms) -> `withdrawEscrowAfterCompletion`
  (buyer withdraws, minus the platform fee).
- **Dispute** (only reachable after the commit point): admin calls `freezeEscrow` while
  reviewing evidence, then resolves it one of two ways:
  - Buyer did pay -> `markFundsAsReceivedAdmin` -> buyer calls the same
    `withdrawEscrowAfterCompletion` as the sunny-day path.
  - Buyer didn't pay -> `returnEscrow` -> seller calls `withdrawEscrowAfterReturn`.

`test/EscrowLifecycle.t.sol` is organized around this same tree. `createEscrow` /
`createOfferWithExpiration` / `linkOfferToEscrow` / `markFundsAsReceived` happy paths live in
`test/SmartWalletEscrow.t.sol`.

## Deprecated: smart-wallet layer

`src/fx-contracts/smart-wallet/` (`AbstractSmartWalletMulti`, `SmartWalletMulti`,
`SmartWalletMultiStorage`, `WalletConfig`, `ProxySmartWalletMulti`) is deprecated in favor of
Openfort embedded wallets, but **still in active production use**: `tx-conductor` currently
routes every escrow operation through a deployed `ProxySmartWalletMulti` instance per
user/broker instead of calling `FxEscrowMulti` directly. Each file carries an
`@custom:deprecated` NatSpec notice with the same explanation.

Do not build new features on this layer. It can be removed once `tx-conductor` calls
`FxEscrowMulti` directly using Openfort-controlled addresses registered via
`addAuthorizedUser`/`addAuthorizedBroker`, and existing proxy wallets are migrated off - that's
a backend migration in other repos, not something this repo can do on its own.

## Repository layout

- `src/` - WireMe's own contracts (see Architecture above).
- `lib/` - external dependencies only: `forge-std`, installed as a git submodule
  (`git submodule update --init` after cloning). `@openzeppelin/contracts` is the other
  dependency contracts import from, but it's installed via npm into `node_modules` instead, with
  an explicit remapping in `foundry.toml` - don't expect to find it under `lib/`.
- `test/` - Foundry tests. `test/helpers/EscrowTestBase.sol` holds the shared
  deploy-escrow-and-two-wallets setup that most suites inherit from.
- `scripts/deploy/` - deployment functions and the `deploy-all` hardhat task (see
  [Deployment](#deployment)).
- `hardhat.config.ts` - compiles `src/` (solc 0.8.30, matching `foundry.toml`) and registers the
  `deploy-all` task. Hardhat Ignition isn't used for anything here; there used to be an
  `ignition/` folder of unused boilerplate, removed entirely rather than left around.

## Setup

Install Foundry:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Install dependencies:

```bash
git submodule update --init --recursive
npm install
```

If you need to deploy from this repo directly (uncommon - see [Deployment](#deployment)), copy
`.env.example` to `.env` and fill in the private keys for the networks you're deploying to.

## Testing

```bash
forge test
```

Run a single test:

```bash
forge test --match-test test_FreezeEscrow_SetsFrozenFlag
```

Check coverage:

```bash
forge coverage
```

Debug with `console.log` (add the import, run with `-vvvv` to see output):

```solidity
import {console} from "../lib/forge-std/src/console.sol";
// ...
console.log(block.timestamp);
```

```bash
forge test -vvvv
```

## CI

`.github/workflows/test.yml` runs `forge build` and `forge test` on every PR targeting `main`
and on pushes to `main`.

## Deployment

This repo doesn't run its own deployments in production, but it does own *how* each contract
gets deployed - `contracts-manager` pulls it in as a git submodule and is responsible for
everything downstream of that (choosing a network/signer, address bookkeeping in its own DB,
secrets-manager key resolution).

`scripts/deploy/` exports one function per contract (`deployEscrowConfig`, `deployFxEscrowMulti`,
`deployProxyFxEscrowMulti`, `deployWalletConfig`, `deploySmartWalletMulti`,
`deployProxySmartWalletMulti`), each taking a `HardhatRuntimeEnvironment`, a `Signer`, and
whatever constructor args that contract needs. The point of centralizing these here rather than
in `contracts-manager`: constructor signatures are hand-duplicated today in
`contracts-manager/scripts/hardhat-tasks/deploy-and-store-*.ts`, and they drift - as of this
writing, `deploy-and-store-fx-escrow-multi-proxy.ts` passes only 3 of `ProxyFxEscrowMulti`'s 5
constructor args (missing `brokerDepositAmount` and `expirationDurationForNonBrokers`, added
after that task was last touched) and would revert if run today. Wiring `contracts-manager`'s
tasks to import and call these functions instead of re-deriving the arg list themselves fixes
that class of bug at the source: change a constructor, update the paired function in the same
commit, every caller picks it up.

`contracts-manager`'s existing tasks keep everything they already do - DB writes, secrets-manager
private key resolution, network/chainId mapping - they'd just replace their own
`hre.ethers.getContractFactory(name).deploy(...)` call with the matching function from here.

For bootstrapping a fresh network directly from this repo, `localhost` is the default network -
`npm run deploy-all` targets it with no flags needed. Start a node first (in a separate terminal,
it needs to keep running):

```bash
npx hardhat node
npm run deploy-all
```

If nothing's listening at the configured URL (`ETH_LOCAL_NODE_URL`, or `http://127.0.0.1:8545` if
unset), `deploy-all` fails fast with a clear error instead of a cryptic connection error - it
checks before doing anything else. Note that on a machine with WireMe's docker-compose dev stack
running, `wireme-eth-node-1` already occupies port 8545 - `deploy-all` will happily deploy there
too (it's just another node at that URL), so set `ETH_LOCAL_NODE_URL` to a different port first if
you want an isolated throwaway chain instead.

For testnet/mainnet:

```bash
npm run deploy-all:sepolia
npm run deploy-all:base
```

This deploys `EscrowConfig`, `FxEscrowMulti` + `ProxyFxEscrowMulti`, `WalletConfig`, and the
`SmartWalletMulti` implementation, in that order. It does not deploy per-user/broker
`ProxySmartWalletMulti` or `ProxyFxEscrowMulti` instances beyond the first - those are deployed
individually elsewhere. See `.env.example` for the required/optional env vars - `base` deploys
real funds to real mainnet, so `BASE_PRIVATE_KEY_1`/`_2` are deliberately left blank there.

Hardhat Ignition modules are not part of any of this - the `ignition/` folder was removed as
dead boilerplate (see git history if you're looking for it).

`foundry.toml` and `hardhat.config.ts`'s solidity settings (`optimizer = true`, `runs = 200`,
`evm_version = "paris"`) are deliberately kept identical to `contracts-manager`'s own configs for
both. They used to diverge - this repo's own configs never turned the optimizer on, which is a
huge size difference (`FxEscrowMulti` compiled to ~29KB unoptimized vs. ~12KB optimized, against
a 24,576-byte EIP-170 limit) - `contracts-manager`'s configs, the ones that actually govern real
deployments, had it right the whole time, so production was never at risk. But it meant this
repo's own `forge build --sizes`, `forge test`, and the `deploy-all` task above all failed or
misreported against a contract that deploys fine for real. If you ever touch the optimizer/evm
version in either config here, change it in `contracts-manager` too (or vice versa) - silent
drift between them is exactly what caused this.

## License

GPL-3.0-or-later - see [LICENSE.txt](./LICENSE.txt).

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "../../src/fx-contracts/fx-escrow/FxEscrowMulti.sol";
import "../../src/fx-contracts/fx-escrow/proxy/ProxyFxEscrowMulti.sol";
import "../../src/fx-contracts/smart-wallet/SmartWalletMulti.sol";
import "../../src/fx-contracts/smart-wallet/proxy/ProxySmartWalletMulti.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../lib/forge-std/src/Test.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

/// @notice Shared deployment/setup for escrow + smart-wallet test suites. Deploys one escrow
/// proxy, one user wallet, and one broker wallet, all driven by `admin` (who is also the
/// authorized EOA on each wallet, mirroring how the real backend relayer operates today).
abstract contract EscrowTestBase is Test {
    uint internal brokerInitialBalance = 1000 * 10 ** 6;
    uint internal userInitialBalance = 1000 * 10 ** 6;
    bytes32 internal constant USDC = keccak256("USDC");
    bytes32 internal constant USDT = keccak256("USDT");
    bytes32 internal constant NATIVE = keccak256("NATIVE");

    address internal admin = address(1);

    MockUSDC internal usdc;

    FxEscrowMulti internal escrowImpl;
    ProxyFxEscrowMulti internal escrowProxy;
    FxEscrowMulti internal escrow;

    SmartWalletMulti internal walletImpl;
    ProxySmartWalletMulti internal walletProxy;
    SmartWalletMulti internal userWallet;
    SmartWalletMulti internal brokerWallet;

    EscrowConfig internal escrowConfig;
    WalletConfig internal walletConfig;

    function setUp() public virtual {
        vm.startPrank(admin);

        // -----------------
        // Deploy Mock Token
        // -----------------
        usdc = new MockUSDC();

        // -----------------
        // Deploy Escrow
        // -----------------
        escrowConfig = new EscrowConfig(
            address(usdc),
            address(usdc)
        );

        escrowImpl = new FxEscrowMulti();

        escrowProxy = new ProxyFxEscrowMulti(
            address(escrowImpl),
            admin,
            address(escrowConfig),
            500 * 10 ** 6,
            48 hours
        );

        escrow = FxEscrowMulti(payable(address(escrowProxy)));

        // -----------------
        // Deploy User Wallet
        // -----------------
        walletConfig = new WalletConfig(
            address(escrow),
            address(usdc),
            address(usdc) // using USDC for both for test simplicity
        );

        walletImpl = new SmartWalletMulti();

        walletProxy = new ProxySmartWalletMulti(
            address(walletImpl),
            admin,
            address(walletConfig)
        );

        userWallet = SmartWalletMulti(payable(address(walletProxy)));

        // Authorize wallet in escrow
        escrow.addAuthorizedUser(address(userWallet));

        // -----------------
        // Deploy Broker Wallet
        // -----------------

        walletImpl = new SmartWalletMulti();

        walletProxy = new ProxySmartWalletMulti(
            address(walletImpl),
            admin,
            address(walletConfig)
        );

        brokerWallet = SmartWalletMulti(payable(address(walletProxy)));

        // Authorize wallet in escrow
        escrow.addAuthorizedBroker(address(brokerWallet));

        vm.stopPrank();

        // Mint USDC to wallet
        usdc.mint(address(userWallet), userInitialBalance);
        usdc.mint(address(brokerWallet), brokerInitialBalance);
    }
}

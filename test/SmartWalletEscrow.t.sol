// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "../lib/fx-contracts/fx-escrow/FxEscrowMulti.sol";

import "../lib/fx-contracts/fx-escrow/proxy/ProxyFxEscrowMulti.sol";
import "../lib/fx-contracts/smart-wallet/SmartWalletMulti.sol";
import "../lib/fx-contracts/smart-wallet/proxy/ProxySmartWalletMulti.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../lib/forge-std/src/Test.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USDC", "USDC") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract SmartWalletEscrowTest is Test {

    uint brokerInitialBalance = 1000 * 10 ** 6;
    uint userInitialBalance = 1000 * 10 ** 6;
    bytes32 internal constant USDC = keccak256("USDC");

    address internal admin = address(1);
//    address internal userEOA = address(2);

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

    function setUp() public {
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

    function test_CreateEscrow_WithERC20() public {

        uint amount = 100 * 10 ** 6;

        vm.startPrank(admin);

        // Approve escrow from wallet
        userWallet.transferFundsAndCreateEscrow(USDC, amount);

        vm.stopPrank();

        // Verify escrow exists
        EscrowStructs.FXEscrow memory escrowData = escrow.getEscrow(USDC, address(userWallet), 0);

        assertEq(escrowData.amount, amount);
        assertEq(escrowData.token, USDC);
        assertTrue(escrowData.createdAt > 0);
        assertFalse(escrowData.isWithdrawn);

        // Ensure funds moved to escrow contract
        assertEq(usdc.balanceOf(address(escrow)), amount);
        assertEq(usdc.balanceOf(address(userWallet)), 900 * 10 ** 6);
    }

    function test_CreateOffer_WithERC20() public {

        vm.startPrank(admin);

        // -----------------
        // Create the Transaction
        // -----------------

        uint amount = 100 * 10 ** 6;
        userWallet.transferFundsAndCreateEscrow(USDC, amount);

        // Approve escrow from wallet
        brokerWallet.createOffer(USDC, address(userWallet), 0, 0);

        vm.stopPrank();

        // Verify off exists
        EscrowStructs.FXEscrowOffer memory offerData = escrow.getOffer(USDC, address(brokerWallet), 0);

        assertEq(offerData.feeBasisPoints, 0);
        assertTrue(offerData.createdAt > 0);
        assertEq(offerData.escrowAccount, address(userWallet));
        assertEq(offerData.escrowIndex, 0);
    }

    function test_DepositSecurityDeposit() public {

        vm.startPrank(admin);

        // -----------------
        // Deposit the security deposit
        // -----------------

        uint amount = 500 * 10 ** 6;
        brokerWallet.depositSecurityDeposit(USDC, amount);

        vm.stopPrank();

        // Verify deposit exists
        EscrowStructs.BrokerDeposit memory brokerDeposit = escrow.getBrokerDeposit(address(brokerWallet));

        assertEq(brokerDeposit.amount, amount);
        assertTrue(brokerDeposit.createdAt > 0);

        // Verify funds moved to escrow contract
        assertEq(usdc.balanceOf(address(escrow)), amount);
        assertEq(usdc.balanceOf(address(brokerWallet)), brokerInitialBalance - amount);
    }

    function test_WithdrawSecurityDeposit() public {

        vm.startPrank(admin);

        // -----------------
        // Deposit the security deposit
        // -----------------

        uint amount = 500 * 10 ** 6;
        brokerWallet.depositSecurityDeposit(USDC, amount);

        vm.stopPrank();

        // Verify deposit exists
        EscrowStructs.BrokerDeposit memory brokerDeposit = escrow.getBrokerDeposit(address(brokerWallet));

        assertEq(brokerDeposit.amount, amount);
        assertTrue(brokerDeposit.createdAt > 0);

        // Verify funds moved to escrow contract
        assertEq(usdc.balanceOf(address(escrow)), amount);
        assertEq(usdc.balanceOf(address(brokerWallet)), brokerInitialBalance - amount);

        // -----------------
        // Withdraw the security deposit
        // -----------------

        vm.startPrank(admin);

        brokerWallet.withdrawSecurityDeposit();

        // Verify funds moved from escrow contract
        assertEq(usdc.balanceOf(address(escrow)), 0);
        assertEq(usdc.balanceOf(address(brokerWallet)), brokerInitialBalance);

        vm.stopPrank();
    }
}
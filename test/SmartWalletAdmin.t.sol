// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import "./helpers/EscrowTestBase.sol";

/// @notice Covers the (deprecated but still live - see AbstractSmartWalletMulti.sol) smart-wallet
/// admin functions: implementation/config swapping, authorized-EOA delegation, and direct
/// wallet-funds withdrawal.
contract SmartWalletAdminTest is EscrowTestBase {
    address internal randomAddress = address(0xD00D);

    // -----------------
    // setImplementation
    // -----------------

    function test_SetImplementation_UpdatesImplementation() public {
        SmartWalletMulti newImpl = new SmartWalletMulti();

        vm.prank(admin);
        userWallet.setImplementation(address(newImpl));

        assertEq(userWallet.getImplementation(), address(newImpl));
    }

    function test_SetImplementation_RevertsIfNotAdmin() public {
        SmartWalletMulti newImpl = new SmartWalletMulti();

        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        userWallet.setImplementation(address(newImpl));
    }

    // -----------------
    // setAuthorizedEOA
    // -----------------

    function test_SetAuthorizedEOA_AllowsThatEOAToActOnWallet() public {
        address eoa = address(0xE0A);

        vm.prank(admin);
        userWallet.setAuthorizedEOA(eoa);

        // Previously only `admin` could withdraw wallet funds; now the authorized EOA can too.
        vm.prank(eoa);
        userWallet.withdrawWalletFunds(USDC, payable(randomAddress), 1 * 10 ** 6);

        assertEq(usdc.balanceOf(randomAddress), 1 * 10 ** 6);
    }

    function test_SetAuthorizedEOA_RevertsIfNotAdminOrAuthorizedEOA() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account or authorized EOA");
        userWallet.setAuthorizedEOA(randomAddress);
    }

    // -----------------
    // setWalletConfig / setWalletConfigAndImplementation
    // -----------------

    function test_SetWalletConfig_UpdatesConfig() public {
        TestStablecoin otherToken = newTestUsdc();
        WalletConfig newConfig = new WalletConfig(address(escrow), address(otherToken), address(otherToken));

        vm.prank(admin);
        userWallet.setWalletConfig(address(newConfig));

        assertEq(userWallet.getErc20ContractAddress(USDC), address(otherToken));
    }

    function test_SetWalletConfig_RevertsIfNotAdmin() public {
        TestStablecoin otherToken = newTestUsdc();
        WalletConfig newConfig = new WalletConfig(address(escrow), address(otherToken), address(otherToken));

        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account");
        userWallet.setWalletConfig(address(newConfig));
    }

    function test_SetWalletConfigAndImplementation_UpdatesBoth() public {
        TestStablecoin otherToken = newTestUsdc();
        WalletConfig newConfig = new WalletConfig(address(escrow), address(otherToken), address(otherToken));
        SmartWalletMulti newImpl = new SmartWalletMulti();

        vm.prank(admin);
        userWallet.setWalletConfigAndImplementation(address(newConfig), address(newImpl));

        assertEq(userWallet.getErc20ContractAddress(USDC), address(otherToken));
        assertEq(userWallet.getImplementation(), address(newImpl));
    }

    // -----------------
    // withdrawWalletFunds
    // -----------------

    function test_WithdrawWalletFunds_TransfersERC20() public {
        uint amount = 50 * 10 ** 6;
        uint balanceBefore = usdc.balanceOf(address(userWallet));

        vm.prank(admin);
        userWallet.withdrawWalletFunds(USDC, payable(randomAddress), amount);

        assertEq(usdc.balanceOf(randomAddress), amount);
        assertEq(usdc.balanceOf(address(userWallet)), balanceBefore - amount);
    }

    function test_WithdrawWalletFunds_TransfersNative() public {
        uint amount = 1 ether;
        vm.deal(address(userWallet), amount);

        vm.prank(admin);
        userWallet.withdrawWalletFunds(NATIVE, payable(randomAddress), amount);

        assertEq(randomAddress.balance, amount);
        assertEq(address(userWallet).balance, 0);
    }

    function test_WithdrawWalletFunds_RevertsOnZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert("Cannot withdraw to zero address");
        userWallet.withdrawWalletFunds(USDC, payable(address(0)), 1);
    }

    function test_WithdrawWalletFunds_RevertsIfNotAdminOrAuthorizedEOA() public {
        vm.prank(randomAddress);
        vm.expectRevert("Sender is not an authorized admin account or authorized EOA");
        userWallet.withdrawWalletFunds(USDC, payable(randomAddress), 1);
    }
}

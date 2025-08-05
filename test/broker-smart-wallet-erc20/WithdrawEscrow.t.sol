// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {IRelay} from "../../lib/IRelay.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {TestToken} from "../../lib/erc20/TestToken.sol";
import {UserSmartWalletERC20} from "../../lib/fx-contracts/UserSmartWalletERC20.sol";
import {FxEscrowERC20} from "../../lib/fx-contracts/FxEscrowERC20.sol";
import "../../lib/EscrowStructs.sol";
import {BrokerSmartWalletERC20} from "../../lib/fx-contracts/BrokerSmartWalletERC20.sol";

contract UserSmartWalletERC20WithdrawEscrowTest is Test {
    TestToken public tokenContract;
    UserSmartWalletERC20 public userWallet;
    BrokerSmartWalletERC20 public brokerWallet;
    BrokerSmartWalletERC20 public brokerWallet2;
    FxEscrowERC20 public escrowContract;
    address public admin = address(0xb055);
    uint public amountToTransfer;
    uint public startingUserBalance;
    uint public startingBlockTimestamp = 4102444800; // 2100/01/01 00:00:00 GMT

    function setUp() public {
        vm.startPrank(admin);

        vm.warp(startingBlockTimestamp); // Set the current block timestamp

        tokenContract = new TestToken("Test Token", "TTK");
        escrowContract = new FxEscrowERC20(100, address(tokenContract));
        userWallet = new UserSmartWalletERC20(address(tokenContract), address(escrowContract), address(0));
        brokerWallet = new BrokerSmartWalletERC20(address(tokenContract), address(escrowContract), address(0));
        brokerWallet2 = new BrokerSmartWalletERC20(address(tokenContract), address(escrowContract), address(0));
        amountToTransfer = 10 * 10 ** tokenContract.decimals();
        startingUserBalance = 1000 * 10 ** tokenContract.decimals();

        // Transfer some tokens to the user wallet
        tokenContract.transfer(address(userWallet), startingUserBalance); // Transfer some tokens to the user smart wallet

        // Approve the user wallet as an authorized user
        escrowContract.addAuthorizedUser(address(userWallet));

        // Approve the broker wallet as an authorized broker
        escrowContract.addAuthorizedBroker(address(brokerWallet));
        escrowContract.addAuthorizedBroker(address(brokerWallet2));

        // Create the escrow
        userWallet.transferFundsAndCreateEscrow(amountToTransfer);

        // Create the offer
        brokerWallet.createOffer(address(userWallet), 0);

        // Link the offer to the escrow
        userWallet.linkOfferToEscrow(0, address(brokerWallet), 0);

        vm.stopPrank();
    }

    function testWithdrawEscrowHappyPath() public {
        vm.startPrank(admin);

        assertEq(tokenContract.balanceOf(address(escrowContract)), amountToTransfer, "Escrow contract should hold the transferred amount before withdrawal");
        assertEq(tokenContract.balanceOf(address(userWallet)), startingUserBalance - amountToTransfer, "User wallet should have the correct balance before withdrawal");
        assertEq(tokenContract.balanceOf(address(brokerWallet)), 0, "Broker wallet should have the correct balance before withdrawal");

        vm.warp(startingBlockTimestamp + escrowContract.defaultEscrowDuration() + 1); // Warp to after the escrow expiration

        brokerWallet.withdrawEscrow(address(userWallet), 0);

        assertEq(tokenContract.balanceOf(address(escrowContract)), 0, "Escrow contract should be empty after withdrawal");
        assertEq(tokenContract.balanceOf(address(userWallet)), startingUserBalance - amountToTransfer, "User wallet should have the same balance before and after withdrawal");
        assertEq(tokenContract.balanceOf(address(brokerWallet)), amountToTransfer, "Broker wallet should have the funds from the escrow after withdrawal");

        (,,,bool isWithdrawn,,,,) = escrowContract.escrows(address(userWallet), 0);
        assertTrue(isWithdrawn, "Escrow should be marked as withdrawn");

        vm.stopPrank();
    }

    function testWithdrawEscrowRevertsIfAlreadyWithdrawn() public {
        vm.startPrank(admin);

        vm.warp(startingBlockTimestamp + escrowContract.defaultEscrowDuration() + 1); // Warp to after the escrow expiration

        brokerWallet.withdrawEscrow(address(userWallet), 0);

        vm.expectRevert("Escrow is already withdrawn");
        brokerWallet.withdrawEscrow(address(userWallet), 0);

        vm.stopPrank();
    }

    function testWithdrawEscrowRevertsIfEscrowIsReturned() public {
        vm.startPrank(admin);

        escrowContract.returnEscrow(address(userWallet), 0);

        vm.expectRevert("Escrow is returned and cannot be withdrawn by the broker");
        brokerWallet.withdrawEscrow(address(userWallet), 0);

        vm.stopPrank();
    }

    function testWithdrawEscrowRevertsIfEscrowIsFrozen() public {
        vm.startPrank(admin);

        escrowContract.freezeEscrow(address(userWallet), 0);

        vm.expectRevert("Escrow is frozen and cannot be withdrawn by the broker");
        brokerWallet.withdrawEscrow(address(userWallet), 0);

        vm.stopPrank();
    }

    function testWithdrawEscrowRevertsIfSenderIsNotSelectedBrokerAccount() public {
        vm.startPrank(admin);

        vm.warp(startingBlockTimestamp + escrowContract.defaultEscrowDuration() + 1); // Warp to after the escrow expiration

        vm.expectRevert("Only the selected broker can withdraw from the escrow");
        brokerWallet2.withdrawEscrow(address(userWallet), 0);

        vm.stopPrank();
    }

    function testWithdrawEscrowRevertsIfEscrowNotExpired() public {
        vm.startPrank(admin);

        vm.warp(startingBlockTimestamp + escrowContract.defaultEscrowDuration() - 1); // Warp to just before the escrow expiration

        vm.expectRevert("Escrow has not yet expired");
        brokerWallet.withdrawEscrow(address(userWallet), 0);

        vm.stopPrank();
    }
}
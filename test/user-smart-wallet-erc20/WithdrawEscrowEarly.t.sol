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

contract UserSmartWalletERC20WithdrawEscrowEarlyTest is Test {
    TestToken public tokenContract;
    UserSmartWalletERC20 public userWallet;
    BrokerSmartWalletERC20 public brokerWallet;
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
        amountToTransfer = 10 * 10 ** tokenContract.decimals();
        startingUserBalance = 1000 * 10 ** tokenContract.decimals();

        // Transfer some tokens to the user wallet
        tokenContract.transfer(address(userWallet), startingUserBalance); // Transfer some tokens to the user smart wallet

        // Approve the user wallet as an authorized user
        escrowContract.addAuthorizedUser(address(userWallet));

        // Approve the broker wallet as an authorized broker
        escrowContract.addAuthorizedBroker(address(brokerWallet));

        // Create the escrow
        userWallet.transferFundsAndCreateEscrow(amountToTransfer);

        // Create the offer
        brokerWallet.createOffer(address(userWallet), 0);

        vm.stopPrank();
    }

    function testWithdrawEscrowEarlyHappyPath() public {
        vm.startPrank(admin);

        assertEq(tokenContract.balanceOf(address(escrowContract)), amountToTransfer, "Escrow contract should hold the transferred amount before withdrawal");
        assertEq(tokenContract.balanceOf(address(userWallet)), startingUserBalance - amountToTransfer, "User wallet should have the correct balance before withdrawal");

        userWallet.withdrawEscrowEarly(0);

        assertEq(tokenContract.balanceOf(address(escrowContract)), 0, "Escrow contract should have no funds after early withdrawal");
        assertEq(tokenContract.balanceOf(address(userWallet)), startingUserBalance, "User wallet should have the correct balance after withdrawal");

        (,,,bool isWithdrawn,,,,) = escrowContract.escrows(address(userWallet), 0);
        assertTrue(isWithdrawn, "Escrow should be marked as withdrawn");

        vm.stopPrank();
    }

    function testWithdrawEscrowEarlyRevertsIfAlreadyWithdrawn() public {
        vm.startPrank(admin);

        userWallet.withdrawEscrowEarly(0);
        vm.expectRevert("Escrow is already withdrawn");
        userWallet.withdrawEscrowEarly(0);

        vm.stopPrank();
    }

    function testWithdrawEscrowEarlyRevertsIfOfferIsLinked() public {
        vm.startPrank(admin);

        userWallet.linkOfferToEscrow(0, address(brokerWallet), 0);

        vm.expectRevert("Escrow has already selected an offer");
        userWallet.withdrawEscrowEarly(0);

        vm.stopPrank();
    }
}
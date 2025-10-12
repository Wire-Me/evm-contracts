// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {Test} from "../../lib/forge-std/src/Test.sol";
import {CommonBase} from "../../lib/forge-std/src/Base.sol";
import {StdAssertions} from "../../lib/forge-std/src/StdAssertions.sol";
import {StdChains} from "../../lib/forge-std/src/StdChains.sol";
import {StdCheats, StdCheatsSafe} from "../../lib/forge-std/src/StdCheats.sol";
import {StdUtils} from "../../lib/forge-std/src/StdUtils.sol";
import {TestToken} from "../../lib/erc20/TestToken.sol";
import {UserSmartWalletERC20} from "../../lib/fx-contracts/UserSmartWalletERC20.sol";
import {FxEscrowERC20} from "../../lib/fx-contracts/fx-escrow/FxEscrowERC20.sol";
import "../../lib/EscrowStructs.sol";
import {console} from "../../lib/forge-std/src/console.sol";



contract UserSmartWalletERC20TransferFundsAndCreateEscrowTest is Test {
    TestToken public tokenContract;
    UserSmartWalletERC20 public userWallet;
    FxEscrowERC20 public escrowContract;
    address public admin = address(0xb055);
    uint public currentBlockTimestamp = 4102444800; // 2100/01/01 00:00:00 GMT


    function setUp() public {
        vm.startPrank(admin);

        // Set the current block timestamp
        vm.warp(currentBlockTimestamp);

        // Set up contracts
        tokenContract = new TestToken("Test Token", "TTK");
        escrowContract = new FxEscrowERC20(100, address(tokenContract));
        userWallet = new UserSmartWalletERC20(address(tokenContract), address(escrowContract), address(0));

        // Transfer some tokens to the user wallet
        tokenContract.transfer(address(userWallet), 1000 * 10 ** tokenContract.decimals()); // Transfer some tokens to the user smart wallet

        // Approve the user wallet as an authorized user
        escrowContract.addAuthorizedUser(address(userWallet));
        vm.stopPrank();
    }

    function testTransferFundsAndCreateEscrowHappyPath() public {
        vm.startPrank(admin);
        uint amountToTransfer = 10 * 10 ** tokenContract.decimals();

        userWallet.transferFundsAndCreateEscrow(amountToTransfer);

        // Check that the escrow contract received the tokens
        assertEq(tokenContract.balanceOf(address(escrowContract)), amountToTransfer);

        // Check that the escrow was created with the correct amount
        (uint amount, uint createdAt, uint expiration, bool isWithdrawn, bool isFrozen, bool isReturned, address selectedBrokerAccount, uint selectedOfferIndex) = escrowContract.escrows(address(userWallet), 0);
        assertEq(amount, amountToTransfer);
        assertEq(createdAt, currentBlockTimestamp);
        assertEq(expiration, currentBlockTimestamp + escrowContract.defaultEscrowDuration());
        assertFalse(isWithdrawn);
        assertFalse(isFrozen);
        assertFalse(isReturned);
        assertEq(selectedBrokerAccount, address(0)); // No broker selected yet
        assertEq(selectedOfferIndex, 0);

        vm.stopPrank();
    }

    function testTransferFundsAndCreateEscrowRevertsIfNotAuthorized() public {
        vm.startPrank(admin);

        escrowContract.removeAuthorizedUser(address(userWallet)); // Remove the user wallet from authorized users

        uint amountToTransfer = 10 * 10 ** tokenContract.decimals();

        // Expect revert because the user wallet is not authorized
        vm.expectRevert("Sender is not an authorized user wallet");
        userWallet.transferFundsAndCreateEscrow(amountToTransfer);

        // Check that the escrow contract did not receive any tokens
        assertEq(tokenContract.balanceOf(address(escrowContract)), 0);
        vm.stopPrank();
    }

}
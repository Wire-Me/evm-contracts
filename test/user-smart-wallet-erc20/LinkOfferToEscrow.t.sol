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
import {FxEscrowERC20} from "../../lib/fx-contracts/FxEscrowERC20.sol";
import "../../lib/EscrowStructs.sol";
import {BrokerSmartWalletERC20} from "../../lib/fx-contracts/BrokerSmartWalletERC20.sol";

contract UserSmartWalletERC20LinkOfferToEscrowTest is Test {
    TestToken public tokenContract;
    UserSmartWalletERC20 public userWallet;
    BrokerSmartWalletERC20 public brokerWallet;
    FxEscrowERC20 public escrowContract;
    address public admin = address(0xb055);
    uint public amountToTransfer;

    function setUp() public {
        vm.startPrank(admin);
        tokenContract = new TestToken("Test Token", "TTK");
        escrowContract = new FxEscrowERC20(100, address(tokenContract));
        userWallet = new UserSmartWalletERC20(address(tokenContract), address(escrowContract), address(0));
        brokerWallet = new BrokerSmartWalletERC20(address(tokenContract), address(escrowContract), address(0));
        amountToTransfer = 10 * 10 ** tokenContract.decimals();

        // Transfer some tokens to the user wallet
        tokenContract.transfer(address(userWallet), 1000 * 10 ** tokenContract.decimals()); // Transfer some tokens to the user smart wallet

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

    function testLinkOfferToEscrowHappyPath() public {
        vm.startPrank(admin);

        userWallet.linkOfferToEscrow(0, address(brokerWallet), 0);

        // Check that the offer is linked to the escrow
        (uint escrowAmount,,,,,, address selectedBrokerAccount, uint selectedOfferIndex) = escrowContract.escrows(address(userWallet), 0);
        assertEq(escrowAmount, amountToTransfer);
        assertEq(selectedBrokerAccount, address(brokerWallet));
        assertEq(selectedOfferIndex, 0);

        vm.stopPrank();
    }

    function testTransferFundsAndCreateEscrowRevertsIfOfferAccountIsZero() public {
        vm.startPrank(admin);

        vm.expectRevert("Offer account cannot be zero address");
        userWallet.linkOfferToEscrow(0, address(0), 0);

        vm.stopPrank();
    }
}
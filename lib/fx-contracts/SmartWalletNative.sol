// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FxEscrowERC20} from "./FxEscrowERC20.sol";
import {AdminBase} from "./AdminBase.sol";
import {SmartWallet} from "./SmartWallet.sol";

contract SmartWalletNative is AdminBase, SmartWallet {
    FxEscrowERC20 immutable public escrowContract;

    constructor(address _escrowContractAddress, address _admin) {
        require(_escrowContractAddress != address(0), "escrow address cannot be zero");

        admin = _admin;
        escrowContract = FxEscrowERC20(_escrowContractAddress);
    }

    ////////////////////
    // User functions //
    ////////////////////

    function transferFundsAndCreateEscrow(uint _amount) external {
        require(address(this).balance >= _amount, "Not enough balance");

        (bool success,) = payable(address(escrowContract)).call{value: _amount}("");
        require(success, "Transfer failed");

        escrowContract.createEscrow(_amount);
    }

    function linkOfferToEscrow(uint _escrowIndex, address _offerAccount, uint _offerIndex) external {
        require(_offerAccount != address(0), "Offer account cannot be zero address");

        escrowContract.linkOfferToEscrow(_escrowIndex, _offerAccount, _offerIndex);
    }

    function extendEscrow(uint _escrowIndex) external {
        escrowContract.extendEscrow(_escrowIndex);
    }

    function withdrawEscrowEarly(uint _escrowIndex) external {
        escrowContract.withdrawEscrowEarly(_escrowIndex);
    }

    function withdrawEscrow(uint _escrowIndex) external {
        escrowContract.withdrawEscrowAfterReturn(_escrowIndex);
    }

    //////////////////////
    // Broker functions //
    //////////////////////

    function createOffer(
        address _escrowAccount,
        uint _escrowIndex,
        uint _feeBasisPoints
    ) external {
        require(_escrowAccount != address(0), "Escrow account cannot be zero address");
        escrowContract.createOffer(_escrowAccount, _escrowIndex, _feeBasisPoints);
    }

    function withdrawEscrow(address _escrowAccount, uint _escrowIndex) external {
        escrowContract.withdrawEscrowAfterCompletion(_escrowAccount, _escrowIndex);
    }

    /////////////////////////
    // Universal functions //
    /////////////////////////

    function withdrawWalletFunds(address payable _to, uint _amount) external onlyAdmin {
        require(_to != address(0), "Cannot withdraw to zero address");
        require(address(this).balance >= _amount, "Not enough balance");

        (bool success,) = _to.call{value: _amount}("");
        require(success, "Transfer failed");
    }
}
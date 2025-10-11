// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {FxEscrowERC20} from "./FxEscrowERC20.sol";
import {AdminBase} from "./AdminBase.sol";

contract SmartWalletERC20 is AdminBase {
    IERC20 immutable public erc20TokenContract;
    FxEscrowERC20 immutable public escrowContract;

    constructor(address _escrowContractAddress, address _admin) {
        require(_escrowContractAddress != address(0), "escrow address cannot be zero");

        admin = _admin;
        escrowContract = FxEscrowERC20(_escrowContractAddress);
        erc20TokenContract = escrowContract.erc20TokenContract();
    }

    ////////////////////
    // User functions //
    ////////////////////

    function transferFundsAndCreateEscrow(uint _amount) external {
        erc20TokenContract.transfer(address(escrowContract), _amount);

        escrowContract.createEscrow(_amount);
    }

    function linkOfferToEscrow(uint _escrowIndex, address _offerAccount, uint _offerIndex) external {
        require(_offerAccount != address(0), "Offer account cannot be zero address");

        escrowContract.linkOfferToEscrow(_escrowIndex, _offerAccount, _offerIndex);
    }

    function extendEscrow(uint escrowIndex) external {
        escrowContract.extendEscrow(escrowIndex);
    }

    function withdrawEscrowEarly(uint escrowIndex) external {
        escrowContract.withdrawEscrowEarly(escrowIndex);
    }

    function withdrawEscrow(uint escrowIndex) external {
        escrowContract.withdrawEscrowAfterReturn(escrowIndex);
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

    function withdrawEscrow(address escrowAccount, uint escrowIndex) external {
        escrowContract.withdrawEscrowAfterCompletion(escrowAccount, escrowIndex);
    }

    /////////////////////////
    // Universal functions //
    /////////////////////////

    function withdrawWalletFunds(address to, uint amount) external onlyAdmin {
        require(to != address(0), "Cannot withdraw to zero address");
        erc20TokenContract.transfer(to, amount);
    }
}
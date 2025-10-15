// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {FxEscrow} from "../fx-escrow/FxEscrow.sol";
import {AdminBase} from "../AdminBase.sol";

abstract contract SmartWallet is AdminBase {
    uint public test = 0;

    function transferFundsFromContract(address _to, uint _amount) internal virtual;

    function escrowContract() public view virtual returns (FxEscrow);

    ////////////////////
    // User functions //
    ////////////////////

    function transferFundsAndCreateEscrow(uint _amount) external onlyAdmin {
        transferFundsFromContract(address(escrowContract()), _amount);

        escrowContract().createEscrow(_amount);
    }

    function linkOfferToEscrow(uint _escrowIndex, address _offerAccount, uint _offerIndex) external onlyAdmin {
        escrowContract().linkOfferToEscrow(_escrowIndex, _offerAccount, _offerIndex);
    }

    function extendEscrow(uint _escrowIndex) external onlyAdmin {
        escrowContract().extendEscrow(_escrowIndex);
    }

    function withdrawEscrowEarly(uint _escrowIndex) external onlyAdmin {
        escrowContract().withdrawEscrowEarly(_escrowIndex);
    }

    function withdrawEscrowAfterReturn(uint _escrowIndex) external onlyAdmin {
        escrowContract().withdrawEscrowAfterReturn(_escrowIndex);
    }

    //////////////////////
    // Broker functions //
    //////////////////////

    function createOffer(
        address _escrowAccount,
        uint _escrowIndex,
        uint _feeBasisPoints
    ) external onlyAdmin {
        require(_escrowAccount != address(0), "Escrow account cannot be zero address");
        escrowContract().createOffer(_escrowAccount, _escrowIndex, _feeBasisPoints);
    }

    function withdrawEscrowAfterCompletion(address _escrowAccount, uint _escrowIndex) external onlyAdmin {
        escrowContract().withdrawEscrowAfterCompletion(_escrowAccount, _escrowIndex);
    }

    /////////////////////////
    // Universal functions //
    /////////////////////////

//    function withdrawWalletFunds(address payable _to, uint _amount) external onlyAdmin {
//        require(_to != address(0), "Cannot withdraw to zero address");
//        transferFundsFromContract(_to, _amount);
//    }

    function withdrawWalletFunds(address payable _to, uint _amount) external {
        require(_to != address(0), "Cannot withdraw to zero address");
        transferFundsFromContract(_to, _amount);
    }
}
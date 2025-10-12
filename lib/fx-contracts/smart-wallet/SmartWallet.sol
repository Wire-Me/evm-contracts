// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {FxEscrow} from "../fx-escrow/FxEscrow.sol";
import {AdminBase} from "../AdminBase.sol";

abstract contract SmartWallet is AdminBase {
    function transferFundsFromContract(address _to, uint _amount) internal virtual;

    function escrowContract() public view virtual returns (FxEscrow);

    ////////////////////
    // User functions //
    ////////////////////

    function transferFundsAndCreateEscrow(uint _amount) external {
        transferFundsFromContract(address(escrowContract()), _amount);

        escrowContract().createEscrow(_amount);
    }

    function linkOfferToEscrow(uint _escrowIndex, address _offerAccount, uint _offerIndex) external {
        require(_offerAccount != address(0), "Offer account cannot be zero address");

        escrowContract().linkOfferToEscrow(_escrowIndex, _offerAccount, _offerIndex);
    }

    function extendEscrow(uint _escrowIndex) external {
        escrowContract().extendEscrow(_escrowIndex);
    }

    function withdrawEscrowEarly(uint _escrowIndex) external {
        escrowContract().withdrawEscrowEarly(_escrowIndex);
    }

    function withdrawEscrow(uint _escrowIndex) external {
        escrowContract().withdrawEscrowAfterReturn(_escrowIndex);
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
        escrowContract().createOffer(_escrowAccount, _escrowIndex, _feeBasisPoints);
    }

    function withdrawEscrow(address _escrowAccount, uint _escrowIndex) external {
        escrowContract().withdrawEscrowAfterCompletion(_escrowAccount, _escrowIndex);
    }

    /////////////////////////
    // Universal functions //
    /////////////////////////

    function withdrawWalletFunds(address payable _to, uint _amount) external onlyAdmin {
        require(_to != address(0), "Cannot withdraw to zero address");
        transferFundsFromContract(_to, _amount);
    }
}
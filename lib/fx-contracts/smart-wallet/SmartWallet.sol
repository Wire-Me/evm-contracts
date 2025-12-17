// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "./SmartWalletStorage.sol";
import {AdminBase} from "../AdminBase.sol";
import {FxEscrow} from "../fx-escrow/FxEscrow.sol";

abstract contract SmartWallet is SmartWalletStorage {
    function transferFundsFromContract(address _to, uint _amount) internal virtual;

    function escrowContract() public view virtual returns (FxEscrow);

    modifier onlyAdminOrAuthorizedEOA() {
        require(msg.sender == admin || msg.sender == authorizedEOA, "Sender is not an authorized admin account or authorized EOA");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Sender is not an authorized admin account");
        _;
    }

    ////////////////////
    // User functions //
    ////////////////////

    function transferFundsAndCreateEscrow(uint _amount) external onlyAdminOrAuthorizedEOA {
        transferFundsFromContract(address(escrowContract()), _amount);

        escrowContract().createEscrow(_amount);
    }

    function linkOfferToEscrow(uint _escrowIndex, address _offerAccount, uint _offerIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().linkOfferToEscrow(_escrowIndex, _offerAccount, _offerIndex);
    }

    function extendEscrow(uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().extendEscrow(_escrowIndex);
    }

    function withdrawEscrowEarly(uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().withdrawEscrowEarly(_escrowIndex);
    }

    function withdrawEscrowAfterReturn(uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
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

    function withdrawEscrowAfterCompletion(address _escrowAccount, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().withdrawEscrowAfterCompletion(_escrowAccount, _escrowIndex);
    }

    /////////////////////////
    // Universal functions //
    /////////////////////////

    function withdrawWalletFunds(address payable _to, uint _amount) external onlyAdminOrAuthorizedEOA {
        require(_to != address(0), "Cannot withdraw to zero address");
        transferFundsFromContract(_to, _amount);
    }
}
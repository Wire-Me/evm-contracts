// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {FxEscrow} from "../../fx-escrow/FxEscrow.sol";
import {SmartWalletMultiStorage} from "./SmartWalletMultiStorage.sol";

abstract contract AbstractSmartWalletMulti is SmartWalletMultiStorage {
    function transferFundsFromWallet(bytes32 _token, address _to, uint _amount) internal virtual;

    function escrowContract(bytes32 _token) public view virtual returns (FxEscrow);

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

    function transferFundsAndCreateEscrow(bytes32 _token, uint _amount) external onlyAdminOrAuthorizedEOA {
        FxEscrow fx = escrowContract(_token);
        transferFundsFromWallet(_token, address(fx), _amount);

        fx.createEscrow(_amount);
    }

    function linkOfferToEscrow(bytes32 _token, uint _escrowIndex, address _offerAccount, uint _offerIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract(_token).linkOfferToEscrow(_escrowIndex, _offerAccount, _offerIndex);
    }

    function extendEscrow(bytes32 _token, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract(_token).extendEscrow(_escrowIndex);
    }

    function withdrawEscrowEarly(bytes32 _token, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract(_token).withdrawEscrowEarly(_escrowIndex);
    }

    function withdrawEscrowAfterReturn(bytes32 _token, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract(_token).withdrawEscrowAfterReturn(_escrowIndex);
    }

    //////////////////////
    // Broker functions //
    //////////////////////

    function createOffer(
        bytes32 _token,
        address _escrowAccount,
        uint _escrowIndex,
        uint _feeBasisPoints
    ) external onlyAdmin {
        require(_escrowAccount != address(0), "Escrow account cannot be zero address");
        escrowContract(_token).createOffer(_escrowAccount, _escrowIndex, _feeBasisPoints);
    }

    function withdrawEscrowAfterCompletion(bytes32 _token, address _escrowAccount, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract(_token).withdrawEscrowAfterCompletion(_escrowAccount, _escrowIndex);
    }

    /////////////////////////
    // Universal functions //
    /////////////////////////

    function withdrawWalletFunds(bytes32 _token, address payable _to, uint _amount) external onlyAdminOrAuthorizedEOA {
        require(_to != address(0), "Cannot withdraw to zero address");
        transferFundsFromWallet(_token, _to, _amount);
    }
}
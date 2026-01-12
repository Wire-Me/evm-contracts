// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "../../fx-escrow/multi-token/FxEscrowMulti.sol";
import {SmartWalletMultiStorage} from "./SmartWalletMultiStorage.sol";
import "./configuration/WalletConfig.sol";

abstract contract AbstractSmartWalletMulti is SmartWalletMultiStorage {
    function transferFundsFromWallet(bytes32 _token, address _to, uint _amount) internal virtual;

    function escrowContract() public view virtual returns (FxEscrowMulti);

    modifier onlyAdminOrAuthorizedEOA() {
        require(msg.sender == _admin || msg.sender == _authorizedEOA, "Sender is not an authorized admin account or authorized EOA");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == _admin, "Sender is not an authorized admin account");
        _;
    }

    //////////////////////
    // Wallet functions //
    //////////////////////

    function setImplementation(address _impl) external onlyAdmin {
        _implementation = _impl;
    }

    function setAuthorizedEOA(address _eoa) external onlyAdminOrAuthorizedEOA {
        _authorizedEOA = _eoa;
    }

    function setWalletConfig(address _walletConfigAddress) external onlyAdmin {
        _config = WalletConfig(_walletConfigAddress);
    }

    function getErc20ContractAddress(bytes32 _token) external view returns (address) {
        return _config.erc20TokenContracts(_token);
    }

    function getFxEscrowContractAddress() external view returns (address) {
        return _config.fxEscrowMultiContract();
    }

    ////////////////////
    // User functions //
    ////////////////////

    function transferFundsAndCreateEscrow(bytes32 _token, uint _amount) external onlyAdminOrAuthorizedEOA {
        FxEscrowMulti fx = escrowContract();
        transferFundsFromWallet(_token, address(fx), _amount);

        fx.createEscrow(_token, _amount);
    }

    function linkOfferToEscrow(bytes32 _token, uint _escrowIndex, address _offerAccount, uint _offerIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().linkOfferToEscrow(_token, _escrowIndex, _offerAccount, _offerIndex);
    }

    function extendEscrow(bytes32 _token, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().extendEscrow(_token, _escrowIndex);
    }

    function withdrawEscrowEarly(bytes32 _token, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().withdrawEscrowEarly(_token, _escrowIndex);
    }

    function withdrawEscrowAfterReturn(bytes32 _token, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().withdrawEscrowAfterReturn(_token,_escrowIndex);
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
        escrowContract().createOffer(_token,_escrowAccount, _escrowIndex, _feeBasisPoints);
    }

    function withdrawEscrowAfterCompletion(bytes32 _token, address _escrowAccount, uint _escrowIndex) external onlyAdminOrAuthorizedEOA {
        escrowContract().withdrawEscrowAfterCompletion(_token,_escrowAccount, _escrowIndex);
    }

    /////////////////////////
    // Universal functions //
    /////////////////////////

    function withdrawWalletFunds(bytes32 _token, address payable _to, uint _amount) external onlyAdminOrAuthorizedEOA {
        require(_to != address(0), "Cannot withdraw to zero address");
        transferFundsFromWallet(_token, _to, _amount);
    }
}
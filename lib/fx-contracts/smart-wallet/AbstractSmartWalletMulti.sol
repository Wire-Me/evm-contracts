// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../fx-escrow/FxEscrowMulti.sol";
import {SmartWalletMultiStorage} from "./SmartWalletMultiStorage.sol";
import "./configuration/WalletConfig.sol";

abstract contract AbstractSmartWalletMulti is SmartWalletMultiStorage {
    bytes32 internal constant NATIVE_TOKEN = keccak256("NATIVE");

    function transferFundsFromWallet(bytes32 _token, address _to, uint _amount) internal virtual;

    function approveERC20Transfer(bytes32 _token, address _to, uint _amount) internal {
        if (_token == NATIVE_TOKEN) {
            revert("Cannot approve transfer of native currency");
        } else {
            IERC20 erc20TokenContract = IERC20(_config.erc20TokenContracts(_token));
            erc20TokenContract.approve(_to, _amount);
        }
    }

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

    function getAdmin() external view returns (address) {
        return _admin;
    }

    function getImplementation() external view returns (address) {
        return _implementation;
    }

    ////////////////////
    // User functions //
    ////////////////////

    function transferFundsAndCreateEscrow(bytes32 _token, uint _amount)
    external
    onlyAdminOrAuthorizedEOA
    {
        FxEscrowMulti fx = escrowContract();
        // transfer funds with transaction if using native currency
        if (_token == NATIVE_TOKEN) {
            (bool success, ) = address(fx).call{value: _amount}(
                abi.encodeWithSelector(
                    fx.createEscrow.selector,
                    _token,
                    _amount
                )
            );

            require(success, "Native escrow creation failed");
        } else {
            // If using ERC20 token use approve / transferFrom
            IERC20(_config.erc20TokenContracts(_token)).approve(address(fx), _amount);
            fx.createEscrow(_token, _amount);
        }
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

    function depositSecurityDeposit(bytes32 _token, uint _amount) external onlyAdminOrAuthorizedEOA {
        FxEscrowMulti fx = escrowContract();
        approveERC20Transfer(_token, address(fx), _amount);

        fx.upsertSecurityDeposit(_token, _amount);
    }

    function withdrawSecurityDeposit() external onlyAdminOrAuthorizedEOA {
        escrowContract().withdrawSecurityDeposit();
    }

    /////////////////////////
    // Universal functions //
    /////////////////////////

    function withdrawWalletFunds(bytes32 _token, address payable _to, uint _amount) external onlyAdminOrAuthorizedEOA {
        require(_to != address(0), "Cannot withdraw to zero address");
        transferFundsFromWallet(_token, _to, _amount);
    }
}
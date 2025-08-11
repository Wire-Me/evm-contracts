// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {SmartWalletERC20} from "./SmartWalletERC20.sol";


contract BrokerSmartWalletERC20 is SmartWalletERC20 {
    constructor(address _erc20TokenAddress, address _escrowContractAddress, address _authorizedUserExternalWallet)
        SmartWalletERC20(_erc20TokenAddress, _escrowContractAddress, _authorizedUserExternalWallet) {}

    function createOffer(
        address _escrowAccount,
        uint _escrowIndex
    ) external onlyAdminOrAuthorizedUser {
        require(_escrowAccount != address(0), "Escrow account cannot be zero address");
        escrowContract.createOffer(_escrowAccount, _escrowIndex);
    }

    function withdrawEscrow(address escrowAccount, uint escrowIndex) external onlyAdminOrAuthorizedUser {
        escrowContract.withdrawEscrowAfterCompletion(escrowAccount, escrowIndex);
    }
}
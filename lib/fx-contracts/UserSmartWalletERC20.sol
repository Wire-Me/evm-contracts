// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {SmartWalletERC20} from "./SmartWalletERC20.sol";


contract UserSmartWalletERC20 is SmartWalletERC20 {
    constructor(address _erc20TokenAddress, address _escrowContractAddress, address _authorizedUserExternalWallet)
        SmartWalletERC20(_erc20TokenAddress, _escrowContractAddress, _authorizedUserExternalWallet) {}

    function transferFundsAndCreateEscrow(uint _amount) external onlyAdminOrAuthorizedUser {
        erc20TokenContract.transfer(address(escrowContract), _amount);

        escrowContract.createEscrow(_amount);
    }

    function linkOfferToEscrow(uint _escrowIndex, address _offerAccount, uint _offerIndex) external onlyAdminOrAuthorizedUser {
        require(_offerAccount != address(0), "Offer account cannot be zero address");

        escrowContract.linkOfferToEscrow(_escrowIndex, _offerAccount, _offerIndex);
    }

    function extendEscrow(uint escrowIndex) external onlyAdminOrAuthorizedUser {
        escrowContract.extendEscrow(escrowIndex);
    }

    function withdrawEscrowEarly(uint escrowIndex) external onlyAdminOrAuthorizedUser {
        escrowContract.withdrawEscrowEarly(escrowIndex);
    }

    function withdrawEscrow(uint escrowIndex) external onlyAdminOrAuthorizedUser {
        escrowContract.withdrawEscrowAfterReturn(escrowIndex);
    }
}
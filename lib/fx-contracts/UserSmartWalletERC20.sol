// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {SmartWalletERC20} from "./SmartWalletERC20.sol";


contract UserSmartWalletERC20 is SmartWalletERC20 {
    constructor(address _escrowContractAddress, address _authorizedUserExternalWallet)
        SmartWalletERC20(_escrowContractAddress, _authorizedUserExternalWallet) {}

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
}
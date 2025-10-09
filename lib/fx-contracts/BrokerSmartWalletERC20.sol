// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {SmartWalletERC20} from "./SmartWalletERC20.sol";

// Deprecated
contract BrokerSmartWalletERC20 is SmartWalletERC20 {
    constructor(address _escrowContractAddress, address _authorizedUserExternalWallet)
        SmartWalletERC20(_escrowContractAddress, _authorizedUserExternalWallet) {}

//    function createOffer(
//        address _escrowAccount,
//        uint _escrowIndex
//    ) external {
//        require(_escrowAccount != address(0), "Escrow account cannot be zero address");
//        escrowContract.createOffer(_escrowAccount, _escrowIndex);
//    }
//
//    function withdrawEscrow(address escrowAccount, uint escrowIndex) external {
//        escrowContract.withdrawEscrowAfterCompletion(escrowAccount, escrowIndex);
//    }
}
// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

interface SmartWallet {
    function transferFundsAndCreateEscrow(uint _amount) external;
    function linkOfferToEscrow(uint _escrowIndex, address _offerAccount, uint _offerIndex) external;
    function extendEscrow(uint _escrowIndex) external;
    function withdrawEscrowEarly(uint _escrowIndex) external;
    function withdrawEscrow(uint _escrowIndex) external;
    function createOffer(
        address _escrowAccount,
        uint _escrowIndex,
        uint _feeBasisPoints
    ) external;
    function withdrawEscrow(address _escrowAccount, uint _escrowIndex) external;
    function withdrawWalletFunds(address payable _to, uint _amount) external;
}
// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

interface FxEscrow {
    event EscrowCreated(
        address indexed _creatingUser,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        uint _expirationTimestamp,
        uint _amount
    );

    event OfferCreated(
        address indexed _creatingBroker,
        uint indexed _offerIndex,
        bytes32 indexed _currency,
        address _escrowUser,
        uint _escrowIndex
    );

    event EscrowSelectedOffer(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _creatorOfOffer,
        uint _offerIndex
    );

    event EscrowFrozen(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowDefrosted(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowFundsReturnedToUser(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowExpirationExtended(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowWithdrawnAfterCompletion(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );

    event EscrowWithdrawnEarly(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );

    event EscrowWithdrawnAfterReturn(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );
}
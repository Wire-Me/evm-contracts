// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

/// @author Ian Pierce
library EscrowStructs {
    struct Relay {
        /// @notice the address of the buyer's account
        address payer;
        /// @notice the address of the seller's account
        address payee;
        /// @notice the address of the account which initially created the agreement (must be either the payer or the payee)
        address creator;
        /// @notice 'true' if initialized
        bool initialized;
        /// @notice the amount of funds required to be deposited by the payer
        uint requiredBalance;
        /// @notice the current balance of the relay (the amount of funds deposited by the payer)
        uint currentBalance;
        /// @notice 'true' if the relay is locked (the nobody cannot withdraw funds)
        /// @dev This property is never set to 'false' after being set to 'true'. For funds to be withdrawn, the relay must be either approved or returned (see below).
        bool isLocked;
        /// @notice 'true' if the relay is returning (the payer can withdraw funds)
        bool isReturning;
        /// @notice 'true' if the relay is approved (the payee can withdraw funds)
        bool isApproved;
        /// @notice The epoch timestamp (seconds) at which the relay will be automatically approved if not already approved (funds are able to be withdrawn by the payee).
        /// @dev For conditional relays this is the refund deadline, and for guaranteed relays this is the completion date.
        uint automaticallyUnlockAt;
        /// @notice The epoch timestamp (seconds) after which the relay can be refunded. (funds are able to be withdrawn by the payer).
        /// @dev For conditional relays this is the completion date, and for guaranteed relays this is zero (guaranteed relays can be returned at any time).
        uint allowReturnAfter;
    }

    struct FXEscrow {
        /// @notice the amount of funds held in escrow
        uint amount;
        /// @notice the epoch timestamp (seconds) at which the escrow was created
        uint createdAt;
        /// @notice the epoch timestamp (seconds) at which the escrow will expire
        uint expirationTimestamp;
        /// @notice 'true' if the funds of the escrow have been withdrawn
        bool isWithdrawn;
        /// @notice 'true' if the escrow is frozen and cannot be withdrawn even after expiration
        bool isFrozen;
        /// @notice 'true' if the user can withdraw the funds of the escrow
        bool isReturned;
        /// @notice the address of the broker account who has made the offer which has been selected by the user
        address selectedBrokerAccount;
        /// @notice the index of the offer made by the broker account which has been selected by the user
        uint selectedOfferIndex;
    }

    struct FXEscrowOffer {
        /// @notice the account address of the user who created the escrow that this offer is linked to
        address escrowAccount;
        /// @notice the escrow index that this offer is linked to
        uint escrowIndex;
        /// @notice The epoch timestamp (seconds) at which the offer was created
        uint createdAt;
    }
}


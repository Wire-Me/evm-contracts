// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.23;

import {IRelay} from "./IRelay.sol";

/// @author Ian Pierce
interface IDisputableRelay {
    struct Dispute {
        /// @notice The address of the account which will moderate the dispute
        address moderator;
        /// @notice The fee going to the moderator in basis points (1 basis point = 0.01%, 100 basis points = 1%, 10000 basis points = 100%)
        uint basisPointFee;
        /// @notice If a dispute has been initiated
        bool isDisputed;
        /// @notice If a dispute has been resolved
        bool isResolved;
    }

    event RelayDisputed(address indexed _creator, uint indexed _agreementIndex);
    event DisputeResolved(address indexed _creator, uint indexed _agreementIndex);
    event DistributionTableUpdated(address indexed _creator, uint indexed _agreementIndex, address _participant, uint _value);

    /// @notice Creates a new relay agreement between two parties.
    /// ---
    /// @param _requiredBalance The amount of funds required to be deposited by the payer.
    /// @param _payer The address of the payer (the buyer in the agreement).
    /// @param _payee The address of the payee (the seller in the agreement).
    /// @param _automaticallyApprovedAt The epoch timestamp (seconds) at which the relay will be automatically approved if not already approved (funds are able to be withdrawn by the payee).
    /// @dev _automaticallyApprovedAt - For conditional relays this is the refund deadline, and for guaranteed relays this is the completion date.
    /// @param _allowReturnAfter The epoch timestamp (seconds) after which the relay can be refunded. (funds are able to be withdrawn by the payer).
    /// @dev _allowReturnAfter - For conditional relays this is the completion date, and for guaranteed relays this must be zero (guaranteed relays can be returned at any time).
    /// @param _moderator The address of the moderator who will handle disputes for this relay.
    /// @param _moderatorBasisPointFee The fee going to the moderator in basis points (1 basis point = 0.01%, 100 basis points = 1%, 10000 basis points = 100%).
    /// ---
    /// @custom:revert If the payer is the zero address, or if the payee is the zero address, or if the required balance is zero.
    /// @custom:revert If the moderator is the zero address, or if the moderator basis point fee is zero.
    /// @custom:revert If the automatically approved at timestamp is in the past
    /// @custom:revert If the automatically approved at timestamp is less than the allow return after timestamp.
    /// @custom:revert If the payer and payee are the same address.
    /// @custom:revert If the caller is not the payer or the payee.
    /// ---
    /// @custom:event Emits a RelayCreated event.
    function createRelay(uint _requiredBalance, address _payer, address _payee, uint _automaticallyApprovedAt, uint _allowReturnAfter, address _moderator, uint _moderatorBasisPointFee) external;

    /// @notice Initiates a dispute for the relay agreement
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// ---
    /// @custom:revert If the relay is not locked
    /// @custom:revert If the relay is already approved or returned.
    /// @custom:revert If allReturnAfter timestamp has not passed.
    /// @custom:revert If the caller is not the payer or payee
    /// ---
    /// @custom:event Emits a RelayDisputed event.
    function disputeRelay(address _creator, uint _index) external;

    /// @notice Called by moderator when dispute is resolved
    /// ---
    /// @custom:revert If called by a user that isn't the moderator
    /// ---
    /// @custom:event Emits a DisputeResolved event.
    function resolveDispute(address _creator, uint _index) external;

    /// @notice Sets the value for the given participant in the distribution table for the relay.
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// ---
    /// @custom:revert If the relay has not been disputed by the participants
    /// @custom:revert If the caller is not the moderator of the relay dispute
    /// ---
    /// @custom:event Emits a RelayDisputed event.
    function setDistributionTableForParticipant(address _creator, uint _index, address _participant, uint _value) external;
}
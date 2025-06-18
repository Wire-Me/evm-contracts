// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.23;

import {IRelay} from "./IRelay.sol";

/// @author Ian Pierce
interface IUndisputableRelay is IRelay {
    /// @notice Creates a new relay agreement between two parties.
    /// ---
    /// @param _requiredBalance The amount of funds required to be deposited by the payer.
    /// @param _payer The address of the payer (the buyer in the agreement).
    /// @param _payee The address of the payee (the seller in the agreement).
    /// @param _automaticallyApprovedAt The epoch timestamp (seconds) at which the relay will be automatically approved if not already approved (funds are able to be withdrawn by the payee).
    /// @dev _automaticallyApprovedAt - For conditional relays this is the refund deadline, and for guaranteed relays this is the completion date.
    /// @param _allowReturnAfter The epoch timestamp (seconds) after which the relay can be refunded. (funds are able to be withdrawn by the payer).
    /// @dev _allowReturnAfter - For conditional relays this is the completion date, and for guaranteed relays this must be zero (guaranteed relays can be returned at any time).
    /// ---
    /// @custom:revert If the payer is the zero address, or if the payee is the zero address, or if the required balance is zero.
    /// @custom:revert If the automatically approved at timestamp is in the past
    /// @custom:revert If the automatically approved at timestamp is less than the allow return after timestamp.
    /// @custom:revert If the payer and payee are the same address.
    /// @custom:revert If the caller is not the payer or the payee.
    /// ---
    /// @custom:event Emits a RelayCreated event.
    function createRelay(uint _requiredBalance, address _payer, address _payee, uint _automaticallyApprovedAt, uint _allowReturnAfter) external;
}
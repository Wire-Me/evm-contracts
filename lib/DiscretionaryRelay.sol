// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "./EscrowStructs.sol";
import {UndisputableRelayBase} from "./UndisputableRelayBase.sol";

/// @author Ian Pierce
contract DiscretionaryRelay is UndisputableRelayBase {
    constructor(string memory _symbol, uint _basisPointFee) UndisputableRelayBase(_symbol, _basisPointFee) {}

    function returnRelay(address _creator, uint _index) external override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        require(relay.isLocked == true, ErrRelayNotLocked());
        require(!relay.isApproved && !relay.isReturning, ErrRelayAlreadyApprovedOrReturned());
        require(relay.allowReturnAfter < block.timestamp, ErrNotAfterAllowReturnTimestamp());

        require(relay.payer == msg.sender, ErrSenderNotPayer());

        relays[_creator][_index].isReturning = true;

        emit RelayReturned(_creator, _index);
    }
}
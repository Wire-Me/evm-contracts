// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.23;

import "./EscrowStructs.sol";
import {UndisputableRelayBase} from "./UndisputableRelayBase.sol";

/// @author Ian Pierce
contract DiscretionaryRelay is UndisputableRelayBase {
    constructor(string memory _symbol, uint _basisPointFee) UndisputableRelayBase(_symbol, _basisPointFee) {}

    function returnRelay(address _creator, uint _index) external override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        require(relay.isLocked == true, "TransactionRelay: can only return funds if locked");
        require(relay.isApproved == false, "TransactionRelay: can not return funds if already approved");
        require(relay.isReturning == false, "TransactionRelay: can not return funds if already returning");
        require(relay.allowReturnAfter < block.timestamp, "TransactionRelay: can not return funds before allowReturnAfter");

        require(relay.payer == msg.sender, "TransactionRelay: only the payer can return funds (if conditional)");

        relays[_creator][_index].isReturning = true;

        emit RelayReturned(_creator, _index);
    }
}
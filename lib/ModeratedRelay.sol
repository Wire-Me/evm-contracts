import "./EscrowStructs.sol";
import {DisputableRelayBase} from "./DisputableRelayBase.sol";

contract ModeratedRelay is DisputableRelayBase {
    constructor(string memory _symbol, uint _basisPointFee) DisputableRelayBase(_symbol, _basisPointFee) {}

    function approveRelay(address _creator, uint _index) external virtual override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        Dispute storage dispute = disputes[_creator][_index];

        require(relay.isLocked, "TimeLockRelay: relay must be locked before approval");
        require(msg.sender == relay.payer, "TimeLockRelay: only the payer can approve the relay");
        require(!relay.isApproved && !relay.isReturning, "TimeLockRelay: relay is already approved or returned");

        require(!dispute.isDisputed, "ModeratedRelay: relay is disputed, cannot approve");

        relay.isApproved = true;

        emit RelayApproved(_creator, _index);
    }

    function returnRelay(address _creator, uint _index) external override {
        revert("ModeratedRelay: returnRelay is not supported in ModeratedRelay contract. Use disputeRelay instead.");
    }
}
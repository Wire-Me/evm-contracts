import "./EscrowStructs.sol";

abstract contract RelayStateReturnable {
    // Returns information about the agreement
    function getRelayActors(address _creator, uint _index) external view override returns (address, address, address, bool) {
        Relay storage relay = relays[_creator][_index];
        return (relay.payer, relay.payee, relay.creator, relay.initialized);
    }

    function getRelayBalances(address _creator, uint _index) external view override returns (uint, uint, bool) {
        Relay storage relay = relays[_creator][_index];
        return (relay.requiredBalance, relay.currentBalance, relay.initialized);
    }

    function getRelayState(address _creator, uint _index) external view override returns (bool, bool, bool, uint, uint, bool) {
        Relay storage relay = relays[_creator][_index];
        return (relay.isLocked, relay.isReturning, relay.isApproved, relay.automaticallyUnlockAt, relay.allowReturnAfter, relay.initialized);
    }
}
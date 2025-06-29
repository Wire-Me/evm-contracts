// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.23;

import "./EscrowStructs.sol";
import {IRelay} from "./IRelay.sol";

/// @author Ian Pierce
abstract contract RelayBase is IRelay {
    address payable public owner; // The account which deployed this contract
    string public coinSymbol; // The symbol of the coin used in this contract ('ETH', 'USDC', 'MATIC', etc.)
    uint public basisPointFee; // The fee for using this contract in basis points (1 basis point = 0.01%, 100 basis points = 1%, 10000 basis points = 100%)

    mapping(address => EscrowStructs.Relay[]) public relays;
    mapping(address => uint) public accountBalances;

    constructor(string memory _symbol, uint _basisPointFee) {
        require(_basisPointFee <= 10000, "TransactionRelay: basis point fee must be less than or equal to 10000 (100%)");
        require(bytes(_symbol).length > 0, "TransactionRelay: coin symbol must not be empty");
        owner = payable(msg.sender);
        coinSymbol = _symbol;
        basisPointFee = _basisPointFee;
    }

    // Revert any plain ETH transfer (no calldata)
    receive() external payable {
        revert("Direct ETH transfers not allowed");
    }

    // Revert any ETH sent with calldata
    fallback() external payable {
        revert("Fallback function called. ETH not accepted");
    }

    // Returns information about the agreement
    function getRelayActors(address _creator, uint _index) external view override returns (address, address, address, bool) {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        return (relay.payer, relay.payee, relay.creator, relay.initialized);
    }

    function getRelayBalances(address _creator, uint _index) external view override returns (uint, uint, bool) {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        return (relay.requiredBalance, relay.currentBalance, relay.initialized);
    }

    function getRelayState(address _creator, uint _index) external view override returns (bool, bool, bool, uint, uint, bool) {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        return (relay.isLocked, relay.isReturning, relay.isApproved, relay.automaticallyUnlockAt, relay.allowReturnAfter, relay.initialized);
    }

    function depositFunds(address _creator, uint _index) external override payable {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        require(msg.value == relay.requiredBalance, ErrDepositAmountNotEqualToRequiredAmount());
        relay.currentBalance += msg.value;
        relay.isLocked = true; // Lock the relay after deposit

        emit FundsDeposited(_creator, _index, msg.value, relays[_creator][_index].currentBalance, relays[_creator][_index].requiredBalance);
    }

    function stashFunds(address _creator, uint _index) external virtual override;

    function withdrawFunds(address _creator, uint _index) external virtual override;

    function approveRelay(address _creator, uint _index) external virtual override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        require(relay.isLocked, "TimeLockRelay: relay must be locked before approval");
        require(msg.sender == relay.payer, "TimeLockRelay: only the payer can approve the relay");
        require(!relay.isApproved && !relay.isReturning, "TimeLockRelay: relay is already approved or returned");

        relay.isApproved = true;

        emit RelayApproved(_creator, _index);
    }

    function returnRelay(address _creator, uint _index) external virtual override;

    function _calculateBasisPointProportion(uint _amount, uint basisPoints) internal pure returns (uint) {
        return (_amount * basisPoints) / 10000;
    }

    function _isPassedAutomaticUnlockTime(address _creator, uint _index) internal view returns (bool) {
        return relays[_creator][_index].automaticallyUnlockAt < block.timestamp;
    }
}
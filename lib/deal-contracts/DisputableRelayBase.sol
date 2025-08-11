// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {RelayBase} from "./RelayBase.sol";
import {IRelay} from "./IRelay.sol";
import {IDisputableRelay} from "./IDisputableRelay.sol";
import {EscrowStructs} from "../EscrowStructs.sol";

/// @author Ian Pierce
abstract contract DisputableRelayBase is RelayBase, IDisputableRelay {
    /// @notice Contains the dispute configuration for each relay
    mapping(address => Dispute[]) public disputes;
    /// @notice Contains the distribution tables for a relay if a dispute has been initiated.
    /// @dev Each distribution table maps a participant address to a value representing their share of the escrow funds in basis points.
    /// @dev e.g. if the payer is mapped to 5,000 (50%), and the payee is mapped to 5,000 (50%) then they will split the escrow funds evenly
    mapping(address => mapping(uint => mapping(address => uint))) public distributionTables;

    constructor(string memory _symbol, uint _basisPointFee) RelayBase(_symbol, _basisPointFee) {}

    function createRelay(uint _requiredBalance, address _payer, address _payee, uint _automaticallyUnlockAt, uint _allowReturnAfter, address _moderator, uint _moderatorBasisPointFee) public virtual override {
        require(msg.sender == _payer || msg.sender == _payee, "TransactionRelay: only the payer or payee can create a relay");
        require(_payer != _payee, "TransactionRelay: payer and payee must be different addresses");
        require(_requiredBalance > 0, "TransactionRelay: required balance must be greater than 0");
        require(_payer != address(0), "TransactionRelay: payer address must not be 0x0");
        require(_payee != address(0), "TransactionRelay: payee address must not be 0x0");
        require(_moderator != address(0), "TransactionRelay: moderator address must not be 0x0");
        require(_moderatorBasisPointFee > 0, "TransactionRelay: moderator basis point fee must be greater than zero");
        require(_automaticallyUnlockAt > block.timestamp, "TransactionRelay: automatically approved at timestamp must be in the future");
        require(_automaticallyUnlockAt > _allowReturnAfter, "TransactionRelay: automatically approved at timestamp must be after allow return after timestamp");

        disputes[msg.sender].push(
            Dispute({
                moderator: _moderator,
                basisPointFee: _moderatorBasisPointFee,
                isDisputed: false,
                isResolved: false
            })
        );

        relays[msg.sender].push(
            EscrowStructs.Relay({
                payer: _payer,
                payee: _payee,
                creator: msg.sender,
                initialized: true,
                requiredBalance: _requiredBalance,
                currentBalance: 0,
                isLocked: false,
                isReturning: false,
                isApproved: false,
                automaticallyUnlockAt: _automaticallyUnlockAt,
                allowReturnAfter: _allowReturnAfter
            })
        );

        emit RelayCreated(msg.sender, relays[msg.sender].length - 1, _payer, _payee);
    }

    function isDisputable() external pure override returns (bool) {
        return true;
    }

    function disputeRelay(address _creator, uint _index) external override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        require(disputes[_creator][_index].isDisputed == false, "TransactionRelay: dispute already initiated");
        require(msg.sender == relay.payer, "TransactionRelay: only the payer can initiate dispute");
        require(relay.isLocked == true, "TransactionRelay: can only dispute if relay is locked");
        require(relay.isApproved == false, "TransactionRelay: can not dispute if relay is already approved");
        require(relay.isReturning == false, "TransactionRelay: can not dispute if relay is already returned");
        require(relay.allowReturnAfter < block.timestamp, "TransactionRelay: can not dispute before allow return after timestamp");

        disputes[_creator][_index].isDisputed = true;

        emit RelayDisputed(_creator, _index);
    }

    function resolveDispute(address _creator, uint _index) external override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        require(disputes[_creator][_index].isDisputed == true, "TransactionRelay: dispute must be initiated before resolving");
        require(msg.sender == disputes[_creator][_index].moderator, "TransactionRelay: only the moderator can resolve the dispute");
        require(distributionTables[_creator][_index][relay.payer] + distributionTables[_creator][_index][relay.payee] == 10_000, "TransactionRelay: distribution table for this relay must sum to 10,000 basis points (100%)");

        // Mark the dispute as resolved
        disputes[_creator][_index].isResolved = true;

        emit DisputeResolved(_creator, _index);
    }

    function setDistributionTableForParticipant(address _creator, uint _index, address _participant, uint _value) external override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        require(disputes[_creator][_index].isDisputed == true, "TransactionRelay: dispute must be initiated before setting distribution table");
        require(msg.sender == disputes[_creator][_index].moderator, "TransactionRelay: only the moderator can set the distribution table");
        require(_participant == relay.payer || _participant == relay.payee, "TransactionRelay: participant address be the payer or payee in the relay");

        // Set the value in the distribution table
        distributionTables[_creator][_index][_participant] = _value;

        emit DistributionTableUpdated(_creator, _index, _participant, _value);
    }

    function stashFunds(address _creator, uint _index) external virtual override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        _validateWithdrawal(_creator, _index);

        (uint amountOwed, uint platformFee) = _calculateAmountAndFeeOwed(_creator, _index);

        // Add the amount owed to the account balance of the stasher
        accountBalances[msg.sender] += amountOwed;
        // Adds fee to the owner's account balance
        accountBalances[owner] += platformFee;
        relay.currentBalance -= (amountOwed + platformFee);

        emit FundsStashed(_creator, _index, (amountOwed + platformFee), amountOwed, platformFee);
    }

    function withdrawFunds(address _creator, uint _index) external virtual override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        _validateWithdrawal(_creator, _index);

        (uint amountOwed, uint platformFee) = _calculateAmountAndFeeOwed(_creator, _index);

        relay.currentBalance -= (amountOwed + platformFee);
        // Adds platform fee to the owner's account balance
        accountBalances[owner] += platformFee;
        payable(msg.sender).transfer(amountOwed);

        emit FundsWithdrawn(_creator, _index, (amountOwed + platformFee), amountOwed, platformFee);
    }

    function _calculateAmountAndFeeOwed(address _creator, uint _index) private view returns (uint, uint) {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        Dispute storage dispute = disputes[_creator][_index];
        uint platformFee = 0;
        uint grossAmount = 0;

        if (!dispute.isDisputed && relay.isLocked && (relay.isReturning || relay.isApproved)) {
            platformFee = _calculateBasisPointProportion(relay.currentBalance, basisPointFee);
            grossAmount = relay.currentBalance - platformFee;
        } else if (dispute.isDisputed && dispute.isResolved) {
            uint moderatorAmountOwed = _calculateBasisPointProportion(relay.currentBalance, disputes[_creator][_index].basisPointFee);
            grossAmount = _calculateBasisPointProportion(relay.currentBalance - moderatorAmountOwed, distributionTables[_creator][_index][msg.sender]);
            platformFee = _calculateBasisPointProportion(grossAmount, basisPointFee);
        }

        return (grossAmount, platformFee);
    }

    /// @notice Validates the withdrawal of funds from the relay.
    /// @custom:revert If the relay is not locked only the payer can withdraw funds. Reverts otherwise
    /// @custom:revert If the relay is locked & returning only the payer can withdraw funds & _amount must equal the current balance. Reverts otherwise.
    /// @custom:revert If the relay is locked & approved only the payee can withdraw funds & _amount must equal the current balance. Reverts otherwise.
    /// @custom:revert If the relay is locked & not approved only the payee can withdraw funds & it must be passed the automatic approval timestamp. Reverts otherwise.
    function _validateWithdrawal(address _creator, uint _index) internal view {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        Dispute storage dispute = disputes[_creator][_index];

        if (relay.isLocked) {
            if (relay.isReturning) {
                require(relay.payer == msg.sender, "TransactionRelay: only the payer can withdraw funds (if marked as returning)");
            } else if (relay.isApproved) {
                require(relay.payee == msg.sender, "TransactionRelay: only the payee can withdraw funds (if locked and approved)");
            } else if (dispute.isDisputed) {
                require(dispute.isResolved, "TransactionRelay: dispute must be resolved before withdrawal");
                require(msg.sender == dispute.moderator || msg.sender == relay.payer || msg.sender == relay.payee, "TransactionRelay: only the moderator and participants can withdraw funds if disputed");
            } else {
                require(_isPassedAutomaticUnlockTime(_creator, _index), "TransactionRelay: can not withdraw funds if not approved and not passed automatic unlock time");
                require(relay.payee == msg.sender, "TransactionRelay: only the payee can withdraw funds (if locked and not approved)");
            }
        } else {
            revert("TransactionRelay: can not withdraw funds if relay isn't locked");
        }
    }
}

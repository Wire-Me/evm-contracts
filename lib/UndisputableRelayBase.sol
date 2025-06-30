// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import {EscrowStructs} from "./EscrowStructs.sol";
import {IRelay} from "./IRelay.sol";
import {IUndisputableRelay} from "./IUndisputableRelay.sol";
import {RelayBase} from "./RelayBase.sol";

/// @author Ian Pierce
abstract contract UndisputableRelayBase is RelayBase, IUndisputableRelay {
    constructor(string memory _symbol, uint _basisPointFee) RelayBase(_symbol, _basisPointFee) {}

    function createRelay(uint _requiredBalance, address _payer, address _payee, uint _automaticallyUnlockAt, uint _allowReturnAfter) public virtual override {
        require(msg.sender == _payer || msg.sender == _payee, ErrSenderNotPayerOrPayee());
        require(_payer != _payee, ErrPayerEqualsPayee());
        require(_requiredBalance > 0, ErrRequiredBalanceNotGreaterThanZero());
        require(_payer != address(0), ErrPayerHasZeroAddress());
        require(_payee != address(0), ErrPayeeHasZeroAddress());
        require(_automaticallyUnlockAt > block.timestamp, ErrUnlockAtNotInFuture());
        require(_automaticallyUnlockAt > _allowReturnAfter, ErrUnlockAtNotGreaterThanReturnAfter());

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
        return false;
    }

    function stashFunds(address _creator, uint _index) external virtual override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        _validateWithdrawal(_creator, _index);

        (uint amountOwed, uint platformFee) = _calculateAmountWithdrawn(_creator, _index);

        // subtract the amount owed and platform fee from the relay's current balance
        relay.currentBalance -= (amountOwed + platformFee);
        // Adds fee to the owner's account balance
        accountBalances[owner] += platformFee;
        // Adds the amount owed to the payer's account balance
        accountBalances[msg.sender] += amountOwed;

        emit FundsStashed(_creator, _index, (amountOwed + platformFee), amountOwed, platformFee);
    }

    function withdrawFunds(address _creator, uint _index) external virtual override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        _validateWithdrawal(_creator, _index);

        (uint amountOwed, uint platformFee) = _calculateAmountWithdrawn(_creator, _index);

        // subtract the amount owed and platform fee from the relay's current balance
        relay.currentBalance -= (amountOwed + platformFee);
        // Adds fee to the owner's account balance
        accountBalances[owner] += platformFee;
        // transfer the sender the amount owed
        payable(msg.sender).transfer(amountOwed);

        emit FundsWithdrawn(_creator, _index, (amountOwed + platformFee), amountOwed, platformFee);
    }

    /// @notice Validates the withdrawal of funds from the relay.
    /// @custom:revert If the relay is not locked only the payer can withdraw funds. Reverts otherwise
    /// @custom:revert If the relay is locked & returning only the payer can withdraw funds & _amount must equal the current balance. Reverts otherwise.
    /// @custom:revert If the relay is locked & approved only the payee can withdraw funds & _amount must equal the current balance. Reverts otherwise.
    /// @custom:revert If the relay is locked & not approved only the payee can withdraw funds & it must be passed the automatic approval timestamp. Reverts otherwise.
    function _validateWithdrawal(address _creator, uint _index) internal view {
        EscrowStructs.Relay storage relay = relays[_creator][_index];

        if (!relay.isLocked) {
            revert ErrRelayNotLocked();
        } else if (relay.isApproved) {
            require(relay.payee == msg.sender, ErrSenderNotPayee());
        } else if (relay.isReturning) {
            require(relay.payer == msg.sender, ErrSenderNotPayer());
        } else {
            require(_isPassedAutomaticUnlockTime(_creator, _index), ErrNotPastUnlockTime());
            require(relay.payee == msg.sender, ErrSenderNotPayee());
        }
    }

    function _calculateAmountWithdrawn(address _creator, uint _index) private view returns (uint, uint) {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        uint platformFee = 0;
        uint grossAmount = 0;

        // If the relay is returned or approved or if the automatic unlock time has passed
        if (relay.isApproved || relay.isReturning || _isPassedAutomaticUnlockTime(_creator, _index)) {
            platformFee = _calculateBasisPointProportion(relay.currentBalance, basisPointFee);
            grossAmount = relay.currentBalance - platformFee;
        }

        return (grossAmount, platformFee);
    }
}
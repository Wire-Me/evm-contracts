// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

/// @author Ian Pierce
interface IRelay {
    event RelayCreated(address indexed _creator, uint indexed _agreementIndex, address _buyer, address _seller);
    event FundsDeposited(address indexed _creator, uint indexed _agreementIndex, uint amountDeposited, uint currentBalance, uint requiredBalance);
    event FundsWithdrawn(address indexed _creator, uint indexed _agreementIndex, uint principleAmount, uint grossAmount, uint platformFee);
    event FundsStashed(address indexed _creator, uint indexed _agreementIndex, uint principleAmount, uint grossAmount, uint platformFee);
    event RelayLocked(address indexed _creator, uint indexed _agreementIndex);
    event RelayApproved(address indexed _creator, uint indexed _agreementIndex);
    event RelayReturned(address indexed _creator, uint indexed _agreementIndex);

    error ErrSenderNotPayerOrPayee();
    error ErrPayerEqualsPayee();
    error ErrRequiredBalanceNotGreaterThanZero();
    error ErrPayerHasZeroAddress();
    error ErrPayeeHasZeroAddress();
    error ErrUnlockAtNotInFuture();
    error ErrUnlockAtNotGreaterThanReturnAfter();
    error ErrDepositAmountNotEqualToRequiredAmount();
    error ErrRelayNotLocked();
    error ErrSenderNotPayer();
    error ErrSenderNotPayee();
    error ErrRelayAlreadyApprovedOrReturned();
    error ErrNotAfterAllowReturnTimestamp();
    error ErrNotPastUnlockTime();

    /// @notice Gets information about the actors involved in the relay agreement.
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// ---
    /// @return A tuple containing the following information in this order: (Addresses of the payer, Addresses of the payee, relay creator address, initialization boolean).
    function getRelayActors(address _creator, uint _index) external view returns (address, address, address, bool);

    /// @notice Gets the balances of the relay agreement.
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// ---
    /// @return A tuple containing the following information in this order: (Required relay balance, Current relay balance, Initialization boolean).
    function getRelayBalances(address _creator, uint _index) external view returns (uint, uint, bool);

    /// @notice Gets the state of the relay agreement.
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// ---
    /// @return A tuple containing the following information in this order: (Is the relay locked, Is the relay returning, Is the relay approved, Automatically approved at timestamp, Allow return after timestamp, Initialization boolean).
    function getRelayState(address _creator, uint _index) external view returns (bool, bool, bool, uint, uint, bool);

    /// @notice Deposits funds into the relay agreement.
    /// @dev Adds the msg.value to the current balance of the relay specified.
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// ---
    /// @custom:revert If the deposit amount is zero.
    /// @custom:revert If the caller is not the payer of the relay agreement.
    /// ---
    /// @custom:event Emits a FundsDeposited event.
    function depositFunds(address _creator, uint _index) external payable;

    /// @notice Stashes the funds of the relay into the account balance of the sender.
    /// @dev Used if the user wants to withdraw funds from the relay without transferring funds to their account.
    /// @dev Must pass the _validateWithdrawal function to ensure the withdrawal is valid (see _validateWithdrawal docs in contract).
    /// @dev Calculates the amount to stash based on the fee basis point value
    /// @dev The fee portion of the balance is transferred to the contract owner's account balance.
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// ---
    /// @custom:event Emits a FundsStashed event.
    function stashFunds(address _creator, uint _index) external;

    /// @notice Withdraws all funds from the relay agreement.
    /// @dev Must pass the _validateWithdrawal function to ensure the withdrawal is valid (see _validateWithdrawal docs in contract).
    /// @dev Calculates the amount to withdraw based on the fee basis point value
    /// @dev The fee portion of the balance is transferred to the contract owner's account balance.
    /// @dev Transfers funds to the sender
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// ---
    /// @custom:event Emits a FundsWithdrawn event.
    function withdrawFunds(address _creator, uint _index) external;

    /// @notice Locks the relay agreement, preventing any withdrawals until it is either approved or returned.
    /// ---
    /// @custom:revert If the relay is already locked.
    /// @custom:revert If the caller is not the payer of the relay agreement.
    /// @custom:revert If the relay's current balance is not equal to the required balance.
    /// ---
    /// @custom:event Emits a RelayLocked event.
//    function lockRelay(address _creator, uint _index) external;

    /// @notice Approves the relay agreement, allowing the payee to withdraw funds.
    /// ---
    /// @custom:revert If the relay is not locked
    /// @custom:revert If the caller is not the payer of the relay agreement.
    /// @custom:revert If the relay is already approved or returned.
    /// ---
    /// @custom:event Emits a RelayApproved event.
    function approveRelay(address _creator, uint _index) external;

    /// @notice Returns the relay agreement, allowing the payer to withdraw funds.
    /// ---
    /// @custom:revert If the relay is not locked
    /// @custom:revert If the relay is already approved or returned.
    /// @custom:revert If allReturnAfter timestamp has not passed.
    /// @custom:revert For guaranteed relays - If the caller is not the payee of the relay agreement.
    /// @custom:revert For conditional relays - If the caller is not the payer of the relay agreement.
    /// ---
    /// @custom:event Emits a RelayReturned event.
    function returnRelay(address _creator, uint _index) external;

    /// @notice If the relays in this contract are disputable
    /// ---
    /// @return A boolean indicating whether the relay is disputable or not.
    function isDisputable() external pure returns (bool);
}
// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.23;

/// @author Ian Pierce
interface IRelay {
    struct Relay {
        /// @notice the address of the buyer's account
        address payer;
        /// @notice the address of the seller's account
        address payee;
        /// @notice the address of the account which initially created the agreement (must be either the payer or the payee)
        address creator;
        /// @notice 'true' if initialized
        bool initialized;
        /// @notice the amount of funds required to be deposited by the payer
        uint requiredBalance;
        /// @notice the current balance of the relay (the amount of funds deposited by the payer)
        uint currentBalance;
        /// @notice 'true' if the relay is locked (the nobody cannot withdraw funds)
        /// @dev This property is never set to 'false' after being set to 'true'. For funds to be withdrawn, the relay must be either approved or returned (see below).
        bool isLocked;
        /// @notice 'true' if the relay is returning (the payer can withdraw funds)
        bool isReturning;
        /// @notice 'true' if the relay is approved (the payee can withdraw funds)
        bool isApproved;
        /// @notice The epoch timestamp (seconds) at which the relay will be automatically approved if not already approved (funds are able to be withdrawn by the payee).
        /// @dev For conditional relays this is the refund deadline, and for guaranteed relays this is the completion date.
        uint automaticallyApprovedAt;
        /// @notice The epoch timestamp (seconds) after which the relay can be refunded. (funds are able to be withdrawn by the payer).
        /// @dev For conditional relays this is the completion date, and for guaranteed relays this is zero (guaranteed relays can be returned at any time).
        uint allowReturnAfter;
    }

    event RelayCreated(address indexed _creator, uint indexed _agreementIndex, address _buyer, address _seller);
    event FundsDeposited(address indexed _creator, uint indexed _agreementIndex, uint amountDeposited, uint currentBalance, uint requiredBalance);
    event FundsWithdrawn(address indexed _creator, uint indexed _agreementIndex, uint amountWithdrawn, uint currentBalance, uint requiredBalance);
    event FundsStashed(address indexed _creator, uint indexed _agreementIndex, uint amountWithdrawn, uint relayCurrentBalance, uint accountCurrentBalance);
    event RelayLocked(address indexed _creator, uint indexed _agreementIndex);
    event RelayApproved(address indexed _creator, uint indexed _agreementIndex);
    event RelayReturned(address indexed _creator, uint indexed _agreementIndex);

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

    /// @notice Withdraws funds from the relay agreement.
    /// @dev Must pass the _validateWithdrawal function to ensure the withdrawal is valid (see _validateWithdrawal docs in contract).
    /// @dev Calculates the amount to withdraw based on the fee basis point value
    /// @dev The fee portion of the balance is transferred to the contract owner's account balance.
    /// @dev Transfers funds to the sender
    /// ---
    /// @param _creator The address of the account which created the agreement.
    /// @param _index The index of the relay agreement in the creator's relays.
    /// @param _amount The amount of funds to withdraw from the relay.
    /// ---
    /// @custom:event Emits a FundsWithdrawn event.
    function withdrawFunds(address _creator, uint _index, uint _amount) external;

    /// @notice Locks the relay agreement, preventing any withdrawals until it is either approved or returned.
    /// ---
    /// @custom:revert If the relay is already locked.
    /// @custom:revert If the caller is not the payer of the relay agreement.
    /// @custom:revert If the relay's current balance is not equal to the required balance.
    /// ---
    /// @custom:event Emits a RelayLocked event.
    function lockRelay(address _creator, uint _index) external;

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
}
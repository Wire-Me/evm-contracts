import "./EscrowStructs.sol";
import {IRelay} from "./IRelay.sol";
import {IUndisputableRelay} from "./IUndisputableRelay.sol";
import {RelayBase} from "./RelayBase.sol";

abstract contract UndisputableRelayBase is RelayBase, IUndisputableRelay {
    constructor(string memory _symbol, uint _basisPointFee) RelayBase(_symbol, _basisPointFee) {}

    function createRelay(uint _requiredBalance, address _payer, address _payee, uint _automaticallyUnlockAt, uint _allowReturnAfter) public virtual override {
        require(msg.sender == _payer || msg.sender == _payee, "TransactionRelay: only the payer or payee can create a relay");
        require(_payer != _payee, "TransactionRelay: payer and payee must be different addresses");
        require(_requiredBalance > 0, "TransactionRelay: required balance must be greater than 0");
        require(_payer != address(0), "TransactionRelay: payer address must not be 0x0");
        require(_payee != address(0), "TransactionRelay: payee address must not be 0x0");
        require(_automaticallyUnlockAt > block.timestamp, "TransactionRelay: automatically approved at timestamp must be in the future");
        require(_automaticallyUnlockAt > _allowReturnAfter, "TransactionRelay: automatically approved at timestamp must be after allow return after timestamp");

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
                automaticallyApprovedAt: _automaticallyUnlockAt,
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

        uint amount = relay.currentBalance;
        _validateWithdrawal(_creator, _index, amount);

        uint amountOfFundsStashed = _calculateAmountWithdrawn(_creator, _index, amount);

        accountBalances[msg.sender] += amountOfFundsStashed;
        // Adds fee to the owner's account balance
        accountBalances[owner] += (amount - amountOfFundsStashed);
        relay.currentBalance = 0;

        emit FundsStashed(_creator, _index, amount, relay.currentBalance, accountBalances[msg.sender]);
    }

    function withdrawFunds(address _creator, uint _index) external virtual override {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        uint amount = relay.currentBalance;

        _validateWithdrawal(_creator, _index, amount);

        uint amountOfFundsWithdrawn = _calculateAmountWithdrawn(_creator, _index, amount);

        relay.currentBalance -= amount;
        // Adds fee to the owner's account balance
        accountBalances[owner] += (amount - amountOfFundsWithdrawn);
        payable(msg.sender).transfer(amountOfFundsWithdrawn);

        emit FundsWithdrawn(_creator, _index, amount, relay.currentBalance, relay.requiredBalance);
    }

    /// @notice Validates the withdrawal of funds from the relay.
    /// @custom:revert If the relay is not locked only the payer can withdraw funds. Reverts otherwise
    /// @custom:revert If the relay is locked & returning only the payer can withdraw funds & _amount must equal the current balance. Reverts otherwise.
    /// @custom:revert If the relay is locked & approved only the payee can withdraw funds & _amount must equal the current balance. Reverts otherwise.
    /// @custom:revert If the relay is locked & not approved only the payee can withdraw funds & it must be passed the automatic approval timestamp. Reverts otherwise.
    function _validateWithdrawal(address _creator, uint _index, uint _amount) internal view {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        require(relay.currentBalance == _amount, "TransactionRelay: can not withdraw partial funds, must be full amount");

        if (relay.isLocked) {
            if (relay.isReturning) {
                require(relay.payer == msg.sender, "TransactionRelay: only the payer can withdraw funds (if marked as returning)");
            } else if (relay.isApproved) {
                require(relay.payee == msg.sender, "TransactionRelay: only the payee can withdraw funds (if locked and approved)");
            } else {
                require(_isPassedAutomaticUnlockTime(_creator, _index), "TransactionRelay: can not withdraw funds if not approved and not passed automatic approval time");
                require(relay.payee == msg.sender, "TransactionRelay: only the payee can withdraw funds (if locked and not approved)");
            }
        } else {
            revert("TransactionRelay: can not withdraw funds if relay isn't locked");
        }
    }

    function _calculateAmountWithdrawn(address _creator, uint _index, uint _amount) private view returns (uint) {
        EscrowStructs.Relay storage relay = relays[_creator][_index];
        uint amountOfFundsWithdrawn = _amount;

        // If the relay is not locked, the full amount can be withdrawn
        if (relay.isLocked && (relay.isReturning || relay.isApproved)) {
            uint fee = _calculateBasisPointProportion(_amount, basisPointFee);
            amountOfFundsWithdrawn = _amount - fee;
        }

        return amountOfFundsWithdrawn;
    }
}
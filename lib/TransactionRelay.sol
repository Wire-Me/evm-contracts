// SPDX-License-Identifier: GNU
pragma solidity ^0.8.23;

contract TransactionRelay {
    address public owner; // The account which deployed this contract
    string public coinSymbol = "ETH"; // The symbol of the coin used in this contract
    uint16 public basisPointFee = 100; // The fee for using this contract (1%)

    struct Relay {
        // the address of the buyer's account
        address payer;
        // the address of the seller's account
        address payee;
        // the address of the account which initially created the agreement (must be either the buyer or the seller in
        // this agreement)
        address creator;
        // 'true' if initialized
        bool initialized;
        // Balance info
        uint requiredBalance;
        uint currentBalance;
        // State info
        bool isLocked;
        bool isReturning;
        bool isApproved;
        // Time info
        uint automaticallyApprovedAt;
        uint allowReturnAfter;
    }

    event RelayCreated(address indexed _creator, uint indexed _agreementIndex, address _buyer, address _seller);
    event FundsDeposited(address indexed _creator, uint indexed _agreementIndex, uint amountDeposited, uint currentBalance, uint requiredBalance);
    event FundsWithdrawn(address indexed _creator, uint indexed _agreementIndex, uint amountWithdrawn, uint currentBalance, uint requiredBalance);
    event FundsStashed(address indexed _creator, uint indexed _agreementIndex, uint amountWithdrawn, uint relayCurrentBalance, uint accountCurrentBalance);
    event RelayLocked(address indexed _creator, uint indexed _agreementIndex);
    event RelayApproved(address indexed _creator, uint indexed _agreementIndex);
    event RelayReturned(address indexed _creator, uint indexed _agreementIndex);

    mapping(address => Relay[]) public relays;
    mapping(address => uint) public accountBalances;

    constructor() {
        owner = msg.sender;
    }

    function createRelay(uint _requiredBalance, address _payer, address _payee, uint _automaticallyApprovedAt, uint _allowReturnAfter) public {
        require(msg.sender == _payer || msg.sender == _payee, "TransactionRelay: only the payer or payee can create a relay");
        require(_payer != _payee, "TransactionRelay: payer and payee must be different addresses");
        require(_requiredBalance > 0, "TransactionRelay: required balance must be greater than 0");
        require(_payer != address(0), "TransactionRelay: payer address must not be 0x0");
        require(_payee != address(0), "TransactionRelay: payee address must not be 0x0");

        relays[msg.sender].push(
            Relay({
                payer: _payer,
                payee: _payee,
                creator: msg.sender,
                initialized: true,
                requiredBalance: _requiredBalance,
                currentBalance: 0,
                isLocked: false,
                isReturning: false,
                isApproved: false,
                automaticallyApprovedAt: _automaticallyApprovedAt,
                allowReturnAfter: _allowReturnAfter
            })
        );

        emit RelayCreated(msg.sender, relays[msg.sender].length - 1, _payer, _payee);
    }

    // Returns information about the agreement
    function getRelayActors(address _creator, uint _index) public view returns (address, address, address, bool) {
        Relay storage relay = relays[_creator][_index];
        return (relay.payer, relay.payee, relay.creator, relay.initialized);
    }

    function getRelayBalances(address _creator, uint _index) public view returns (uint, uint, bool) {
        Relay storage relay = relays[_creator][_index];
        return (relay.requiredBalance, relay.currentBalance, relay.initialized);
    }

    function getRelayState(address _creator, uint _index) public view returns (bool, bool, bool, uint, uint, bool) {
        Relay storage relay = relays[_creator][_index];
        return (relay.isLocked, relay.isReturning, relay.isApproved, relay.automaticallyApprovedAt, relay.allowReturnAfter, relay.initialized);
    }

    function depositFunds(address _creator, uint _index) public payable {
        require(msg.value > 0, "TransactionRelay: deposit amount must be greater than 0");
        require(relays[_creator][_index].payer == msg.sender, "TransactionRelay: Only the payer can deposit funds");
        relays[_creator][_index].currentBalance += msg.value;

        emit FundsDeposited(_creator, _index, msg.value, relays[_creator][_index].currentBalance, relays[_creator][_index].requiredBalance);
    }

    function stashFunds(address _creator, uint _index) public {
        Relay storage relay = relays[_creator][_index];

        uint amount = relay.currentBalance;
        _validateWithdrawal(_creator, _index, amount);

        uint amountOfFundsStashed = _calculateAmountWithdrawn(_creator, _index, amount);

        accountBalances[msg.sender] += amountOfFundsStashed;
        accountBalances[owner] += (amount - amountOfFundsStashed);
        relay.currentBalance = 0;

        emit FundsStashed(_creator, _index, amount, relay.currentBalance, accountBalances[msg.sender]);
    }

    function withdrawFunds(address _creator, uint _index, uint _amount) public {
        Relay storage relay = relays[_creator][_index];

        _validateWithdrawal(_creator, _index, _amount);

        uint amountOfFundsWithdrawn = _calculateAmountWithdrawn(_creator, _index, _amount);

        relay.currentBalance -= _amount;
        accountBalances[owner] += (_amount - amountOfFundsWithdrawn);
        payable(msg.sender).transfer(amountOfFundsWithdrawn);

        emit FundsWithdrawn(_creator, _index, _amount, relay.currentBalance, relay.requiredBalance);
    }

    function lockRelay(address _creator, uint _index) public {
        Relay storage relay = relays[_creator][_index];

        require(relay.isLocked == false, "TransactionRelay: relay is already locked");
        require(relay.payer == msg.sender, "TransactionRelay: only the payer can lock the relay");
        require(relay.currentBalance == relays[_creator][_index].requiredBalance, "TransactionRelay: current balance must equal required balance to lock");

        relay.isLocked = true;

        emit RelayLocked(_creator, _index);
    }

    function approveRelay(address _creator, uint _index) public {
        Relay storage relay = relays[_creator][_index];

        require(relay.payer == msg.sender, "TransactionRelay: only the payer can approve the relay");
        require(relay.isLocked == true, "TransactionRelay: can only approve if locked");
        require(relay.isReturning == false, "TransactionRelay: can not approve if already marked as returning");
        require(relay.isApproved == false, "TransactionRelay: can not approve if already approved");

        relay.isApproved = true;

        emit RelayApproved(_creator, _index);
    }

    function returnRelay(address _creator, uint _index) public {
        Relay storage relay = relays[_creator][_index];
        require(relay.isLocked == true, "TransactionRelay: can only return funds if locked");
        require(relay.isApproved == false, "TransactionRelay: can not return funds if already approved");
        require(relay.isReturning == false, "TransactionRelay: can not return funds if already returning");
        require(relay.allowReturnAfter < block.timestamp, "TransactionRelay: can not return funds before allowReturnAfter");

        if (_isGuaranteed(_creator, _index)) {
            require(relay.payee == msg.sender, "TransactionRelay: only the payee can return funds (if guaranteed)");
        } else if (_isConditional(_creator, _index)) {
            require(relay.payer == msg.sender, "TransactionRelay: only the payer can return funds (if conditional)");
        } else {
            revert("TransactionRelay: can not return funds if not guaranteed or conditional");
        }

        relays[_creator][_index].isReturning = true;

        emit RelayReturned(_creator, _index);
    }

    /* Private functions */

    function _isGuaranteed(address _creator, uint _index) private view returns (bool) {
        return relays[_creator][_index].allowReturnAfter == 0;
    }

    function _isConditional(address _creator, uint _index) private view returns (bool) {
        return relays[_creator][_index].allowReturnAfter > 0;
    }

    function _isPassedCompletionTime(address _creator, uint _index) private view returns (bool) {
        return relays[_creator][_index].automaticallyApprovedAt < block.timestamp;
    }

    function _isGuaranteedAndPassedCompletionTime(address _creator, uint _index) private view returns (bool) {
        return _isGuaranteed(_creator, _index) && _isPassedCompletionTime(_creator, _index);
    }

    function _validateWithdrawal(address _creator, uint _index, uint _amount) private view {
        Relay storage relay = relays[_creator][_index];
        require(relay.currentBalance >= _amount, "TransactionRelay: insufficient balance");

        if (!relay.isLocked) {
            require(relay.payer == msg.sender, "TransactionRelay: only the payer can withdraw funds (if relay isn't locked)");
        } else if (relay.isLocked && relay.isReturning) {
            require(relay.payer == msg.sender, "TransactionRelay: only the payer can withdraw funds (if marked as returning)");
            require(_amount == relay.currentBalance, "TransactionRelay: can not withdraw partial funds if marked as returning");
        } else if (relay.isLocked && relay.isApproved) {
            require(relay.payee == msg.sender, "TransactionRelay: only the payee can withdraw funds (if locked and approved)");
            require(_amount == relay.currentBalance, "TransactionRelay: can not withdraw partial funds if marked as approved");
        } else if (relay.isLocked && _isGuaranteed(_creator, _index) && !relay.isApproved) {
            require(relay.payee == msg.sender, "TransactionRelay: only the payee can withdraw funds (if locked, guaranteed, and not approved)");
            require(_isPassedCompletionTime(_creator, _index), "TransactionRelay: can not withdraw funds if not approved and not passed completion time");
        } else {
            revert("TransactionRelay: can not withdraw funds if relay is locked and not approved or returning");
        }
    }

    function _calculateFee(uint _amount) private view returns (uint) {
        return (_amount * basisPointFee) / 10000;
    }

    function _calculateAmountWithdrawn(address _creator, uint _index, uint _amount) private view returns (uint) {
        Relay storage relay = relays[_creator][_index];
        uint amountOfFundsWithdrawn = _amount;

        if (relay.isLocked && (relay.isReturning || relay.isApproved)) {
            uint fee = _calculateFee(_amount);
            amountOfFundsWithdrawn = _amount - fee;
        }

        return amountOfFundsWithdrawn;
    }
}
// SPDX-License-Identifier: GNU-3.0
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../../EscrowStructs.sol";
import {FxEscrowMultiStorage} from "./FxEscrowMultiStorage.sol";
import {EscrowConfig} from "./configuration/EscrowConfig.sol";

abstract contract AbstractFxEscrowMulti is FxEscrowMultiStorage {
    bytes32 internal constant NATIVE_TOKEN = keccak256("NATIVE");

    // Admin modifier
    modifier onlyAdmin() {
        require(msg.sender == _admin, "Sender is not an authorized admin account");
        _;
    }

    // Authorized users
    modifier onlyAuthorizedUsers() {
        require(_authorizedUserWallets[msg.sender], "Sender is not an authorized user wallet");
        _;
    }

    function isAuthorizedUser(address user) external view returns (bool) {
        return _authorizedUserWallets[user];
    }

    function addAuthorizedUser(address user) external onlyAdmin {
        require(user != address(0), "User address cannot be zero");
        _authorizedUserWallets[user] = true;
    }

    function removeAuthorizedUser(address user) external onlyAdmin {
        require(user != address(0), "User address cannot be zero");
        _authorizedUserWallets[user] = false;
    }

    // Authorized brokers
    modifier onlyAuthorizedBrokers() {
        require(_authorizedBrokerWallets[msg.sender], "Sender is not an authorized broker wallet");
        _;
    }

    function isAuthorizedBroker(address broker) external view returns (bool) {
        return _authorizedBrokerWallets[broker];
    }

    function addAuthorizedBroker(address broker) external onlyAdmin {
        require(broker != address(0), "Broker address cannot be zero");
        _authorizedBrokerWallets[broker] = true;
    }

    function removeAuthorizedBroker(address broker) external onlyAdmin {
        require(broker != address(0), "Broker address cannot be zero");
        _authorizedBrokerWallets[broker] = false;
    }

    function transferFundsFromContract(bytes32 _token, address _to, uint _amount) internal {
        if (_token == NATIVE_TOKEN) {
            require(address(this).balance >= _amount, "Insufficient balance in contract");

            (bool success,) = payable(_to).call{value: _amount}("");
            require(success, "Transfer failed");

            emit TransferSuccessful(address(this), _to, _amount);
        } else {
            IERC20 erc20TokenContract = IERC20(config.erc20TokenContracts(_token));
            erc20TokenContract.transfer(_to, _amount);
        }
    }

    event TransferSuccessful(address indexed from, address indexed to, uint amount);

    event EscrowCreated(
        address indexed _creatingUser,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        uint _expirationTimestamp,
        uint _amount
    );

    event OfferCreated(
        address indexed _creatingBroker,
        uint indexed _offerIndex,
        bytes32 indexed _currency,
        address _escrowUser,
        uint _escrowIndex
    );

    event EscrowSelectedOffer(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _creatorOfOffer,
        uint _offerIndex
    );

    event EscrowFrozen(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowDefrosted(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowFundsReturnedToUser(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency
    );

    event EscrowExpirationExtended(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        uint _newExpirationTimestamp
    );

    event EscrowWithdrawnAfterCompletion(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );

    event EscrowWithdrawnEarly(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );

    event EscrowWithdrawnAfterReturn(
        address indexed _creatorOfEscrow,
        uint indexed _escrowIndex,
        bytes32 indexed _currency,
        address _withdrawnTo,
        uint _amountWithdrawn
    );

    function getEscrow(bytes32 _token, address _escrowAccount, uint _escrowIndex) external view returns (EscrowStructs.FXEscrow memory) {
        return _escrows[_token][_escrowAccount][_escrowIndex];
    }

    function getOffer(bytes32 _token, address _offerAccount, uint _offerIndex) external view returns (EscrowStructs.FXEscrowOffer memory) {
        return _offers[_token][_offerAccount][_offerIndex];
    }

    function getErc20ContractAddress(bytes32 _token) external view returns (address) {
        return config.erc20TokenContracts(_token);
    }

    function getPlatformFeeBalance(bytes32 _token) external view returns (uint) {
        return _platformFeeBalances[_token];
    }

    function createEscrow(bytes32 _token, uint _amount) external onlyAuthorizedUsers {
        uint expiration = block.timestamp + defaultEscrowDuration;

        _escrows[_token][msg.sender].push(
            EscrowStructs.FXEscrow({
                amount: _amount,
                token: _token,
                createdAt: block.timestamp,
                expirationTimestamp: expiration,
                isWithdrawn: false,
                isFrozen: false,
                isReturned: false,
                selectedBrokerAccount: address(0),
                selectedOfferIndex: 0
            })
        );

        emit EscrowCreated(msg.sender, _escrows[_token][msg.sender].length - 1, _token, expiration, _amount);
    }

    function createOffer(
        bytes32 _token,
        address _escrowAccount,
        uint _escrowIndex,
        uint _feeBasisPoints
    ) external onlyAuthorizedBrokers {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][_escrowAccount][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.selectedBrokerAccount == address(0), "Escrow already has selected an offer");

        _offers[_token][msg.sender].push(
            EscrowStructs.FXEscrowOffer({
                escrowAccount: _escrowAccount,
                escrowIndex: _escrowIndex,
                feeBasisPoints: _feeBasisPoints,
                createdAt: block.timestamp
            })
        );

        emit OfferCreated(msg.sender, _offers[_token][msg.sender].length - 1, _token, _escrowAccount, _escrowIndex);
    }

    function linkOfferToEscrow(
        bytes32 _token,
        uint _escrowIndex,
        address _offerAccount,
        uint _offerIndex
    ) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][msg.sender][_escrowIndex];
        EscrowStructs.FXEscrowOffer storage offer = _offers[_token][_offerAccount][_offerIndex];

        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(offer.createdAt > 0, "Offer is not initialized");

        // Defrost the escrow if it is frozen
        if (escrow.isFrozen) {
            escrow.isFrozen = false;
            emit EscrowDefrosted(msg.sender, _escrowIndex, _token);
        }

        // Extend the escrow expiration if it is past half of its duration
        if (block.timestamp > (escrow.expirationTimestamp - (defaultEscrowDuration / 2))) {
            uint newExpirationTimestamp = block.timestamp + defaultEscrowDuration;
            escrow.expirationTimestamp = newExpirationTimestamp;
            emit EscrowExpirationExtended(msg.sender, _escrowIndex, _token, newExpirationTimestamp);
        }

        escrow.selectedBrokerAccount = _offerAccount;
        escrow.selectedOfferIndex = _offerIndex;

        emit EscrowSelectedOffer(msg.sender, _escrowIndex, _token, _offerAccount, _offerIndex);
    }

    function freezeEscrow(bytes32 _token, address _escrowAccount, uint _escrowIndex) external onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][_escrowAccount][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isFrozen, "Escrow is already frozen");

        escrow.isFrozen = true;

        emit EscrowFrozen(_escrowAccount, _escrowIndex, _token);
    }

    function defrostEscrow(bytes32 _token, address _escrowAccount, uint _escrowIndex) public onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][_escrowAccount][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.isFrozen, "Escrow is not frozen");

        escrow.isFrozen = false;

        emit EscrowDefrosted(_escrowAccount, _escrowIndex, _token);
    }

    function returnEscrow(bytes32 _token, address _escrowAccount, uint _escrowIndex) external onlyAdmin {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][_escrowAccount][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");

        escrow.isReturned = true;
        escrow.isFrozen = false; // Unfreeze the escrow if it was frozen (most of the time it will be so no `if` check to save gas)

        emit EscrowFundsReturnedToUser(_escrowAccount, _escrowIndex, _token);
    }

    function extendEscrow(bytes32 _token, uint _escrowIndex) public onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][msg.sender][_escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(escrow.selectedBrokerAccount == address(0), "Escrow has already selected an offer");

        // Extend the escrow expiration by the default duration
        uint newExpirationTimestamp = block.timestamp + defaultEscrowDuration;
        escrow.expirationTimestamp = newExpirationTimestamp;

        emit EscrowExpirationExtended(msg.sender, _escrowIndex, _token, newExpirationTimestamp);
    }

    function withdrawEscrowAfterCompletion(bytes32 _token, address escrowAccount, uint escrowIndex) external onlyAuthorizedBrokers {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][escrowAccount][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(!escrow.isFrozen, "Escrow is frozen and cannot be withdrawn by the broker");
        require(!escrow.isReturned, "Escrow is returned and cannot be withdrawn by the broker");
        require(escrow.selectedBrokerAccount == msg.sender, "Only the selected broker can withdraw from the escrow");
        require(block.timestamp >= escrow.expirationTimestamp, "Escrow has not yet expired");

        EscrowStructs.FXEscrowOffer storage selectedOffer = _offers[_token][escrow.selectedBrokerAccount][escrow.selectedOfferIndex];

        uint platformFee = _calcBasisPointShare(escrow.amount, selectedOffer.feeBasisPoints);
        uint amountWithdrawn = escrow.amount - platformFee;

        escrow.isWithdrawn = true;

        // Transfer the escrow amount to the broker
        transferFundsFromContract(_token, msg.sender, amountWithdrawn);
        // Add the platform fee to the contract's balance
        _platformFeeBalances[_token] += platformFee;

        emit EscrowWithdrawnAfterCompletion(escrowAccount, escrowIndex, _token, msg.sender, amountWithdrawn);
    }

    function withdrawEscrowEarly(bytes32 _token, uint escrowIndex) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][msg.sender][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(escrow.selectedBrokerAccount == address(0), "Escrow has already selected an offer");

        escrow.isWithdrawn = true;

        // Transfer the escrow amount back to the user
        transferFundsFromContract(_token, msg.sender, escrow.amount);

        emit EscrowWithdrawnEarly(msg.sender, escrowIndex, _token, msg.sender, escrow.amount);
    }

    function withdrawEscrowAfterReturn(bytes32 _token, uint escrowIndex) external onlyAuthorizedUsers {
        EscrowStructs.FXEscrow storage escrow = _escrows[_token][msg.sender][escrowIndex];
        require(escrow.createdAt > 0, "Escrow is not initialized");
        require(!escrow.isWithdrawn, "Escrow is already withdrawn");
        require(escrow.isReturned, "Escrow has not been returned");
        require(!escrow.isFrozen, "Escrow is frozen and cannot be withdrawn");

        escrow.isWithdrawn = true;

        // Transfer the escrow amount back to the user
        transferFundsFromContract(_token, msg.sender, escrow.amount);

        emit EscrowWithdrawnAfterReturn(msg.sender, escrowIndex, _token, msg.sender, escrow.amount);
    }

    function withdrawFees(bytes32 _token, address payable _to) external onlyAdmin {
        require(_to != address(0), "Cannot withdraw to zero address");
        uint amount = _platformFeeBalances[_token];
        transferFundsFromContract(_token, _to, amount);
        _platformFeeBalances[_token] = 0;
    }

    function setConfigAddress(address _newConfigAddress) external onlyAdmin {
        require(_newConfigAddress != address(0), "New config address cannot be zero");
        config = EscrowConfig(_newConfigAddress);
    }

    function _calcBasisPointShare(uint _amount, uint basisPoints) internal pure returns (uint) {
        return (_amount * basisPoints) / 10000;
    }
}
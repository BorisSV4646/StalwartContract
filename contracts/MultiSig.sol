// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiSigStalwart {
    struct Transaction {
        bytes data;
        bool executed;
        uint signatureCount;
        mapping(address => bool) signatures;
    }

    address[] public owners;
    uint public requiredSignatures;
    uint public transactionCount;
    mapping(uint => Transaction) public transactions;

    event TransactionCreated(uint indexed transactionId, bytes data);
    event TransactionSigned(uint indexed transactionId, address by);
    event TransactionExecuted(uint indexed transactionId);

    error NotAnOwner(address sender);
    error NotTransaction(uint idTransaction);
    error AlreadyExecuted(uint idTransaction);
    error AlreadySigned(uint idTransactio);
    error NotEnoughSignatures(uint idTransactio);
    error onlyMultiSigError(address sender);

    modifier onlyOwner() {
        if (!isOwner(msg.sender)) {
            revert NotAnOwner(msg.sender);
        }
        _;
    }

    constructor(address[] memory _owners, uint _requiredSignatures) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredSignatures > 0 && _requiredSignatures <= _owners.length,
            "Invalid number of required signatures"
        );

        owners = _owners;
        requiredSignatures = _requiredSignatures;
    }

    function createTransaction(
        bytes memory _data
    ) public returns (uint transactionId) {
        transactionId = transactionCount;
        Transaction storage newTransaction = transactions[transactionId];
        newTransaction.data = _data;
        newTransaction.executed = false;
        newTransaction.signatureCount = 0;
        transactionCount += 1;

        emit TransactionCreated(transactionId, _data);
    }

    function signTransaction(uint _transactionId) public {
        if (!isOwner(msg.sender)) {
            revert NotAnOwner(msg.sender);
        }
        if (_transactionId > transactionCount) {
            revert NotTransaction(_transactionId);
        }

        Transaction storage transaction = transactions[_transactionId];

        if (transaction.executed) {
            revert AlreadyExecuted(_transactionId);
        }
        if (transaction.signatures[msg.sender]) {
            revert AlreadySigned(_transactionId);
        }

        transaction.signatures[msg.sender] = true;
        transaction.signatureCount += 1;

        emit TransactionSigned(_transactionId, msg.sender);

        if (transaction.signatureCount >= requiredSignatures) {
            executeTransaction(_transactionId);
        }
    }

    function executeTransaction(uint _transactionId) internal {
        Transaction storage transaction = transactions[_transactionId];

        if (transaction.executed) {
            revert AlreadyExecuted(_transactionId);
        }
        if (transaction.signatureCount <= requiredSignatures) {
            revert NotEnoughSignatures(_transactionId);
        }

        transaction.executed = true;

        (bool success, ) = address(this).call(transaction.data);
        require(success, "Transaction execution failed");

        emit TransactionExecuted(_transactionId);
    }

    function isOwner(address _address) internal view returns (bool) {
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                return true;
            }
        }
        return false;
    }
}

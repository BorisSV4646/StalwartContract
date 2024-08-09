// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

contract MultiSigStalwart {
    struct Transaction {
        bytes data;
        bool executed;
        uint256 signatureCount;
        mapping(address => bool) signatures;
    }

    address[] public owners;
    uint256 public requiredSignatures;
    uint256 public transactionCount;
    mapping(uint256 => Transaction) public transactions;

    event TransactionCreated(uint256 indexed transactionId, bytes data);
    event TransactionSigned(uint256 indexed transactionId, address by);
    event TransactionExecuted(uint256 indexed transactionId);

    error NotAnOwner(address sender);
    error NotTransaction(uint256 idTransaction);
    error AlreadyExecuted(uint256 idTransaction);
    error AlreadySigned(uint256 idTransactio);
    error NotEnoughSignatures(uint256 idTransactio);
    error onlyMultiSigError(address sender);

    modifier onlyOwner() {
        if (!isOwner(msg.sender)) {
            revert NotAnOwner(msg.sender);
        }
        _;
    }

    function createTransaction(
        bytes memory _data
    ) public returns (uint256 transactionId) {
        transactionId = transactionCount;
        Transaction storage newTransaction = transactions[transactionId];
        newTransaction.data = _data;
        newTransaction.executed = false;
        newTransaction.signatureCount = 0;
        transactionCount += 1;

        emit TransactionCreated(transactionId, _data);
    }

    function signTransaction(uint256 _transactionId) public {
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

    function executeTransaction(uint256 _transactionId) internal {
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
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                return true;
            }
        }
        return false;
    }
}

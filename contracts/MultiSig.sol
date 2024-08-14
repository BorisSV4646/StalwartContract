// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Errors} from "./libraries/Errors.sol";
import {Events} from "./libraries/Events.sol";

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

    /**
     * @dev Initializes the contract with the list of owners and the number of required signatures.
     * @param _owners An array of addresses that are the owners of the contract.
     * @param _requiredSignatures The number of signatures required to execute a transaction.
     * Requirements:
     * - `_owners` must not be empty.
     * - `_requiredSignatures` must be at least 2 and less than or equal to the number of owners.
     */
    constructor(address[] memory _owners, uint _requiredSignatures) {
        if (_owners.length == 0) {
            revert Errors.OwnersRequire(_owners.length);
        }
        if (_requiredSignatures < 2 || _requiredSignatures > _owners.length) {
            revert Errors.InvalidNumberSignatures(
                _requiredSignatures,
                _owners.length
            );
        }

        owners = _owners;
        requiredSignatures = _requiredSignatures;
    }

    /**
     * @dev Modifier to check if the caller is an owner.
     * Reverts with `Errors.NotAnOwner` if the caller is not an owner.
     */
    modifier onlyOwner() {
        if (!isOwner(msg.sender)) {
            revert Errors.NotAnOwner(msg.sender);
        }
        _;
    }

    /**
     * @dev Creates a new transaction.
     * @param _data The data to be executed by the transaction.
     * @return transactionId The ID of the newly created transaction.
     * Emits a {TransactionCreated} event.
     */
    function createTransaction(
        bytes memory _data
    ) public returns (uint256 transactionId) {
        transactionId = transactionCount;
        Transaction storage newTransaction = transactions[transactionId];
        newTransaction.data = _data;
        newTransaction.executed = false;
        newTransaction.signatureCount = 0;
        transactionCount += 1;

        emit Events.TransactionCreated(transactionId, _data);
    }

    /**
     * @dev Signs a transaction. If the transaction receives enough signatures, it is executed.
     * @param _transactionId The ID of the transaction to be signed.
     * Requirements:
     * - The caller must be an owner.
     * - The transaction must not be already executed.
     * - The transaction must not have been already signed by the caller.
     * Emits a {TransactionSigned} event and, if executed, a {TransactionExecuted} event.
     */
    function signTransaction(uint256 _transactionId) public {
        if (!isOwner(msg.sender)) {
            revert Errors.NotAnOwner(msg.sender);
        }
        if (_transactionId >= transactionCount) {
            revert Errors.NotTransaction(_transactionId);
        }

        Transaction storage transaction = transactions[_transactionId];

        if (transaction.executed) {
            revert Errors.AlreadyExecuted(_transactionId);
        }
        if (transaction.signatures[msg.sender]) {
            revert Errors.AlreadySigned(_transactionId);
        }

        transaction.signatures[msg.sender] = true;
        transaction.signatureCount += 1;

        emit Events.TransactionSigned(_transactionId, msg.sender);

        if (transaction.signatureCount >= requiredSignatures) {
            executeTransaction(_transactionId);
        }
    }

    /**
     * @dev Executes a transaction that has received enough signatures.
     * @param _transactionId The ID of the transaction to be executed.
     * Requirements:
     * - The transaction must have enough signatures.
     * - The transaction must not be already executed.
     * Emits a {TransactionExecuted} event.
     */
    function executeTransaction(uint256 _transactionId) internal {
        Transaction storage transaction = transactions[_transactionId];

        if (transaction.executed) {
            revert Errors.AlreadyExecuted(_transactionId);
        }
        if (transaction.signatureCount < requiredSignatures) {
            revert Errors.NotEnoughSignatures(_transactionId);
        }

        transaction.executed = true;

        (bool success, ) = address(this).call(transaction.data);
        require(success, "Transaction execution failed");

        emit Events.TransactionExecuted(_transactionId);
    }

    /**
     * @dev Creates a transaction to add or remove an owner.
     * @param owner The address of the owner to add or remove.
     * @param addNew If true, the owner will be added. If false, the owner will be removed.
     * Requirements:
     * - The caller must be an owner.
     * - The owner address must be valid (not zero address).
     * Emits a {TransactionCreated} event.
     */
    function addAddressOwner(address owner, bool addNew) external onlyOwner {
        if (owner == address(0)) {
            revert Errors.InvalidAddressOwner(owner);
        }

        bytes memory data = abi.encodeWithSignature(
            "executeAddAddressOwner(address,bool)",
            owner,
            addNew
        );
        createTransaction(data);
    }

    /**
     * @dev Creates a transaction to change the number of required signatures.
     * @param newRequiredSignatures The new number of required signatures.
     * Requirements:
     * - The caller must be an owner.
     * - The new number of required signatures must be at least 2 and less than or equal to the number of owners.
     * Emits a {TransactionCreated} event.
     */
    function changeRequiredSignatures(
        uint256 newRequiredSignatures
    ) external onlyOwner {
        if (
            newRequiredSignatures < 2 || newRequiredSignatures > owners.length
        ) {
            revert Errors.InvalidNumberSignatures(
                newRequiredSignatures,
                owners.length
            );
        }

        bytes memory data = abi.encodeWithSignature(
            "executeChangeRequiredSignatures(uint256)",
            newRequiredSignatures
        );
        createTransaction(data);
    }

    /**
     * @dev Executes the addition or removal of an owner.
     * @param owner The address of the owner to add or remove.
     * @param addNew If true, the owner will be added. If false, the owner will be removed.
     * Requirements:
     * - This function should only be called internally by the contract.
     */
    function executeAddAddressOwner(address owner, bool addNew) internal {
        if (addNew) {
            owners.push(owner);
        } else {
            uint indexToRemove = owners.length;

            for (uint i = 0; i < owners.length; i++) {
                if (owners[i] == owner) {
                    indexToRemove = i;
                    break;
                }
            }

            if (indexToRemove == owners.length) {
                revert Errors.AddressNotFound(owner);
            }

            for (uint i = indexToRemove; i < owners.length - 1; i++) {
                owners[i] = owners[i + 1];
            }

            owners.pop();
        }
    }

    /**
     * @dev Executes the change of the number of required signatures.
     * @param newRequiredSignatures The new number of required signatures.
     * Requirements:
     * - This function should only be called internally by the contract.
     */
    function executeChangeRequiredSignatures(
        uint256 newRequiredSignatures
    ) internal {
        requiredSignatures = newRequiredSignatures;
    }

    /**
     * @dev Checks if an address is an owner.
     * @param _address The address to check.
     * @return True if the address is an owner, false otherwise.
     */
    function isOwner(address _address) internal view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                return true;
            }
        }
        return false;
    }
}

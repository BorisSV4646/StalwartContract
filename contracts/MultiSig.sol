// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiSigStalwart {
    struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
        uint signatureCount;
        mapping(address => bool) signatures;
    }

    address[] public owners;
    uint public requiredSignatures;
    uint public transactionCount;
    mapping(uint => Transaction) public transactions;

    event TransactionCreated(
        uint indexed transactionId,
        address to,
        uint value,
        bytes data
    );
    event TransactionSigned(uint indexed transactionId, address by);
    event TransactionExecuted(uint indexed transactionId);

    // constructor initializes the contract with the owners and required signatures
    constructor(address[] memory _owners, uint _requiredSignatures) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredSignatures > 0 && _requiredSignatures <= _owners.length,
            "Invalid number of required signatures"
        );

        owners = _owners;
        requiredSignatures = _requiredSignatures;
    }

    // createTransaction creates a transaction
    function createTransaction(
        address _to,
        uint _value,
        bytes memory _data
    ) public returns (uint transactionId) {
        require(isOwner(msg.sender), "Not an owner");
        transactionId = transactionCount;
        Transaction storage newTransaction = transactions[transactionId];
        newTransaction.to = _to;
        newTransaction.value = _value;
        newTransaction.data = _data;
        newTransaction.executed = false;
        newTransaction.signatureCount = 0;
        transactionCount += 1;
        emit TransactionCreated(transactionId, _to, _value, _data);
    }

    // signTransaction signs a transaction
    function signTransaction(uint _transactionId) public {
        require(isOwner(msg.sender), "Not an owner");
        require(
            _transactionId < transactionCount,
            "Transaction does not exist"
        );
        Transaction storage transaction = transactions[_transactionId];
        require(!transaction.executed, "Transaction already executed");
        require(
            !transaction.signatures[msg.sender],
            "Transaction already signed by owner"
        );

        transaction.signatures[msg.sender] = true;
        transaction.signatureCount += 1;

        emit TransactionSigned(_transactionId, msg.sender);

        if (transaction.signatureCount >= requiredSignatures) {
            executeTransaction(_transactionId);
        }
    }

    // getTokenBalance returns the balance of a token
    function getTokenBalance(
        address _token,
        address _account
    ) internal view returns (uint256) {
        return IERC20(_token).balanceOf(_account);
    }

    // isERC20 checks if the address is an ERC20 token
    // function isERC20(address _token) internal view returns (bool) {
    //     (bool success, bytes memory data) = _token.staticcall(
    //         abi.encodeWithSignature("totalSupply()")
    //     );
    //     return success && data.length > 0;
    // }

    function executeTransaction(uint _transactionId) internal {
        Transaction storage transaction = transactions[_transactionId];
        require(!transaction.executed, "Transaction already executed");
        require(
            transaction.signatureCount >= requiredSignatures,
            "Not enough signatures"
        );
        require(transaction.to != address(0), "Invalid address");

        transaction.executed = true;

        if (transaction.data.length == 0) {
            (bool success, ) = transaction.to.call{value: transaction.value}(
                ""
            );
            require(success, "Transaction execution failed");
        } else {
            if (transaction.value == 0) {
                // Token transaction
                address token = transaction.to;
                // require(isERC20(token), "Address is not a valid ERC20 token");

                // decoding function and parameters
                bytes4 sig = extractFunctionSignature(transaction.data);
                require(
                    sig == bytes4(keccak256("transfer(address,uint256)")),
                    "Invalid function signature"
                );

                (, /*address recipient*/ uint256 amount) = decodeTransferData(
                    transaction.data
                );
                require(
                    getTokenBalance(token, address(this)) >= amount,
                    "Insufficient token balance"
                );
            }

            (bool success /* bytes memory returnData*/, ) = transaction.to.call(
                transaction.data
            );
            require(success, "Transaction execution failed");
        }

        emit TransactionExecuted(_transactionId);
    }

    function extractFunctionSignature(
        bytes memory data
    ) internal pure returns (bytes4) {
        require(data.length >= 4, "Invalid data length");
        return
            bytes4(data[0]) |
            (bytes4(data[1]) >> 8) |
            (bytes4(data[2]) >> 16) |
            (bytes4(data[3]) >> 24);
    }

    function decodeTransferData(
        bytes memory data
    ) internal pure returns (address recipient, uint256 amount) {
        require(data.length >= 68, "Invalid data length for transfer");
        assembly {
            recipient := mload(add(data, 36)) // 32 (length) + 4 (function signature)
            amount := mload(add(data, 68)) // 32 (length) + 4 (function signature) + 32 (recipient)
        }
    }

    // getSignaturesLeft returns the number of signatures left for a transaction
    function getSignaturesLeft(uint _transactionId) public view returns (uint) {
        require(
            _transactionId < transactionCount,
            "Transaction does not exist"
        );
        Transaction storage transaction = transactions[_transactionId];
        if (transaction.executed) {
            return 0;
        }
        return requiredSignatures - transaction.signatureCount;
    }

    // isOwner checks if the address is an owner
    function isOwner(address _address) internal view returns (bool) {
        for (uint i = 0; i < owners.length; i++) {
            if (owners[i] == _address) {
                return true;
            }
        }
        return false;
    }
}

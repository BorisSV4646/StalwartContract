// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Errors library
 * @notice Defines the custom errors used by the Stalwart protocol
 */
library Errors {
    error InvalidStableType();
    error InvalidPoolType();
    error InvalidPoolAddress();
    error InsufficientAllowance(
        uint256 allowance,
        uint256 amount,
        address sender
    );
    error InsufficientBalance(
        uint256 balance,
        uint256 required,
        address sender
    );
    error InvalidERC20Token(address token);
    error InsufficientStableBalance(uint256 stableBalance, uint256 amount);
    error InvalidPercentage(uint256 percents);
    error InvalidPercentLiquidity(uint256 newPercentLiquidity);
    error InvalidPoolsAddress(
        address usdtPool,
        address usdcPool,
        address daiPool
    );
    error OwnersRequire(uint ownersLenght);
    error InvalidNumberSignatures(uint signatures, uint ownersLenght);
    error NotAnOwner(address sender);
    error NotTransaction(uint256 idTransaction);
    error AlreadyExecuted(uint256 idTransaction);
    error AlreadySigned(uint256 idTransactio);
    error NotEnoughSignatures(uint256 idTransactio);
    error onlyMultiSigError(address sender);
    error AddressNotFound(address owner);
    error InvalidAddressOwner(address owner);
    error NoAvalibleFee();
    error InvalidAddress();
}

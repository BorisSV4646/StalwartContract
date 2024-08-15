// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Errors library
 * @notice Defines the custom errors used by the Stalwart protocol
 */
library Errors {
    // MAIN CONTRACT

    /**
     * @dev Error thrown when the token's decimals are not supported.
     * @param decimals The number of decimals of the token that is not supported.
     */
    error UnsupportedDecimals(uint256 decimals);

    /**
     * @dev Error indicating that an invalid stable type was provided.
     */
    error InvalidStableType();

    /**
     * @dev Error indicating that an invalid pool type was provided.
     */
    error InvalidPoolType();

    /**
     * @dev Error indicating that an invalid pool address was provided.
     */
    error InvalidPoolAddress();

    /**
     * @dev Error indicating that the allowance is insufficient for the transaction.
     * @param allowance The current allowance.
     * @param amount The required amount.
     * @param sender The address of the sender.
     */
    error InsufficientAllowance(
        uint256 allowance,
        uint256 amount,
        address sender
    );

    /**
     * @dev Error indicating that the balance is insufficient for the transaction.
     * @param balance The current balance.
     * @param required The required balance.
     * @param sender The address of the sender.
     */
    error InsufficientBalance(
        uint256 balance,
        uint256 required,
        address sender
    );

    /**
     * @dev Error indicating that the provided token is not a valid ERC20 token.
     * @param token The address of the invalid token.
     */
    error InvalidERC20Token(address token);

    // LIQUIDITY

    /**
     * @dev Emitted when a function that requires execution through the multisig process is called.
     * This event logs the address of the caller who attempted to execute the function directly.
     *
     * @param caller The address that attempted to call the function requiring multisig.
     */
    error OnlyWithMultisig(address caller);

    /**
     * @dev Error indicating that the stable balance is insufficient for the transaction.
     * @param stableBalance The current stable balance.
     * @param amount The required amount.
     */
    error InsufficientStableBalance(uint256 stableBalance, uint256 amount);

    /**
     * @dev Error indicating that an invalid percentage was provided.
     * @param percents The provided percentage.
     */
    error InvalidPercentage(uint256 percents);

    /**
     * @dev Error indicating that an invalid percentage for liquidity was provided.
     * @param newPercentLiquidity The provided percentage for liquidity.
     */
    error InvalidPercentLiquidity(uint256 newPercentLiquidity);

    /**
     * @dev Error indicating that invalid pool addresses were provided.
     * @param usdtPool The address of the USDT pool.
     * @param usdcPool The address of the USDC pool.
     * @param daiPool The address of the DAI pool.
     */
    error InvalidPoolsAddress(
        address usdtPool,
        address usdcPool,
        address daiPool
    );

    /**
     * @dev Error indicating that at least one owner is required for the contract.
     * @param ownersLenght The number of owners provided.
     */
    error OwnersRequire(uint256 ownersLenght);

    /**
     * @dev Error indicating that the number of required signatures is invalid.
     * @param signatures The provided number of signatures.
     * @param ownersLenght The number of owners.
     */
    error InvalidNumberSignatures(uint256 signatures, uint256 ownersLenght);

    /**
     * @dev Error indicating that the sender is not an owner.
     * @param sender The address of the sender.
     */
    error NotAnOwner(address sender);

    /**
     * @dev Error indicating that the transaction with the provided ID does not exist.
     * @param idTransaction The ID of the transaction.
     */
    error NotTransaction(uint256 idTransaction);

    /**
     * @dev Error indicating that the transaction has already been executed.
     * @param idTransaction The ID of the transaction.
     */
    error AlreadyExecuted(uint256 idTransaction);

    /**
     * @dev Error indicating that the transaction has already been signed.
     * @param idTransaction The ID of the transaction.
     */
    error AlreadySigned(uint256 idTransaction);

    /**
     * @dev Error indicating that the transaction does not have enough signatures.
     * @param idTransaction The ID of the transaction.
     */
    error NotEnoughSignatures(uint256 idTransaction);

    /**
     * @dev Error indicating that the caller is not the multisig contract.
     * @param sender The address of the sender.
     */
    error onlyMultiSigError(address sender);

    /**
     * @dev Error indicating that the provided owner address was not found.
     * @param owner The address of the owner.
     */
    error AddressNotFound(address owner);

    /**
     * @dev Error indicating that the provided owner address is invalid.
     * @param owner The address of the invalid owner.
     */
    error InvalidAddressOwner(address owner);

    /**
     * @dev Error indicating that the provided address is invalid.
     */
    error InvalidAddress();

    /**
     * @dev Error indicating that there was an issue changing the pool.
     * @param useAave Boolean indicating whether the Aave pool is being used.
     */
    error ChangePool(bool useAave);

    // UNISWAP

    /**
     * @dev Error indicating that no available fee tier was found on Uniswap.
     */
    error NoAvalibleFee();
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Events {
    /**
     * @dev Emitted when a user buys Stalwart tokens using a stablecoin.
     * @param buyer The address of the buyer.
     * @param amount The amount of Stalwart tokens purchased.
     * @param stableAddress The address of the stablecoin used for the purchase.
     */
    event BuyStalwartForStable(
        address indexed buyer,
        uint256 amount,
        address stableAddress
    );

    /**
     * @dev Emitted when a user buys Stalwart tokens using another token through a swap.
     * @param buyer The address of the buyer.
     * @param amount The amount of Stalwart tokens purchased.
     * @param token The address of the token used for the swap.
     * @param swapAmount The amount of the token swapped to purchase Stalwart tokens.
     */
    event BuyStalwartForToken(
        address indexed buyer,
        uint256 amount,
        address token,
        uint256 swapAmount
    );

    /**
     * @dev Emitted when a user buys Stalwart tokens using ETH.
     * @param buyer The address of the buyer.
     * @param amount The amount of ETH used to buy Stalwart tokens.
     * @param swapAmount The amount of stablecoin received after swapping ETH.
     */
    event BuyStalwartForEth(
        address indexed buyer,
        uint256 amount,
        uint256 swapAmount
    );

    /**
     * @dev Emitted when a user sells Stalwart tokens in exchange for a stablecoin.
     * @param seller The address of the seller.
     * @param amount The amount of Stalwart tokens sold.
     * @param stableAddress The address of the stablecoin received from the sale.
     */
    event SellStalwart(
        address indexed seller,
        uint256 amount,
        address stableAddress
    );

    /**
     * @dev Emitted when the rebalancing of liquidity pools is executed.
     * @param executor The address of the user or contract that executed the rebalancing.
     */
    event Rebalanced(address indexed executor);

    /**
     * @dev Emitted when a new transaction is created within the multisig contract.
     * @param transactionId The ID of the transaction.
     * @param data The data associated with the transaction.
     */
    event TransactionCreated(uint256 indexed transactionId, bytes data);

    /**
     * @dev Emitted when a transaction is signed by an owner within the multisig contract.
     * @param transactionId The ID of the transaction.
     * @param by The address of the owner who signed the transaction.
     */
    event TransactionSigned(uint256 indexed transactionId, address by);

    /**
     * @dev Emitted when a transaction is executed within the multisig contract.
     * @param transactionId The ID of the transaction.
     */
    event TransactionExecuted(uint256 indexed transactionId);

    /**
     * @dev Emitted when a token swap is executed.
     * @param user The address of the user who executed the swap.
     * @param tokenIn The address of the input token.
     * @param tokenOut The address of the output token.
     * @param amountIn The amount of input tokens swapped.
     * @param amountOut The amount of output tokens received.
     * @param poolFee The fee tier of the pool used for the swap.
     */
    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint24 poolFee
    );

    /**
     * @dev Emitted when liquidity is sent to a rebalancer pool.
     * @param pool The address of the rebalancer pool.
     * @param amount The amount of liquidity sent.
     */
    event LiquiditySentToPool(address indexed pool, uint256 amount);

    /**
     * @dev Emitted when liquidity is sent to an Aave pool.
     * @param stable The address of the stablecoin.
     * @param amount The amount of liquidity sent.
     */
    event LiquiditySentToAave(address indexed stable, uint256 amount);

    /**
     * @dev Emitted when liquidity is withdrawn from a rebalancer pool.
     * @param pool The address of the rebalancer pool.
     * @param amount The amount of liquidity withdrawn.
     */
    event LiquidityWithdrawnFromPool(address indexed pool, uint256 amount);

    /**
     * @dev Emitted when liquidity is withdrawn from an Aave pool.
     * @param stable The address of the stablecoin.
     * @param amount The amount of liquidity withdrawn.
     */
    event LiquidityWithdrawnFromAave(address indexed stable, uint256 amount);

    /**
     * @dev Emitted when the target percentages for stablecoins in the liquidity pools are changed.
     * @param usdtPercentage The new target percentage for USDT.
     * @param usdcPercentage The new target percentage for USDC.
     * @param daiPercentage The new target percentage for DAI.
     */
    event TargetPercentageChanged(
        uint256 usdtPercentage,
        uint256 usdcPercentage,
        uint256 daiPercentage
    );

    /**
     * @dev Emitted when the percentage of liquidity sent to pools is changed.
     * @param newPercentLiquidity The new percentage of liquidity to send to pools.
     */
    event LiquidityPercentageChanged(uint256 newPercentLiquidity);

    /**
     * @dev Emitted when the addresses of rebalancer pools are changed.
     * @param usdtPool The new address of the USDT rebalancer pool.
     * @param usdcPool The new address of the USDC rebalancer pool.
     * @param daiPool The new address of the DAI rebalancer pool.
     */
    event PoolAddressesChanged(
        address usdtPool,
        address usdcPool,
        address daiPool
    );

    /**
     * @dev Emitted when the settings for Aave pool and incentives are changed.
     * @param pool The new address of the Aave pool.
     * @param incentives The new address of the Aave incentives contract.
     * @param usdt The new address of the USDT token.
     * @param usdc The new address of the USDC token.
     * @param dai The new address of the DAI token.
     */
    event AaveSettingsChanged(
        address pool,
        address incentives,
        address usdt,
        address usdc,
        address dai
    );

    /**
     * @dev Emitted when rewards are withdrawn from the contract to a specified address.
     * @param rewards The address of the reward token withdrawn.
     * @param to The address receiving the rewards.
     * @param amount The amount of rewards withdrawn.
     */
    event RewardsWithdrawn(
        address indexed rewards,
        address indexed to,
        uint256 amount
    );
}

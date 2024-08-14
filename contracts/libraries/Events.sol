// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

library Events {
    event BuyStalwartForStable(
        address indexed buyer,
        uint256 amount,
        address stableAddress
    );
    event BuyStalwartForToken(
        address indexed buyer,
        uint256 amount,
        address token,
        uint256 swapAmount
    );
    event BuyStalwartForEth(
        address indexed buyer,
        uint256 amount,
        uint256 swapAmount
    );
    event SellStalwart(
        address indexed seller,
        uint256 amount,
        address stableAddress
    );
    event Rebalanced(address indexed executor);

    event TransactionCreated(uint256 indexed transactionId, bytes data);
    event TransactionSigned(uint256 indexed transactionId, address by);
    event TransactionExecuted(uint256 indexed transactionId);

    event SwapExecuted(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint24 poolFee
    );

    event LiquiditySentToPool(address indexed pool, uint256 amount);
    event LiquiditySentToAave(address indexed stable, uint256 amount);
    event LiquidityWithdrawnFromPool(address indexed pool, uint256 amount);
    event LiquidityWithdrawnFromAave(address indexed stable, uint256 amount);
    event TargetPercentageChanged(
        uint256 usdtPercentage,
        uint256 usdcPercentage,
        uint256 daiPercentage
    );
    event LiquidityPercentageChanged(uint256 newPercentLiquidity);
    event PoolAddressesChanged(
        address usdtPool,
        address usdcPool,
        address daiPool
    );
    event AaveSettingsChanged(
        address pool,
        address incentives,
        address usdt,
        address usdc,
        address dai
    );
    event RewardsWithdrawn(
        address indexed rewards,
        address indexed to,
        uint256 amount
    );
}

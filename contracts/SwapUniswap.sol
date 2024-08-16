// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma abicoder v2;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {Errors} from "./libraries/Errors.sol";
import {Addresses} from "./libraries/Addresses.sol";
import {Events} from "./libraries/Events.sol";

contract SwapUniswap {
    /// @dev List of fee tiers supported by Uniswap pools.
    uint24[] public feeTiers = [500, 3000, 10000];

    /// @dev Enumeration representing supported stablecoins.
    enum StableType {
        DAI,
        USDT,
        USDC
    }

    /**
     * @notice Executes a single input token swap for a specified stablecoin.
     * @dev This function swaps a fixed amount of input token (`token`) for the maximum possible amount of `stable` token.
     * The caller must approve this contract to spend at least `amountIn` worth of its tokens before calling this function.
     * @param amountIn The exact amount of `token` that will be swapped.
     * @param token The address of the input token.
     * @param stable The address of the stablecoin to receive in return.
     * @return amountOut The amount of stablecoin received after the swap.
     */
    function swapExactInputSingle(
        uint256 amountIn,
        address token,
        address stable
    ) internal returns (uint256 amountOut) {
        uint24 poolFee = _findMinimumFeeTier(token, stable);

        if (token != Addresses.WETH_ARB) {
            TransferHelper.safeTransferFrom(
                token,
                msg.sender,
                address(this),
                amountIn
            );
        }

        TransferHelper.safeApprove(
            token,
            address(Addresses.SWAP_ROUTER),
            amountIn
        );

        (
            uint256 amountOutMinimum,
            uint160 sqrtPriceX96After
        ) = _getAmountOutMinimum(token, stable, amountIn, poolFee);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token,
                tokenOut: stable,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: sqrtPriceX96After
            });

        amountOut = Addresses.SWAP_ROUTER.exactInputSingle(params);

        emit Events.SwapExecuted(
            msg.sender,
            token,
            stable,
            amountIn,
            amountOut,
            poolFee
        );
    }

    /**
     * @notice Calculates the minimum output amount for a given input amount, token pair, and pool fee.
     * @dev Uses the Uniswap V3 Quoter to estimate the minimum amount of `tokenOut` that can be received for `amountIn` of `tokenIn`.
     * @param tokenIn The address of the input token.
     * @param tokenOut The address of the output token (usually a stablecoin).
     * @param amountIn The exact amount of input tokens to be swapped.
     * @param poolFee The fee tier of the pool to be used for the swap.
     * @return amountOutMinimum The minimum amount of output tokens expected from the swap.
     * @return sqrtPriceX96After The square root of the price after the swap, represented in Q96 format.
     */
    function _getAmountOutMinimum(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee
    ) internal returns (uint256 amountOutMinimum, uint160 sqrtPriceX96After) {
        IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2
            .QuoteExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amountIn,
                fee: poolFee,
                sqrtPriceLimitX96: 0
            });

        (amountOutMinimum, sqrtPriceX96After, , ) = Addresses
            .QUOTERV2
            .quoteExactInputSingle(params);
    }

    /**
     * @notice Finds the minimum fee tier available for a specific token pair.
     * @dev This function identifies the lowest available fee tier for the provided token pair.
     * If no pool is available for the given token pair, the function reverts with an error.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @return The minimum fee tier available for the specified token pair.
     */
    function _findMinimumFeeTier(
        address tokenA,
        address tokenB
    ) internal view returns (uint24) {
        uint24[] memory availableFeeTiers = _findAvailableFeeTiers(
            tokenA,
            tokenB
        );

        if (availableFeeTiers.length == 0) {
            revert Errors.NoAvalibleFee();
        }

        uint24 minFee = availableFeeTiers[0];
        for (uint256 i = 1; i < availableFeeTiers.length; i++) {
            if (availableFeeTiers[i] < minFee) {
                minFee = availableFeeTiers[i];
            }
        }

        return minFee;
    }

    /**
     * @notice Finds available fee tiers for a specific token pair.
     * @dev This function checks for available Uniswap pools with the given fee tiers for the provided token pair.
     * @param tokenA The address of the first token in the pair.
     * @param tokenB The address of the second token in the pair.
     * @return availableFeeTiers An array of available fee tiers that have pools for the specified token pair.
     */
    function _findAvailableFeeTiers(
        address tokenA,
        address tokenB
    ) internal view returns (uint24[] memory availableFeeTiers) {
        uint24[] memory availableFees = new uint24[](feeTiers.length);
        uint256 count = 0;

        for (uint256 i = 0; i < feeTiers.length; i++) {
            address pool = Addresses.UNISWAP_V3_FACTORY.getPool(
                tokenA,
                tokenB,
                feeTiers[i]
            );
            if (pool != address(0)) {
                availableFees[count] = feeTiers[i];
                count++;
            }
        }

        availableFeeTiers = new uint24[](count);
        for (uint256 i = 0; i < count; i++) {
            availableFeeTiers[i] = availableFees[i];
        }
    }
}

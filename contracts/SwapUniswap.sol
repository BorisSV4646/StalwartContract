// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma abicoder v2;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {IUniswapV3Factory, IUniswapV3Pool} from "./interfaces/IUniswapPool.sol";
import {Errors} from "./libraries/Errors.sol";

contract SwapUniswap {
    ISwapRouter public immutable swapRouter;
    IQuoterV2 public immutable quoterV2;
    IUniswapV3Factory public immutable uniswapV3Factory;

    uint24[] public feeTiers = [500, 3000, 10000];

    enum StableType {
        DAI,
        USDT,
        USDC
    }

    address public immutable DAI = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;
    address public immutable USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address public immutable USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address public immutable WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;

    constructor(
        ISwapRouter _swapRouter,
        IQuoterV2 _quoterv2,
        IUniswapV3Factory _uniswapV3Factory
    ) {
        swapRouter = _swapRouter;
        quoterV2 = _quoterv2;
        uniswapV3Factory = _uniswapV3Factory;
    }

    function getAmountOutMinimum(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint24 poolFee
    ) public returns (uint256 amountOutMinimum, uint160 sqrtPriceX96After) {
        IQuoterV2.QuoteExactInputSingleParams memory params = IQuoterV2
            .QuoteExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                amountIn: amountIn,
                fee: poolFee,
                sqrtPriceLimitX96: 0
            });

        (amountOutMinimum, sqrtPriceX96After, , ) = quoterV2
            .quoteExactInputSingle(params);
    }

    /// @notice swapExactInputSingle swaps a fixed amount of DAI for a maximum possible amount of WETH9
    /// using the DAI/WETH9 0.3% pool by calling `exactInputSingle` in the swap router.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
    /// @param amountIn The exact amount of DAI that will be swapped for WETH9.
    /// @return amountOut The amount of WETH9 received.
    function swapExactInputSingle(
        uint256 amountIn,
        address token,
        address stable
    ) internal returns (uint256 amountOut) {
        uint24 poolFee = findMinimumFeeTier(token, stable);

        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(token, address(swapRouter), amountIn);

        (
            uint256 amountOutMinimum,
            uint160 sqrtPriceX96After
        ) = getAmountOutMinimum(token, stable, amountIn, poolFee);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: token,
                tokenOut: stable,
                fee: poolFee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMinimum,
                sqrtPriceLimitX96: sqrtPriceX96After
            });

        amountOut = swapRouter.exactInputSingle(params);
    }

    /// @notice swapInputMultiplePools swaps a fixed amount of DAI for a maximum possible amount of WETH9 through an intermediary pool.
    /// For this example, we will swap DAI to USDC, then USDC to WETH9 to achieve our desired output.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
    /// @param amountIn The amount of DAI to be swapped.
    /// @return amountOut The amount of WETH9 received after the swap.
    function swapExactInputMultihop(
        uint256 amountIn,
        address token,
        address stable
    ) internal returns (uint256 amountOut) {
        uint24 poolFee = findMinimumFeeTier(token, stable);

        TransferHelper.safeTransferFrom(
            token,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(token, address(swapRouter), amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: abi.encodePacked(token, poolFee, USDC, poolFee, stable),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0
            });

        amountOut = swapRouter.exactInput(params);
    }

    function findAvailableFeeTiers(
        address tokenA,
        address tokenB
    ) internal view returns (uint24[] memory availableFeeTiers) {
        uint24[] memory availableFees = new uint24[](feeTiers.length);
        uint256 count = 0;

        for (uint256 i = 0; i < feeTiers.length; i++) {
            address pool = uniswapV3Factory.getPool(
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

    function findMinimumFeeTier(
        address tokenA,
        address tokenB
    ) internal view returns (uint24) {
        uint24[] memory availableFeeTiers = findAvailableFeeTiers(
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
}

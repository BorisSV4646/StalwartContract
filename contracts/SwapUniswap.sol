// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma abicoder v2;

import {TransferHelper} from "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {IUniswapV3Factory, IUniswapV3Pool} from "./interfaces/IUniswapPool.sol";

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

    address public immutable DAI;
    address public immutable USDT;
    address public immutable USDC;
    address public immutable WETH;

    error NoAvalibleFee();
    error InvalidAddress();

    constructor(
        ISwapRouter _swapRouter,
        IQuoterV2 _quoterv2,
        IUniswapV3Factory _uniswapV3Factory,
        address _dai,
        address _usdt,
        address _usdc,
        address _weth
    ) {
        if (
            _dai == address(0) ||
            _usdt == address(0) ||
            _usdc == address(0) ||
            _weth == address(0)
        ) {
            revert InvalidAddress();
        }

        swapRouter = _swapRouter;
        quoterV2 = _quoterv2;
        uniswapV3Factory = _uniswapV3Factory;
        DAI = _dai;
        USDT = _usdt;
        USDC = _usdc;
        WETH = _weth;
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
            revert NoAvalibleFee();
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

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
pragma abicoder v2;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

contract SwapUniswap {
    ISwapRouter public immutable swapRouter;
    IQuoterV2 public immutable quoterV2;

    enum StableType {
        DAI,
        USDT,
        USDC
    }

    address public immutable DAI;
    address public immutable USDT;
    address public immutable USDC;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint24 public constant poolFee = 3000;

    constructor(
        ISwapRouter _swapRouter,
        IQuoterV2 _quoterv2,
        address _dai,
        address _usdt,
        address _usdc
    ) {
        swapRouter = _swapRouter;
        quoterV2 = _quoterv2;
        DAI = _dai;
        USDT = _usdt;
        USDC = _usdc;
    }

    function getAmountOutMinimum(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
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
        ) = getAmountOutMinimum(token, stable, amountIn);

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
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract SwapUniswap {
    ISwapRouter public immutable swapRouter;

    enum StableType {DAI, USDT, USDC }

    address public immutable DAI;
    address public immutable USDT;
    address public immutable USDC;
    address public constant WETH9 = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
 

    uint24 public constant poolFee = 3000;

    constructor(ISwapRouter _swapRouter, address _dai, address _usdt, address _usdc) {
        swapRouter = _swapRouter;
        DAI = _dai;
        USDT = _usdt;
        USDC = _usdc;
    }

    /// @notice swapInputMultiplePools swaps a fixed amount of DAI for a maximum possible amount of WETH9 through an intermediary pool.
    /// For this example, we will swap DAI to USDC, then USDC to WETH9 to achieve our desired output.
    /// @dev The calling address must approve this contract to spend at least `amountIn` worth of its DAI for this function to succeed.
    /// @param amountIn The amount of DAI to be swapped.
    /// @return amountOut The amount of WETH9 received after the swap.
    function swapExactInputMultihop(
        uint256 amountIn
    ) external returns (uint256 amountOut) {
        TransferHelper.safeTransferFrom(
            DAI,
            msg.sender,
            address(this),
            amountIn
        );

        TransferHelper.safeApprove(DAI, address(swapRouter), amountIn);

        ISwapRouter.ExactInputParams memory params = ISwapRouter
            .ExactInputParams({
                path: abi.encodePacked(DAI, poolFee, USDC, poolFee, WETH9),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: 0
            });

        amountOut = swapRouter.exactInput(params);
    }

    /// @notice swapExactOutputMultihop swaps a minimum possible amount of DAI for a fixed amount of WETH through an intermediary pool.
    /// For this example, we want to swap DAI for WETH9 through a USDC pool but we specify the desired amountOut of WETH9. Notice how the path encoding is slightly different in for exact output swaps.
    /// @dev The calling address must approve this contract to spend its DAI for this function to succeed. As the amount of input DAI is variable,
    /// the calling address will need to approve for a slightly higher amount, anticipating some variance.
    /// @param amountOut The desired amount of WETH9.
    /// @param amountInMaximum The maximum amount of DAI willing to be swapped for the specified amountOut of WETH9.
    /// @return amountIn The amountIn of DAI actually spent to receive the desired amountOut.
    function swapExactOutputMultihop(
        uint256 amountOut,
        uint256 amountInMaximum
    ) external returns (uint256 amountIn) {
        TransferHelper.safeTransferFrom(
            DAI,
            msg.sender,
            address(this),
            amountInMaximum
        );
        TransferHelper.safeApprove(DAI, address(swapRouter), amountInMaximum);

        ISwapRouter.ExactOutputParams memory params = ISwapRouter
            .ExactOutputParams({
                path: abi.encodePacked(WETH9, poolFee, USDC, poolFee, DAI),
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: amountOut,
                amountInMaximum: amountInMaximum
            });

        amountIn = swapRouter.exactOutput(params);

        if (amountIn < amountInMaximum) {
            TransferHelper.safeApprove(DAI, address(swapRouter), 0);
            TransferHelper.safeTransferFrom(
                DAI,
                address(this),
                msg.sender,
                amountInMaximum - amountIn
            );
        }
    }
}

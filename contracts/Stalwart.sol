// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./MultiSig.sol";
import "./SwapUniswap.sol";

contract Stalwart is ERC20, MultiSigStalwart, SwapUniswap {
    error InvalidStableType();
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

    constructor(
        address[] memory _owners,
        uint _requiredSignatures,
        ISwapRouter _swapRouter,
        address _dai,
        address _usdt,
        address _usdc
    )
        ERC20("Stalwart", "STL")
        MultiSigStalwart(_owners, _requiredSignatures)
        SwapUniswap(_swapRouter, _dai, _usdt, _usdc)
    {}

    // need to get approve
    function buyStalwartForStable(
        uint256 amount,
        StableType typeStable
    ) external {
        address stableAddress = getStableAddress(typeStable);
        IERC20 stableToken = IERC20(stableAddress);

        uint256 balance = stableToken.balanceOf(msg.sender);
        if (balance < amount) {
            revert InsufficientBalance(balance, amount, msg.sender);
        }

        uint256 allowance = stableToken.allowance(msg.sender, address(this));
        if (allowance < amount) {
            revert InsufficientAllowance(allowance, amount, msg.sender);
        }

        TransferHelper.safeTransferFrom(
            stableAddress,
            msg.sender,
            address(this),
            amount
        );

        _mint(msg.sender, amount);
    }

    // need to get approve
    function buyStalwartForToken() external {}

    function buyStalwartForEth() external payable {}

    function soldStalwart() external {}

    function rebalancer() external {}

    function getStableAddress(
        StableType typeStable
    ) internal view returns (address) {
        if (typeStable == StableType.DAI) {
            return DAI;
        } else if (typeStable == StableType.USDT) {
            return USDT;
        } else if (typeStable == StableType.USDC) {
            return USDC;
        } else {
            revert InvalidStableType();
        }
    }
}

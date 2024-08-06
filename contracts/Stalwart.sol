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
    error InvalidERC20Token(address token);

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

        checkAllowanceAndBalance(msg.sender, stableToken, amount);

        TransferHelper.safeTransferFrom(
            stableAddress,
            msg.sender,
            address(this),
            amount
        );

        _mint(msg.sender, amount);
    }

    // need to get approve
    function buyStalwartForToken(uint256 amount, address token) external {
        isERC20(token);

        IERC20 sellToken = IERC20(token);

        checkAllowanceAndBalance(msg.sender, sellToken, amount);

        address memory needStable = checkStableBalance();
        uint256 swapAmount = swapExactInputMultihop(amount, token, needStable);

        _mint(msg.sender, swapAmount);
    }

    function buyStalwartForEth() external payable {}

    function soldStalwart() external {}

    function rebalancer() external {}

    function checkStableBalance() internal view returns (address) {
        IERC20 usdt = IERC20(USDT);
        IERC20 usds = IERC20(USDC);
        IERC20 dai = IERC20(DAI);

        uint256 balanceUSDT = usdt.balanceOf(address(this));
        uint256 balanceUSDC = usds.balanceOf(address(this));
        uint256 balanceDAI = dai.balanceOf(address(this));

        return
            getMinBalanceAddress(
                balanceUSDT,
                USDT,
                balanceUSDC,
                USDC,
                balanceDAI,
                DAI
            );
    }

    function getMinBalanceAddress(
        uint256 balanceA,
        address addressA,
        uint256 balanceB,
        address addressB,
        uint256 balanceC,
        address addressC
    ) internal pure returns (address) {
        if (balanceA <= balanceB && balanceA <= balanceC) {
            return addressA;
        } else if (balanceB <= balanceA && balanceB <= balanceC) {
            return addressB;
        } else {
            return addressC;
        }
    }

    function checkAllowanceAndBalance(
        address owner,
        address tokenAddress,
        uint256 amount
    ) internal view {
        IERC20 sellToken = IERC20(tokenAddress);

        uint256 balance = sellToken.balanceOf(msg.sender);
        if (balance < amount) {
            revert InsufficientBalance(balance, amount, msg.sender);
        }

        uint256 allowance = sellToken.allowance(owner, address(this));
        if (allowance < amount) {
            revert InsufficientAllowance(allowance, amount, owner);
        }
    }

    function isERC20(address _token) internal view {
        (bool success, bytes memory data) = _token.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );

        if (success && data.length == 0) {
            revert InvalidERC20Token(_token);
        }
    }

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

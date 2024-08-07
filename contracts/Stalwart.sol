// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./MultiSig.sol";
import "./SwapUniswap.sol";

contract Stalwart is ERC20, MultiSigStalwart, SwapUniswap {
    uint256 public usdtTargetPercentage = 70;
    uint256 public usdcTargetPercentage = 20;
    uint256 public daiTargetPercentage = 10;

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
    error InvalidPercentage(uint256 percents);

    constructor(
        address[] memory _owners,
        uint _requiredSignatures,
        ISwapRouter _swapRouter,
        IQuoterV2 _quoterv2,
        address _dai,
        address _usdt,
        address _usdc
    )
        ERC20("Stalwart", "STL")
        MultiSigStalwart(_owners, _requiredSignatures)
        SwapUniswap(_swapRouter, _quoterv2, _dai, _usdt, _usdc)
    {}

    // need to get approve
    // need give 50% to aave pools
    function buyStalwartForStable(
        uint256 amount,
        StableType typeStable
    ) external {
        address stableAddress = getStableAddress(typeStable);

        checkAllowanceAndBalance(msg.sender, stableAddress, amount);

        TransferHelper.safeTransferFrom(
            stableAddress,
            msg.sender,
            address(this),
            amount
        );

        _mint(msg.sender, amount);
    }

    // need to get approve
    // need give 50% to aave pools
    function buyStalwartForToken(uint256 amount, address token) external {
        isERC20(token);

        checkAllowanceAndBalance(msg.sender, token, amount);

        address needStable = checkStableBalance();
        uint256 swapAmount = swapExactInputSingle(amount, token, needStable);

        _mint(msg.sender, swapAmount);
    }

    function buyStalwartForEth() external payable {}

    function soldStalwart() external {}

    function rebalancer() external {}

    function sendToPool() internal {}

    function getFromPool() internal {}

    function checkStableBalance() internal view returns (address) {
        IERC20 usdt = IERC20(USDT);
        IERC20 usdc = IERC20(USDC);
        IERC20 dai = IERC20(DAI);

        uint256 balanceUSDT = usdt.balanceOf(address(this));
        uint256 balanceUSDC = usdc.balanceOf(address(this));
        uint256 balanceDAI = dai.balanceOf(address(this));

        uint256 totalBalance = balanceUSDT + balanceUSDC + balanceDAI;

        uint256 usdtPercentage = (balanceUSDT * 100) / totalBalance;
        uint256 usdcPercentage = (balanceUSDC * 100) / totalBalance;

        if (usdtPercentage < usdtTargetPercentage) {
            return USDT;
        } else if (usdcPercentage < usdcTargetPercentage) {
            return USDC;
        } else {
            return DAI;
        }
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

    function setUsdtTargetPercentage(
        uint256 _usdtPercentage,
        uint256 _usdcPercentage,
        uint256 _daiPercentage
    ) external {
        uint256 percents = _usdtPercentage + _usdcPercentage + _daiPercentage;

        if (percents != 100) {
            revert InvalidPercentage(percents);
        }

        usdtTargetPercentage = _usdtPercentage;
        usdcTargetPercentage = _usdcPercentage;
        daiTargetPercentage = _daiPercentage;
    }
}

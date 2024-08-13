// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "hardhat/console.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SwapUniswap, ISwapRouter, IQuoterV2, IUniswapV3Factory, TransferHelper} from "./SwapUniswap.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {StalwartLiquidity} from "./StalwartLiquidity.sol";
import {Errors} from "./libraries/Errors.sol";

contract Stalwart is StalwartLiquidity, SwapUniswap, ERC20 {
    constructor(
        address[] memory _owners,
        uint256 _requiredSignatures,
        ISwapRouter _swapRouter,
        IQuoterV2 _quoterv2,
        IUniswapV3Factory _uniswapV3Factory
    )
        ERC20("Stalwart", "STL")
        SwapUniswap(_swapRouter, _quoterv2, _uniswapV3Factory)
        StalwartLiquidity(_owners, _requiredSignatures)
    {}

    // need to get approve
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

        // менять апрув надо при смене ааве
        if (sendLiquidity) {
            address poolAddress = getPoolAddress(typeStable);
            uint256 amountLiquidity = (amount * percentLiquidity) / 100;

            _sendToPools(stableAddress, poolAddress, amountLiquidity);
        }

        _mint(msg.sender, amount);
    }

    // need to get approve
    function buyStalwartForToken(uint256 amount, address token) external {
        isERC20(token);

        checkAllowanceAndBalance(msg.sender, token, amount);

        address needStable = checkStableBalance(false);
        uint256 swapAmount = swapExactInputSingle(amount, token, needStable);

        if (sendLiquidity) {
            address poolAddress = getPoolAddress(needStable);
            uint256 amountLiquidity = (swapAmount * percentLiquidity) / 100;

            _sendToPools(needStable, poolAddress, amountLiquidity);
        }

        _mint(msg.sender, swapAmount);
    }

    function buyStalwartForEth() external payable {
        uint256 amount = msg.value;
        IWETH(WETH).deposit{value: amount}();

        address needStable = checkStableBalance(false);
        uint256 swapAmount = swapExactInputSingle(amount, WETH, needStable);

        if (sendLiquidity) {
            address poolAddress = getPoolAddress(needStable);
            uint256 amountLiquidity = (swapAmount * percentLiquidity) / 100;

            _sendToPools(needStable, poolAddress, amountLiquidity);
        }

        _mint(msg.sender, swapAmount);
    }

    function soldStalwart(uint256 amount) external {
        checkAllowanceAndBalance(msg.sender, address(this), amount);

        _burn(msg.sender, amount);

        address needStable = checkStableBalance(true);

        IERC20 stableToken = IERC20(needStable);
        uint256 stableBalance = stableToken.balanceOf(address(this));

        if (stableBalance < amount) {
            address poolAddress = getPoolAddress(needStable);
            _getFromPool(poolAddress, amount, needStable);
        }

        TransferHelper.safeTransferFrom(
            needStable,
            address(this),
            msg.sender,
            amount
        );
    }

    function showRecieveStable() external view returns (address needStable) {
        needStable = checkStableBalance(true);
    }

    function getAllBalances()
        public
        view
        returns (uint256 usdtBalance, uint256 usdcBalance, uint256 daiBalance)
    {
        usdtBalance = IERC20(USDT).balanceOf(address(this));
        usdcBalance = IERC20(USDC).balanceOf(address(this));
        daiBalance = IERC20(DAI).balanceOf(address(this));
        return (usdtBalance, usdcBalance, daiBalance);
    }

    function checkStableBalance(
        bool getMaxDeviation
    ) internal view returns (address) {
        (
            uint256 usdtBalance,
            uint256 usdcBalance,
            uint256 daiBalance
        ) = getAllBalances();

        uint256 usdtPoolToken;
        uint256 usdcPoolToken;
        uint256 daiPoolToken;
        if (!useAave) {
            (
                usdtPoolToken,
                usdcPoolToken,
                daiPoolToken
            ) = checkBalancerTokenBalances(true);
        } else {
            (
                usdtPoolToken,
                usdcPoolToken,
                daiPoolToken
            ) = checkBalancerTokenBalances(false);
        }

        uint256 totalBalance = (usdtBalance +
            usdcBalance +
            daiBalance +
            usdtPoolToken +
            usdcPoolToken +
            daiPoolToken) / 10 ** 18;

        uint256 targetUSDT = (totalBalance * targetPercentage.usdt) / 100;
        uint256 targetUSDC = (totalBalance * targetPercentage.usdc) / 100;
        uint256 targetDAI = (totalBalance * targetPercentage.dai) / 100;

        if (getMaxDeviation) {
            return getMaxDeviationAddress(targetUSDT, targetUSDC, targetDAI);
        } else {
            return getMinDeviationAddress(targetUSDT, targetUSDC, targetDAI);
        }
    }

    function getMaxDeviationAddress(
        uint256 targetUSDT,
        uint256 targetUSDC,
        uint256 targetDAI
    ) internal view returns (address) {
        int256 deviationA = int256(targetPercentage.usdt) - int256(targetUSDT);
        int256 deviationB = int256(targetPercentage.usdc) - int256(targetUSDC);
        int256 deviationC = int256(targetPercentage.dai) - int256(targetDAI);

        if (deviationA >= deviationB && deviationA >= deviationC) {
            return USDT;
        } else if (deviationB >= deviationA && deviationB >= deviationC) {
            return USDC;
        } else {
            return DAI;
        }
    }

    function getMinDeviationAddress(
        uint256 targetUSDT,
        uint256 targetUSDC,
        uint256 targetDAI
    ) internal view returns (address) {
        int256 deviationA = int256(targetPercentage.usdt) - int256(targetUSDT);
        int256 deviationB = int256(targetPercentage.usdc) - int256(targetUSDC);
        int256 deviationC = int256(targetPercentage.dai) - int256(targetDAI);

        if (deviationA <= deviationB && deviationA <= deviationC) {
            return USDT;
        } else if (deviationB <= deviationA && deviationB <= deviationC) {
            return USDC;
        } else {
            return DAI;
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
            revert Errors.InsufficientBalance(balance, amount, msg.sender);
        }

        uint256 allowance = sellToken.allowance(owner, address(this));
        if (allowance < amount) {
            revert Errors.InsufficientAllowance(allowance, amount, owner);
        }
    }

    function isERC20(address _token) internal view {
        (bool success, bytes memory data) = _token.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );

        if (success && data.length == 0) {
            revert Errors.InvalidERC20Token(_token);
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
            revert Errors.InvalidStableType();
        }
    }

    function getPoolAddress(
        StableType typeStable
    ) internal view returns (address) {
        if (typeStable == StableType.DAI) {
            return rebalancerPools.daiPool;
        } else if (typeStable == StableType.USDT) {
            return rebalancerPools.usdtPool;
        } else if (typeStable == StableType.USDC) {
            return rebalancerPools.usdcPool;
        } else {
            revert Errors.InvalidPoolType();
        }
    }

    function getPoolAddress(
        address stableAddress
    ) internal view returns (address) {
        if (stableAddress == DAI) {
            return rebalancerPools.daiPool;
        } else if (stableAddress == USDT) {
            return rebalancerPools.usdtPool;
        } else if (stableAddress == USDC) {
            return rebalancerPools.usdcPool;
        } else {
            revert Errors.InvalidPoolAddress();
        }
    }

    function rebalancer() external onlyOwner {
        bytes memory data = abi.encodeWithSignature("executeRebalancer()");
        createTransaction(data);
    }

    function executeRebalancer() internal {
        uint256 usdtPoolToken;
        uint256 usdcPoolToken;
        uint256 daiPoolToken;
        if (!useAave) {
            (
                usdtPoolToken,
                usdcPoolToken,
                daiPoolToken
            ) = checkBalancerTokenBalances(true);
        } else {
            (
                usdtPoolToken,
                usdcPoolToken,
                daiPoolToken
            ) = checkBalancerTokenBalances(false);
        }

        (
            uint256 usdtBalance,
            uint256 usdcBalance,
            uint256 daiBalance
        ) = getAllBalances();

        rebalanceTokenPool(
            usdtBalance,
            usdtPoolToken,
            rebalancerPools.usdtPool,
            USDT
        );
        rebalanceTokenPool(
            usdcBalance,
            usdcPoolToken,
            rebalancerPools.usdcPool,
            USDC
        );
        rebalanceTokenPool(
            daiBalance,
            daiPoolToken,
            rebalancerPools.daiPool,
            DAI
        );
    }

    // пока только ребалансирует активы между пулом и контрактом,
    // не делает ребалансировку в процентах между токенами, так как
    // тогда опять меняется соотношение с токенами в пулах
    function rebalanceTokenPool(
        uint256 tokenBalance,
        uint256 poolTokenBalance,
        address rebalancerPool,
        address needStable
    ) internal {
        uint256 totalBalance = tokenBalance + poolTokenBalance;
        uint256 targetBalance = (totalBalance * percentLiquidity) / 100;

        if (targetBalance < percentLiquidity) {
            uint256 needAmount = poolTokenBalance - (totalBalance / 2);
            _getFromPool(rebalancerPool, needAmount, needStable);
        } else {
            uint256 needAmount = tokenBalance - (totalBalance / 2);
            _sendToPools(needStable, rebalancerPool, needAmount);
        }
    }

    function _sendToPools(
        address needStable,
        address rebalancerPool,
        uint256 needAmount
    ) internal {
        if (!useAave) {
            TransferHelper.safeApprove(needStable, rebalancerPool, needAmount);
            _sendToPool(rebalancerPool, needAmount);
        } else {
            TransferHelper.safeApprove(needStable, aavePools.pool, needAmount);
            _sendToPoolAave(needStable, needAmount);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
// 1) структурировать функции
// 2) прописать комментарии
// 2) добавить эмиты
// 1) разобраться с контрактами ребалансера

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SwapUniswap, TransferHelper} from "./SwapUniswap.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {StalwartLiquidity} from "./StalwartLiquidity.sol";
import {Errors} from "./libraries/Errors.sol";
import {Addresses} from "./libraries/Addresses.sol";
import {Percents} from "./libraries/Percents.sol";

contract Stalwart is StalwartLiquidity, SwapUniswap, ERC20 {
    enum ScaleDirection {
        Up,
        Down
    }

    constructor(
        address[] memory _owners,
        uint256 _requiredSignatures
    )
        ERC20("Stalwart", "STL")
        StalwartLiquidity(_owners, _requiredSignatures)
    {}

    // need to get approve
    // amount - stalwart need 10 ** 18
    function buyStalwartForStable(
        uint256 amount,
        StableType typeStable
    ) external {
        address stableAddress = getStableAddress(typeStable);

        uint256 adjustedAmount = getAdjustedAmount(
            stableAddress,
            amount,
            ScaleDirection.Down
        );

        checkAllowanceAndBalance(msg.sender, stableAddress, adjustedAmount);

        TransferHelper.safeTransferFrom(
            stableAddress,
            msg.sender,
            address(this),
            adjustedAmount
        );

        if (sendLiquidity) {
            address poolAddress = getPoolAddress(typeStable);
            uint256 amountLiquidity = (adjustedAmount * percentLiquidity) / 100;

            _sendToPools(stableAddress, poolAddress, amountLiquidity);
        }

        _mint(msg.sender, amount);
    }

    // need to get approve
    function buyStalwartForToken(uint256 amount, address token) external {
        isERC20(token);
        address needStable = checkStableBalance(false);

        uint256 adjustedAmount = getAdjustedAmount(
            needStable,
            amount,
            ScaleDirection.Down
        );
        uint256 adjustedAmountSwap = getAdjustedAmount(
            token,
            amount,
            ScaleDirection.Down
        );

        checkAllowanceAndBalance(msg.sender, token, adjustedAmount);

        uint256 swapAmount = swapExactInputSingle(
            adjustedAmountSwap,
            token,
            needStable
        );

        if (sendLiquidity) {
            address poolAddress = getPoolAddress(needStable);
            uint256 amountLiquidity = (swapAmount * percentLiquidity) / 100;

            _sendToPools(needStable, poolAddress, amountLiquidity);
        }

        _mint(msg.sender, amount);
    }

    function buyStalwartForEth() external payable {
        uint256 amount = msg.value;
        IWETH(Addresses.WETH_ARB).deposit{value: amount}();

        address needStable = checkStableBalance(false);
        uint256 swapAmount = swapExactInputSingle(
            amount,
            Addresses.WETH_ARB,
            needStable
        );

        if (sendLiquidity) {
            address poolAddress = getPoolAddress(needStable);
            uint256 amountLiquidity = (swapAmount * percentLiquidity) / 100;

            _sendToPools(needStable, poolAddress, amountLiquidity);
        }

        uint256 adjustedMint = getAdjustedAmount(
            needStable,
            swapAmount,
            ScaleDirection.Up
        );

        _mint(msg.sender, adjustedMint);
    }

    function soldStalwart(uint256 amount) external {
        address needStable = checkStableBalance(true);

        checkAllowanceAndBalance(msg.sender, address(this), amount);

        _burn(msg.sender, amount);

        IERC20 stableToken = IERC20(needStable);
        uint256 stableBalance = stableToken.balanceOf(address(this));

        uint256 adjustedAmount = getAdjustedAmount(
            needStable,
            amount,
            ScaleDirection.Down
        );

        if (stableBalance < adjustedAmount) {
            address poolAddress = getPoolAddress(needStable);
            _getFromPool(poolAddress, adjustedAmount, needStable);
        }

        TransferHelper.safeTransferFrom(
            needStable,
            address(this),
            msg.sender,
            adjustedAmount
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
        usdtBalance = IERC20(Addresses.USDT_ARB).balanceOf(address(this));
        usdcBalance = IERC20(Addresses.USDC_ARB).balanceOf(address(this));
        daiBalance = IERC20(Addresses.DAI_ARB).balanceOf(address(this));
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
        (
            usdtPoolToken,
            usdcPoolToken,
            daiPoolToken
        ) = checkBalancerTokenBalances();

        uint256 totalBalance = (usdtBalance *
            Percents.SMALL_DECIMALS +
            usdcBalance *
            Percents.SMALL_DECIMALS +
            daiBalance +
            usdtPoolToken *
            Percents.SMALL_DECIMALS +
            usdcPoolToken *
            Percents.SMALL_DECIMALS +
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
            return Addresses.USDT_ARB;
        } else if (deviationB >= deviationA && deviationB >= deviationC) {
            return Addresses.USDC_ARB;
        } else {
            return Addresses.DAI_ARB;
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
            return Addresses.USDT_ARB;
        } else if (deviationB <= deviationA && deviationB <= deviationC) {
            return Addresses.USDC_ARB;
        } else {
            return Addresses.DAI_ARB;
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

    function getStableAddress(
        StableType typeStable
    ) internal pure returns (address) {
        if (typeStable == StableType.DAI) {
            return Addresses.DAI_ARB;
        } else if (typeStable == StableType.USDT) {
            return Addresses.USDT_ARB;
        } else if (typeStable == StableType.USDC) {
            return Addresses.USDC_ARB;
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
        if (stableAddress == Addresses.DAI_ARB) {
            return rebalancerPools.daiPool;
        } else if (stableAddress == Addresses.USDT_ARB) {
            return rebalancerPools.usdtPool;
        } else if (stableAddress == Addresses.USDC_ARB) {
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
        (
            usdtPoolToken,
            usdcPoolToken,
            daiPoolToken
        ) = checkBalancerTokenBalances();

        (
            uint256 usdtBalance,
            uint256 usdcBalance,
            uint256 daiBalance
        ) = getAllBalances();

        rebalanceTokenPool(
            usdtBalance,
            usdtPoolToken,
            rebalancerPools.usdtPool,
            Addresses.USDT_ARB
        );
        rebalanceTokenPool(
            usdcBalance,
            usdcPoolToken,
            rebalancerPools.usdcPool,
            Addresses.USDC_ARB
        );
        rebalanceTokenPool(
            daiBalance,
            daiPoolToken,
            rebalancerPools.daiPool,
            Addresses.DAI_ARB
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

    function getAdjustedAmount(
        address stableAddress,
        uint256 amount,
        ScaleDirection direction
    ) internal view returns (uint256) {
        uint8 decimals = IERC20Metadata(stableAddress).decimals();

        if (decimals == 18) {
            return amount;
        } else if (decimals == 6) {
            return
                direction == ScaleDirection.Up
                    ? amount * 10 ** 12
                    : amount / 10 ** 12;
        } else if (decimals == 8) {
            return
                direction == ScaleDirection.Up
                    ? amount * 10 ** 10
                    : amount / 10 ** 10;
        } else {
            revert Errors.UnsupportedDecimals(decimals);
        }
    }
}

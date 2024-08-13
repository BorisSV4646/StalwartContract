// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
// 1) структурировать функции
// 1) разобраться с контрактами ребалансера
// 3) сделать ребалансировку
// 4) добавить нули, так как usdt и usdc с 6 нулями, а не с 18

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SwapUniswap, TransferHelper} from "./SwapUniswap.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {StalwartLiquidity} from "./StalwartLiquidity.sol";
import {Errors} from "./libraries/Errors.sol";
import {Addresses} from "./libraries/Addresses.sol";

contract Stalwart is StalwartLiquidity, SwapUniswap, ERC20 {
    constructor(
        address[] memory _owners,
        uint256 _requiredSignatures
    )
        ERC20("Stalwart", "STL")
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
}

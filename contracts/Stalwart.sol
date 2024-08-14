// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SwapUniswap, TransferHelper} from "./SwapUniswap.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {StalwartLiquidity} from "./StalwartLiquidity.sol";
import {Errors} from "./libraries/Errors.sol";
import {Addresses} from "./libraries/Addresses.sol";
import {Percents} from "./libraries/Percents.sol";
import {Events} from "./libraries/Events.sol";

contract Stalwart is StalwartLiquidity, SwapUniswap, ERC20 {
    /// @dev Enumeration for scaling directions (up or down).
    enum ScaleDirection {
        Up,
        Down
    }

    /// @notice Constructor for the Stalwart contract.
    /// @param _owners List of addresses that own the multisig wallet.
    /// @param _requiredSignatures Number of signatures required to execute a transaction.
    constructor(
        address[] memory _owners,
        uint256 _requiredSignatures
    )
        ERC20("Stalwart", "STL")
        StalwartLiquidity(_owners, _requiredSignatures)
    {}

    /**
     * @notice Allows a user to buy Stalwart tokens using a stablecoin.
     * @param amount The amount of Stalwart tokens to purchase (scaled to 18 decimals).
     * @param typeStable The type of stablecoin used for the purchase (DAI, USDT, or USDC).
     */
    function buyStalwartForStable(
        uint256 amount,
        StableType typeStable
    ) external {
        address stableAddress = _getStableAddress(typeStable);

        uint256 adjustedAmount = _getAdjustedAmount(
            stableAddress,
            amount,
            ScaleDirection.Down
        );

        _checkAllowanceAndBalance(msg.sender, stableAddress, adjustedAmount);

        TransferHelper.safeTransferFrom(
            stableAddress,
            msg.sender,
            address(this),
            adjustedAmount
        );

        if (sendLiquidity) {
            address poolAddress = _getPoolAddress(typeStable);
            uint256 amountLiquidity = (adjustedAmount * percentLiquidity) / 100;

            _sendToPools(stableAddress, poolAddress, amountLiquidity);
        }

        _mint(msg.sender, amount);

        emit Events.BuyStalwartForStable(msg.sender, amount, stableAddress);
    }

    /**
     * @notice Allows a user to buy Stalwart tokens using any ERC20 token.
     * @param amount The amount of Stalwart tokens to purchase (scaled to 18 decimals).
     * @param token The address of the ERC20 token used for the purchase.
     */
    function buyStalwartForToken(uint256 amount, address token) external {
        isERC20(token);
        address needStable = _checkStableBalance(false);

        uint256 adjustedAmount = _getAdjustedAmount(
            needStable,
            amount,
            ScaleDirection.Down
        );
        uint256 adjustedAmountSwap = _getAdjustedAmount(
            token,
            amount,
            ScaleDirection.Down
        );

        _checkAllowanceAndBalance(msg.sender, token, adjustedAmount);

        uint256 swapAmount = swapExactInputSingle(
            adjustedAmountSwap,
            token,
            needStable
        );

        if (sendLiquidity) {
            address poolAddress = _getPoolAddress(needStable);
            uint256 amountLiquidity = (swapAmount * percentLiquidity) / 100;

            _sendToPools(needStable, poolAddress, amountLiquidity);
        }

        _mint(msg.sender, amount);

        emit Events.BuyStalwartForToken(msg.sender, amount, token, swapAmount);
    }

    /**
     * @notice Allows a user to buy Stalwart tokens using ETH.
     */
    function buyStalwartForEth() external payable {
        uint256 amount = msg.value;
        IWETH(Addresses.WETH_ARB).deposit{value: amount}();

        address needStable = _checkStableBalance(false);
        uint256 swapAmount = swapExactInputSingle(
            amount,
            Addresses.WETH_ARB,
            needStable
        );

        if (sendLiquidity) {
            address poolAddress = _getPoolAddress(needStable);
            uint256 amountLiquidity = (swapAmount * percentLiquidity) / 100;

            _sendToPools(needStable, poolAddress, amountLiquidity);
        }

        uint256 adjustedMint = _getAdjustedAmount(
            needStable,
            swapAmount,
            ScaleDirection.Up
        );

        _mint(msg.sender, adjustedMint);

        emit Events.BuyStalwartForEth(msg.sender, amount, swapAmount);
    }

    /**
     * @notice Allows a user to sell Stalwart tokens for a stablecoin.
     * @param amount The amount of Stalwart tokens to sell (scaled to 18 decimals).
     */
    function soldStalwart(uint256 amount) external {
        address needStable = _checkStableBalance(true);

        _checkAllowanceAndBalance(msg.sender, address(this), amount);

        _burn(msg.sender, amount);

        IERC20 stableToken = IERC20(needStable);
        uint256 stableBalance = stableToken.balanceOf(address(this));

        uint256 adjustedAmount = _getAdjustedAmount(
            needStable,
            amount,
            ScaleDirection.Down
        );

        if (stableBalance < adjustedAmount) {
            address poolAddress = _getPoolAddress(needStable);
            getFromPool(poolAddress, adjustedAmount, needStable);
        }

        TransferHelper.safeTransferFrom(
            needStable,
            address(this),
            msg.sender,
            adjustedAmount
        );

        emit Events.SellStalwart(msg.sender, amount, needStable);
    }

    /**
     * @notice Returns the address of the stablecoin with the highest or lowest deviation from the target balance.
     * @return needStable The address of the stablecoin.
     */
    function showRecieveStable() external view returns (address needStable) {
        needStable = _checkStableBalance(true);
    }

    /**
     * @notice Retrieves the balances of USDT, USDC, and DAI held by the contract.
     * @return usdtBalance The balance of USDT.
     * @return usdcBalance The balance of USDC.
     * @return daiBalance The balance of DAI.
     */
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

    /**
     * @notice Initiates the rebalancing process for the token pools.
     */
    function rebalancer() external onlyOwner {
        bytes memory data = abi.encodeWithSignature("executeRebalancer()");
        createTransaction(data);

        emit Events.Rebalanced(msg.sender);
    }

    /**
     * @dev Sends liquidity to the appropriate pools based on whether Aave is used or not.
     * @param needStable The address of the stablecoin.
     * @param rebalancerPool The address of the rebalancer pool.
     * @param needAmount The amount of stablecoin to send to the pool.
     */
    function _sendToPools(
        address needStable,
        address rebalancerPool,
        uint256 needAmount
    ) internal {
        if (!useAave) {
            TransferHelper.safeApprove(needStable, rebalancerPool, needAmount);
            sendToPool(rebalancerPool, needAmount);
        } else {
            TransferHelper.safeApprove(needStable, aavePools.pool, needAmount);
            sendToPoolAave(needStable, needAmount);
        }
    }

    /**
     * @dev Checks the balance and deviation of stablecoins in the contract and pools.
     * @param getMaxDeviation Indicates whether to return the stablecoin with the maximum deviation.
     * @return The address of the stablecoin.
     */
    function _checkStableBalance(
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
            return _getMaxDeviationAddress(targetUSDT, targetUSDC, targetDAI);
        } else {
            return _getMinDeviationAddress(targetUSDT, targetUSDC, targetDAI);
        }
    }

    /**
     * @dev Returns the address of the stablecoin with the maximum deviation from the target balance.
     * @param targetUSDT The target balance of USDT.
     * @param targetUSDC The target balance of USDC.
     * @param targetDAI The target balance of DAI.
     * @return The address of the stablecoin.
     */
    function _getMaxDeviationAddress(
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

    /**
     * @dev Returns the address of the stablecoin with the minimum deviation from the target balance.
     * @param targetUSDT The target balance of USDT.
     * @param targetUSDC The target balance of USDC.
     * @param targetDAI The target balance of DAI.
     * @return The address of the stablecoin.
     */
    function _getMinDeviationAddress(
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

    /**
     * @dev Checks the allowance and balance of a specific token for a specific owner.
     * @param owner The address of the token owner.
     * @param tokenAddress The address of the token.
     * @param amount The amount to check.
     */
    function _checkAllowanceAndBalance(
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

    /**
     * @dev Returns the address of the stablecoin based on the StableType enum.
     * @param typeStable The type of stablecoin.
     * @return The address of the stablecoin.
     */
    function _getStableAddress(
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

    /**
     * @dev Returns the address of the pool based on the StableType enum.
     * @param typeStable The type of stablecoin.
     * @return The address of the pool.
     */
    function _getPoolAddress(
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

    /**
     * @dev Returns the address of the pool based on the stablecoin address.
     * @param stableAddress The address of the stablecoin.
     * @return The address of the pool.
     */
    function _getPoolAddress(
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

    /**
     * @dev Adjusts the amount based on the stablecoin's decimal places.
     * @param stableAddress The address of the stablecoin.
     * @param amount The amount to adjust.
     * @param direction The direction to scale the amount (up or down).
     * @return The adjusted amount.
     */
    function _getAdjustedAmount(
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

    /**
     * @dev Executes the rebalancing of token pools.
     */
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

        _rebalanceTokenPool(
            usdtBalance,
            usdtPoolToken,
            rebalancerPools.usdtPool,
            Addresses.USDT_ARB
        );
        _rebalanceTokenPool(
            usdcBalance,
            usdcPoolToken,
            rebalancerPools.usdcPool,
            Addresses.USDC_ARB
        );
        _rebalanceTokenPool(
            daiBalance,
            daiPoolToken,
            rebalancerPools.daiPool,
            Addresses.DAI_ARB
        );
    }

    /**
     * @dev Rebalances the tokens between the contract and the pool.
     * @param tokenBalance The balance of the token in the contract.
     * @param poolTokenBalance The balance of the token in the pool.
     * @param rebalancerPool The address of the rebalancer pool.
     * @param needStable The address of the stablecoin.
     */
    function _rebalanceTokenPool(
        uint256 tokenBalance,
        uint256 poolTokenBalance,
        address rebalancerPool,
        address needStable
    ) internal {
        uint256 totalBalance = tokenBalance + poolTokenBalance;
        uint256 targetBalance = (totalBalance * percentLiquidity) / 100;

        if (targetBalance < percentLiquidity) {
            uint256 needAmount = poolTokenBalance - (totalBalance / 2);
            getFromPool(rebalancerPool, needAmount, needStable);
        } else {
            uint256 needAmount = tokenBalance - (totalBalance / 2);
            _sendToPools(needStable, rebalancerPool, needAmount);
        }
    }
}

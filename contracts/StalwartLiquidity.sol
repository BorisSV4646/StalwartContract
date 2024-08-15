// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MultiSigStalwart} from "./MultiSig.sol";
import {IRebalancer} from "./interfaces/IRebalancer.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IIncentives} from "./interfaces/IIncentives.sol";
import {TransferHelper} from "./SwapUniswap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Errors} from "./libraries/Errors.sol";
import {Addresses} from "./libraries/Addresses.sol";
import {Percents} from "./libraries/Percents.sol";
import {Events} from "./libraries/Events.sol";

contract StalwartLiquidity is MultiSigStalwart {
    /// @notice Indicates whether to send liquidity to pools.
    bool public sendLiquidity;

    /// @notice Indicates whether to use Aave for liquidity operations.
    bool public useAave;

    /// @notice Percentage of liquidity to be sent to pools.
    uint256 public percentLiquidity;

    /// @dev Stores target percentages for different stablecoins in the pool.
    struct TargetPercentage {
        uint256 usdt;
        uint256 usdc;
        uint256 dai;
    }
    TargetPercentage public targetPercentage;

    /// @dev Stores the addresses of rebalancer pools for different stablecoins.
    struct RebalancerPools {
        address usdtPool;
        address usdcPool;
        address daiPool;
    }
    RebalancerPools public rebalancerPools;

    /// @dev Stores the addresses of Aave pools and incentives.
    struct AavePools {
        address pool;
        address incentives;
        address usdt;
        address usdc;
        address dai;
    }
    AavePools public aavePools;

    /**
     * @notice Constructor initializes the contract with the given owners and required signatures.
     * @param _owners Array of addresses that will be the owners of the multisig wallet.
     * @param _requiredSignatures Number of signatures required to execute transactions.
     */
    constructor(
        address[] memory _owners,
        uint256 _requiredSignatures
    ) MultiSigStalwart(_owners, _requiredSignatures) {
        uint256 _percentLiquidity = Percents.PERCENT_LIQUIDITY;
        uint256 _usdtPercentage = Percents.USDT_PERCENT;
        uint256 _usdcPercentage = Percents.USDC_PERCENT;
        uint256 _daiPercentage = Percents.DAI_PERCENT;

        uint256 percents = _usdtPercentage + _usdcPercentage + _daiPercentage;
        if (percents != 100) {
            revert Errors.InvalidPercentage(percents);
        }
        targetPercentage = TargetPercentage(
            _usdtPercentage,
            _usdcPercentage,
            _daiPercentage
        );

        rebalancerPools = RebalancerPools(
            Addresses.REB_USDT_POOL,
            Addresses.REB_USDC_POOL,
            Addresses.REB_DAI_POOL
        );

        aavePools = AavePools(
            Addresses.AAVE_POOL,
            Addresses.AAVE_INCENTIVES,
            Addresses.AAVE_USDT,
            Addresses.AAVE_USDC,
            Addresses.AAVE_DAI
        );

        if (_percentLiquidity > 100) {
            revert Errors.InvalidPercentLiquidity(_percentLiquidity);
        }
        percentLiquidity = _percentLiquidity;

        sendLiquidity = true;
        useAave = false;
    }

    /**
     * @notice Retrieves liquidity from a specified pool.
     * @param pool The address of the pool from which to retrieve liquidity.
     * @param amount The amount of liquidity to retrieve.
     * @param stable The address of the stablecoin to withdraw.
     */
    function getFromPool(
        address pool,
        uint256 amount,
        address stable
    ) internal {
        if (!useAave) {
            IRebalancer(pool).withdraw(amount, address(this), address(this));
            emit Events.LiquidityWithdrawnFromPool(pool, amount);
        } else {
            address[] memory assets;
            assets[0] = stable;

            IIncentives(aavePools.incentives).claimAllRewards(
                assets,
                address(this)
            );
            IPool(aavePools.pool).withdraw(stable, amount, address(this));
            emit Events.LiquidityWithdrawnFromAave(stable, amount);
        }
    }

    /**
     * @notice Sends liquidity to a specified rebalancer pool.
     * @param pool The address of the rebalancer pool.
     * @param amount The amount of liquidity to send.
     */
    function sendToPool(address pool, uint256 amount) internal {
        IRebalancer(pool).deposit(amount, address(this));
        emit Events.LiquiditySentToPool(pool, amount);
    }

    /**
     * @notice Sends liquidity to an Aave pool.
     * @param stable The address of the stablecoin.
     * @param amount The amount of liquidity to send.
     */
    function sendToPoolAave(address stable, uint256 amount) internal {
        IPool(aavePools.pool).supply(stable, amount, address(this), 0);
        emit Events.LiquiditySentToAave(stable, amount);
    }

    /**
     * @notice Checks the balance of tokens in rebalancer pools or Aave pools.
     * @return usdtPoolToken The balance of USDT tokens in the pool.
     * @return usdcPoolToken The balance of USDC tokens in the pool.
     * @return daiPoolToken The balance of DAI tokens in the pool.
     */
    function checkBalancerTokenBalances()
        public
        view
        returns (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        )
    {
        if (!useAave) {
            usdtPoolToken = IRebalancer(rebalancerPools.usdtPool).balanceOf(
                address(this)
            );
            usdcPoolToken = IRebalancer(rebalancerPools.usdcPool).balanceOf(
                address(this)
            );
            daiPoolToken = IRebalancer(rebalancerPools.daiPool).balanceOf(
                address(this)
            );
        } else {
            usdtPoolToken = IERC20(aavePools.usdt).balanceOf(address(this));
            usdcPoolToken = IERC20(aavePools.usdc).balanceOf(address(this));
            daiPoolToken = IERC20(aavePools.dai).balanceOf(address(this));
        }
    }

    /**
     * @notice Verifies whether the provided address is an ERC20 token contract.
     * @param _token The address of the token to check.
     */
    function isERC20(address _token) internal view {
        (bool success, bytes memory data) = _token.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );

        if (success && data.length == 0) {
            revert Errors.InvalidERC20Token(_token);
        }
    }

    /**
     * @notice Claims all rewards from Aave for a specified set of assets.
     */
    function _claimAllRewardsAave() internal {
        address[] memory assets;

        assets[0] = Addresses.USDT_ARB;
        assets[1] = Addresses.USDC_ARB;
        assets[2] = Addresses.DAI_ARB;

        IIncentives(aavePools.incentives).claimAllRewards(
            assets,
            address(this)
        );
    }

    /**
     * @notice Sets target percentages for USDT, USDC, and DAI in the pools.
     * @param _usdtPercentage The target percentage for USDT.
     * @param _usdcPercentage The target percentage for USDC.
     * @param _daiPercentage The target percentage for DAI.
     */
    function setTargetPercentage(
        uint256 _usdtPercentage,
        uint256 _usdcPercentage,
        uint256 _daiPercentage
    ) external onlyOwner {
        uint256 percents = _usdtPercentage + _usdcPercentage + _daiPercentage;

        if (percents != 100) {
            revert Errors.InvalidPercentage(percents);
        }

        bytes memory data = abi.encodeWithSignature(
            "executeSetTargetPercentage(uint256,uint256,uint256)",
            _usdtPercentage,
            _usdcPercentage,
            _daiPercentage
        );
        createTransaction(data);
    }

    /**
     * @notice Retrieves all liquidity from the rebalancer or Aave pools.
     */
    function getAllLiquidity() external onlyOwner {
        (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        ) = checkBalancerTokenBalances();

        bytes memory data = abi.encodeWithSignature(
            "executeGetAllLiquidity(uint256,uint256,uint256)",
            usdtPoolToken,
            usdcPoolToken,
            daiPoolToken
        );
        createTransaction(data);
    }

    /**
     * @notice Changes the status of sending liquidity to pools.
     * @param newSendLiquidity The new status of the sendLiquidity flag.
     */
    function changeSendLiquidity(bool newSendLiquidity) external onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "executeChangeSendLiquidity(bool)",
            newSendLiquidity
        );
        createTransaction(data);
    }

    /**
     * @notice Changes the addresses of rebalancer pools for USDT, USDC, and DAI.
     * @dev This function can only be executed if useAave is set to false.
     * @param _usdtRebalancerPool The new address of the USDT rebalancer pool.
     * @param _usdcRebalancerPool The new address of the USDC rebalancer pool.
     * @param _daiRebalancerPool The new address of the DAI rebalancer pool.
     */
    function changePoolsAddress(
        address _usdtRebalancerPool,
        address _usdcRebalancerPool,
        address _daiRebalancerPool
    ) external onlyOwner {
        if (
            _usdtRebalancerPool == address(0) ||
            _usdcRebalancerPool == address(0) ||
            _daiRebalancerPool == address(0)
        ) {
            revert Errors.InvalidPoolsAddress(
                _usdtRebalancerPool,
                _usdcRebalancerPool,
                _daiRebalancerPool
            );
        }
        if (useAave) {
            revert Errors.ChangePool(useAave);
        }

        bytes memory data = abi.encodeWithSignature(
            "executeChangePoolsAddress(address,address,address)",
            _usdtRebalancerPool,
            _usdcRebalancerPool,
            _daiRebalancerPool
        );
        createTransaction(data);
    }

    /**
     * @notice Changes the percentage of liquidity to be sent to pools.
     * @param newPercentLiquidity The new percentage of liquidity to send.
     */
    function changePercentLiquidity(
        uint256 newPercentLiquidity
    ) external onlyOwner {
        if (newPercentLiquidity > 100 || newPercentLiquidity < 0) {
            revert Errors.InvalidPercentLiquidity(newPercentLiquidity);
        }

        bytes memory data = abi.encodeWithSignature(
            "executeChangePercentLiquidity(uint256)",
            newPercentLiquidity
        );
        createTransaction(data);
    }

    /**
     * @notice Switches between using a rebalancer or Aave for liquidity management.
     * @param newUseAave The new status of the useAave flag.
     */
    function changeBalancerToAave(bool newUseAave) external onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "executeChangeBalancerToAaae(bool)",
            newUseAave
        );
        createTransaction(data);
    }

    /**
     * @notice Changes the addresses of the Aave pool and supported tokens.
     * @dev This function can only be executed if useAave is set to true.
     * @param _pool The new address of the Aave pool.
     * @param _incentives The new address of the Aave incentives contract.
     * @param _usdt The new address of the USDT token.
     * @param _usdc The new address of the USDC token.
     * @param _dai The new address of the DAI token.
     */
    function changeAavePoolAndTokens(
        address _pool,
        address _incentives,
        address _usdt,
        address _usdc,
        address _dai
    ) external onlyOwner {
        if (
            _pool == address(0) ||
            _usdt == address(0) ||
            _usdc == address(0) ||
            _dai == address(0)
        ) {
            revert Errors.InvalidPoolsAddress(_usdt, _usdc, _dai);
        }
        if (!useAave) {
            revert Errors.ChangePool(useAave);
        }

        bytes memory data = abi.encodeWithSignature(
            "executeChangeAavePoolAndTokens(address,address,address,address,address)",
            _pool,
            _incentives,
            _usdt,
            _usdc,
            _dai
        );
        createTransaction(data);
    }

    /**
     * @notice Withdraws rewards from the contract to a specified address.
     * @param rewards The address of the reward token to withdraw.
     * @param to The address to receive the rewards.
     */
    function withdrawRewards(address rewards, address to) external onlyOwner {
        isERC20(rewards);

        if (to == address(0)) {
            revert Errors.InvalidAddress();
        }

        bytes memory data = abi.encodeWithSignature(
            "executeWithdrawRewards(address,address)",
            rewards,
            to
        );
        createTransaction(data);
    }

    // Execute functions

    /**
     * @notice Executes the change of target percentages for USDT, USDC, and DAI.
     * @param _usdtPercentage The new target percentage for USDT.
     * @param _usdcPercentage The new target percentage for USDC.
     * @param _daiPercentage The new target percentage for DAI.
     */
    function executeSetTargetPercentage(
        uint256 _usdtPercentage,
        uint256 _usdcPercentage,
        uint256 _daiPercentage
    ) external onlyExecutable {
        targetPercentage.usdt = _usdtPercentage;
        targetPercentage.usdc = _usdcPercentage;
        targetPercentage.dai = _daiPercentage;

        emit Events.TargetPercentageChanged(
            _usdtPercentage,
            _usdcPercentage,
            _daiPercentage
        );
    }

    /**
     * @notice Executes the retrieval of all liquidity from the pools.
     * @param usdtPoolTokens The amount of USDT pool tokens to withdraw.
     * @param usdcPoolTokens The amount of USDC pool tokens to withdraw.
     * @param daiPoolTokens The amount of DAI pool tokens to withdraw.
     */
    function executeGetAllLiquidity(
        uint256 usdtPoolTokens,
        uint256 usdcPoolTokens,
        uint256 daiPoolTokens
    ) public onlyExecutable {
        if (!useAave) {
            IRebalancer(rebalancerPools.usdtPool).withdraw(
                usdtPoolTokens,
                address(this),
                address(this)
            );
            IRebalancer(rebalancerPools.usdcPool).withdraw(
                usdcPoolTokens,
                address(this),
                address(this)
            );
            IRebalancer(rebalancerPools.daiPool).withdraw(
                daiPoolTokens,
                address(this),
                address(this)
            );
        } else {
            _claimAllRewardsAave();

            IPool(aavePools.pool).withdraw(
                Addresses.USDT_ARB,
                usdtPoolTokens,
                address(this)
            );
            IPool(aavePools.pool).withdraw(
                Addresses.USDC_ARB,
                usdcPoolTokens,
                address(this)
            );
            IPool(aavePools.pool).withdraw(
                Addresses.DAI_ARB,
                daiPoolTokens,
                address(this)
            );
        }
    }

    /**
     * @notice Executes the change of the sendLiquidity flag.
     * @param newSendLiquidity The new status of the sendLiquidity flag.
     */
    function executeChangeSendLiquidity(bool newSendLiquidity) external onlyExecutable {
        sendLiquidity = newSendLiquidity;
    }

    /**
     * @notice Executes the change of rebalancer pool addresses.
     * @param _usdtRebalancerPool The new address of the USDT rebalancer pool.
     * @param _usdcRebalancerPool The new address of the USDC rebalancer pool.
     * @param _daiRebalancerPool The new address of the DAI rebalancer pool.
     */
    function executeChangePoolsAddress(
        address _usdtRebalancerPool,
        address _usdcRebalancerPool,
        address _daiRebalancerPool
    ) external onlyExecutable {
        (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        ) = checkBalancerTokenBalances();

        executeGetAllLiquidity(usdtPoolToken, usdcPoolToken, daiPoolToken);

        rebalancerPools.usdtPool = _usdtRebalancerPool;
        rebalancerPools.usdcPool = _usdcRebalancerPool;
        rebalancerPools.daiPool = _daiRebalancerPool;

        emit Events.PoolAddressesChanged(
            _usdtRebalancerPool,
            _usdcRebalancerPool,
            _daiRebalancerPool
        );
    }

    /**
     * @notice Executes the change of the percentLiquidity value.
     * @param newPercentLiquidity The new percentage of liquidity to send to pools.
     */
    function executeChangePercentLiquidity(
        uint256 newPercentLiquidity
    ) external onlyExecutable {
        percentLiquidity = newPercentLiquidity;

        emit Events.LiquidityPercentageChanged(newPercentLiquidity);
    }

    /**
     * @notice Executes the change of the useAave flag.
     * @param newUseAave The new status of the useAave flag.
     */
    function executeChangeBalancerToAaae(
        bool newUseAave
    ) external onlyExecutable {
        useAave = newUseAave;
    }

    /**
     * @notice Executes the change of Aave pool and token addresses.
     * @param _pool The new address of the Aave pool.
     * @param _incentives The new address of the Aave incentives contract.
     * @param _usdt The new address of the USDT token.
     * @param _usdc The new address of the USDC token.
     * @param _dai The new address of the DAI token.
     */
    function executeChangeAavePoolAndTokens(
        address _pool,
        address _incentives,
        address _usdt,
        address _usdc,
        address _dai
    ) external onlyExecutable {
        (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        ) = checkBalancerTokenBalances();

        executeGetAllLiquidity(usdtPoolToken, usdcPoolToken, daiPoolToken);

        aavePools.pool = _pool;
        aavePools.incentives = _incentives;
        aavePools.usdt = _usdt;
        aavePools.usdc = _usdc;
        aavePools.dai = _dai;

        emit Events.AaveSettingsChanged(_pool, _incentives, _usdt, _usdc, _dai);
    }

    /**
     * @notice Executes the withdrawal of rewards to a specified address.
     * @param rewards The address of the reward token to withdraw.
     * @param to The address to receive the rewards.
     */
    function executeWithdrawRewards(address rewards, address to) external onlyExecutable {
        IERC20 sellToken = IERC20(rewards);

        uint256 balance = sellToken.balanceOf(address(this));
        if (balance == 0) {
            revert Errors.InsufficientBalance(balance, balance, msg.sender);
        }

        TransferHelper.safeTransferFrom(rewards, address(this), to, balance);

        emit Events.RewardsWithdrawn(rewards, to, balance);
    }
}

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

contract StalwartLiquidity is MultiSigStalwart {
    bool public sendLiquidity;
    bool public useAave;

    uint256 public percentLiquidity;

    struct TargetPercentage {
        uint256 usdt;
        uint256 usdc;
        uint256 dai;
    }
    TargetPercentage public targetPercentage;

    struct RebalancerPools {
        address usdtPool;
        address usdcPool;
        address daiPool;
    }
    RebalancerPools public rebalancerPools;

    struct AavePools {
        address pool;
        address incentives;
        address usdt;
        address usdc;
        address dai;
    }
    AavePools public aavePools;

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

    function _sendToPool(address pool, uint256 amount) internal {
        IRebalancer(pool).deposit(amount, address(this));
    }

    function _sendToPoolAave(address stable, uint256 amount) internal {
        IPool(aavePools.pool).supply(stable, amount, address(this), 0);
    }

    function _getFromPool(
        address pool,
        uint256 amount,
        address stable
    ) internal {
        if (!useAave) {
            IRebalancer(pool).withdraw(amount, address(this), address(this));
        } else {
            address[] memory assets;
            assets[0] = stable;

            IIncentives(aavePools.incentives).claimAllRewards(
                assets,
                address(this)
            );
            IPool(aavePools.pool).withdraw(stable, amount, address(this));
        }
    }

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

    function executeSetTargetPercentage(
        uint256 _usdtPercentage,
        uint256 _usdcPercentage,
        uint256 _daiPercentage
    ) internal {
        targetPercentage.usdt = _usdtPercentage;
        targetPercentage.usdc = _usdcPercentage;
        targetPercentage.dai = _daiPercentage;
    }

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

    function executeGetAllLiquidity(
        uint256 usdtPoolTokens,
        uint256 usdcPoolTokens,
        uint256 daiPoolTokens
    ) internal {
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

    function changeSendLiquidity(bool newSendLiquidity) external onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "executeChangeSendLiquidity(bool)",
            newSendLiquidity
        );
        createTransaction(data);
    }

    function executeChangeSendLiquidity(bool newSendLiquidity) internal {
        sendLiquidity = newSendLiquidity;
    }

    // work if useAave = false
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

    function executeChangePoolsAddress(
        address _usdtRebalancerPool,
        address _usdcRebalancerPool,
        address _daiRebalancerPool
    ) internal {
        (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        ) = checkBalancerTokenBalances();

        executeGetAllLiquidity(usdtPoolToken, usdcPoolToken, daiPoolToken);

        rebalancerPools.usdtPool = _usdtRebalancerPool;
        rebalancerPools.usdcPool = _usdcRebalancerPool;
        rebalancerPools.daiPool = _daiRebalancerPool;
    }

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

    function executeChangePercentLiquidity(
        uint256 newPercentLiquidity
    ) internal {
        percentLiquidity = newPercentLiquidity;
    }

    function changeBalancerToAave(bool newUseAave) external onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "executeChangeBalancerToAaae(bool)",
            newUseAave
        );
        createTransaction(data);
    }

    function executeChangeBalancerToAaae(bool newUseAave) internal {
        useAave = newUseAave;
    }

    // work if useAave = true
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

    function executeChangeAavePoolAndTokens(
        address _pool,
        address _incentives,
        address _usdt,
        address _usdc,
        address _dai
    ) internal {
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
    }

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

    function executeWithdrawRewards(address rewards, address to) internal {
        IERC20 sellToken = IERC20(rewards);

        uint256 balance = sellToken.balanceOf(address(this));
        if (balance == 0) {
            revert Errors.InsufficientBalance(balance, balance, msg.sender);
        }

        TransferHelper.safeTransferFrom(rewards, address(this), to, balance);
    }

    function isERC20(address _token) internal view {
        (bool success, bytes memory data) = _token.staticcall(
            abi.encodeWithSignature("totalSupply()")
        );

        if (success && data.length == 0) {
            revert Errors.InvalidERC20Token(_token);
        }
    }
}

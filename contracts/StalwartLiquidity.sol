// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
// TODO: 1) разобраться с контрактами ребалансера
// 2) сделать смену пулов на aave
// 3) сделать ребалансировку
// 4) добавить нули, так как usdt и usdc с 6 нулями, а не с 18
// 5) поменять где нужно на aave функции
// 6) сделать обмен наград arb или вывод при клейме наград

import {MultiSigStalwart} from "./MultiSig.sol";
import {IRebalancer} from "./interfaces/IRebalancer.sol";
import {IPool} from "@aave/core-v3/contracts/interfaces/IPool.sol";
import {IIncentives} from "./interfaces/IIncentives.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Errors} from "./libraries/Errors.sol";

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
        uint256 _percentLiquidity = 50;
        uint256 _usdtPercentage = 70;
        uint256 _usdcPercentage = 20;
        uint256 _daiPercentage = 10;

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
            0xCF86c768E5b8bcc823aC1D825F56f37c533d32F9,
            0x6eAFd6Ae0B766BAd90e9226627285685b2d702aB,
            0x5A0F7b7Ea13eDee7AD76744c5A6b92163e51a99a
        );

        aavePools = AavePools(
            0x794a61358D6845594F94dc1DB02A252b5b4814aD,
            0x929EC64c34a17401F460460D4B9390518E5B473e,
            0x6ab707Aca953eDAeFBc4fD23bA73294241490620,
            0x724dc807b04555b71ed48a6896b6F41593b8C637,
            0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE
        );

        if (_percentLiquidity > 100) {
            revert Errors.InvalidPercentLiquidity(_percentLiquidity);
        }
        percentLiquidity = _percentLiquidity;

        sendLiquidity = true;
        useAave = false;
    }

    function _sendToPool(
        address pool,
        uint256 amount,
        address stable
    ) internal {
        if (!useAave) {
            IRebalancer(pool).deposit(amount, address(this));
        } else {
            IPool(aavePools.pool).supply(stable, amount, address(this), 0);
        }
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

    function checkBalancerTokenBalances(
        bool isRebalancer
    )
        public
        view
        returns (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        )
    {
        if (isRebalancer) {
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

    function getAllLiquidity(bool isRebalancer) external onlyOwner {
        (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        ) = checkBalancerTokenBalances(isRebalancer);

        bytes memory data = abi.encodeWithSignature(
            "executeGetAllLiquidity(uint256,uint256,uint256,bool)",
            usdtPoolToken,
            usdcPoolToken,
            daiPoolToken,
            isRebalancer
        );
        createTransaction(data);
    }

    function executeGetAllLiquidity(
        uint256 usdtPoolTokens,
        uint256 usdcPoolTokens,
        uint256 daiPoolTokens,
        bool isRebalancer
    ) internal {
        if (isRebalancer) {
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
                aavePools.usdt,
                usdtPoolTokens,
                address(this)
            );
            IPool(aavePools.pool).withdraw(
                aavePools.usdc,
                usdcPoolTokens,
                address(this)
            );
            IPool(aavePools.pool).withdraw(
                aavePools.dai,
                daiPoolTokens,
                address(this)
            );
        }
    }

    function _claimAllRewardsAave() internal {
        address[] memory assets;

        assets[0] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
        assets[1] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
        assets[2] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

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
        ) = checkBalancerTokenBalances(true);

        executeGetAllLiquidity(
            usdtPoolToken,
            usdcPoolToken,
            daiPoolToken,
            true
        );

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
        ) = checkBalancerTokenBalances(false);

        executeGetAllLiquidity(
            usdtPoolToken,
            usdcPoolToken,
            daiPoolToken,
            false
        );

        aavePools.pool = _pool;
        aavePools.incentives = _incentives;
        aavePools.usdt = _usdt;
        aavePools.usdc = _usdc;
        aavePools.dai = _dai;
    }
}

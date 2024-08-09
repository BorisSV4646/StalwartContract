// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MultiSigStalwart} from "./MultiSig.sol";
import {IRebalancer} from "./interfaces/IRebalancer.sol";

contract StalwartLiquidity is MultiSigStalwart {
    bool public sendLiquidity = true;

    uint256 public usdtTargetPercentage;
    uint256 public usdcTargetPercentage;
    uint256 public daiTargetPercentage;

    address public usdtRebalancerPool;
    address public usdcRebalancerPool;
    address public daiRebalancerPool;

    error InvalidPercentage(uint256 percents);
    error InvalidPoolsAddress(
        address usdtPool,
        address usdcPool,
        address daiPool
    );

    constructor(
        address _usdtRebalancerPool,
        address _usdcRebalancerPool,
        address _daiRebalancerPool,
        uint256 _usdtPercentage,
        uint256 _usdcPercentage,
        uint256 _daiPercentage
    ) {
        if (
            _usdtRebalancerPool == address(0) ||
            _usdcRebalancerPool == address(0) ||
            _daiRebalancerPool == address(0)
        ) {
            revert InvalidPoolsAddress(
                _usdtRebalancerPool,
                _usdcRebalancerPool,
                _daiRebalancerPool
            );
        }
        usdtRebalancerPool = _usdtRebalancerPool;
        usdcRebalancerPool = _usdcRebalancerPool;
        daiRebalancerPool = _daiRebalancerPool;

        uint256 percents = _usdtPercentage + _usdcPercentage + _daiPercentage;

        if (percents != 100) {
            revert InvalidPercentage(percents);
        }
        usdtTargetPercentage = _usdtPercentage;
        usdcTargetPercentage = _usdcPercentage;
        daiTargetPercentage = _daiPercentage;
    }

    function sendToPool() internal {}

    function getFromPool() internal {}

    // TODO: разобраться с контрактами ребалансера
    function setUsdtTargetPercentage(
        uint256 _usdtPercentage,
        uint256 _usdcPercentage,
        uint256 _daiPercentage
    ) external onlyOwner {
        uint256 percents = _usdtPercentage + _usdcPercentage + _daiPercentage;

        if (percents != 100) {
            revert InvalidPercentage(percents);
        }

        bytes memory data = abi.encodeWithSignature(
            "executeSetUsdtTargetPercentage(uint256,uint256,uint256)",
            _usdtPercentage,
            _usdcPercentage,
            _daiPercentage
        );
        createTransaction(data);
    }

    function executeSetUsdtTargetPercentage(
        uint256 _usdtPercentage,
        uint256 _usdcPercentage,
        uint256 _daiPercentage
    ) internal {
        usdtTargetPercentage = _usdtPercentage;
        usdcTargetPercentage = _usdcPercentage;
        daiTargetPercentage = _daiPercentage;
    }

    function rebalancer() external onlyOwner {
        bytes memory data = abi.encodeWithSignature("executeRebalancer()");
        createTransaction(data);
    }

    function executeRebalancer() internal {
        // Реализация функции ребалансировки
    }

    function changeBalancerToAaave() external onlyOwner {
        bytes memory data = abi.encodeWithSignature(
            "executeChangeBalancerToAaave()"
        );
        createTransaction(data);
    }

    function executeChangeBalancerToAaave() internal {
        // Реализация функции изменения баланса на Aave
    }

    function getAllLiquidity() external onlyOwner {
        bytes memory data = abi.encodeWithSignature("executeGetAllLiquidity()");
        createTransaction(data);
    }

    function executeGetAllLiquidity() internal {
        // Реализация функции получения всей ликвидности
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
            revert InvalidPoolsAddress(
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
        usdtRebalancerPool = _usdtRebalancerPool;
        usdcRebalancerPool = _usdcRebalancerPool;
        daiRebalancerPool = _daiRebalancerPool;
    }
}

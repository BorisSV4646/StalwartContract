// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
// TODO: 1) разобраться с контрактами ребалансера 2) сделать смену пулов на aave 3) сделать ребалансировку

import {MultiSigStalwart} from "./MultiSig.sol";
import {IRebalancer} from "./interfaces/IRebalancer.sol";

contract StalwartLiquidity is MultiSigStalwart {
    bool public sendLiquidity;

    uint256 public percentLiquidity;

    uint256 public usdtTargetPercentage;
    uint256 public usdcTargetPercentage;
    uint256 public daiTargetPercentage;

    address public usdtRebalancerPool;
    address public usdcRebalancerPool;
    address public daiRebalancerPool;

    error InvalidPercentage(uint256 percents);
    error InvalidPercentLiquidity(uint256 newPercentLiquidity);
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

        sendLiquidity = true;
        percentLiquidity = 50;
    }

    function _sendToPool(address pool, uint256 amount) internal {
        IRebalancer(pool).deposit(amount, address(this));
    }

    function _getFromPool(address pool, uint256 amount) internal {
        IRebalancer(pool).withdraw(amount, address(this), address(this));
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
        usdtPoolToken = IRebalancer(usdtRebalancerPool).balanceOf(
            address(this)
        );
        usdcPoolToken = IRebalancer(usdcRebalancerPool).balanceOf(
            address(this)
        );
        daiPoolToken = IRebalancer(daiRebalancerPool).balanceOf(address(this));
    }

    function setTargetPercentage(
        uint256 _usdtPercentage,
        uint256 _usdcPercentage,
        uint256 _daiPercentage
    ) external onlyOwner {
        uint256 percents = _usdtPercentage + _usdcPercentage + _daiPercentage;

        if (percents != 100) {
            revert InvalidPercentage(percents);
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
        usdtTargetPercentage = _usdtPercentage;
        usdcTargetPercentage = _usdcPercentage;
        daiTargetPercentage = _daiPercentage;
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
        IRebalancer(usdtRebalancerPool).withdraw(
            usdtPoolTokens,
            address(this),
            address(this)
        );
        IRebalancer(usdcRebalancerPool).withdraw(
            usdcPoolTokens,
            address(this),
            address(this)
        );
        IRebalancer(daiRebalancerPool).withdraw(
            daiPoolTokens,
            address(this),
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
        (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        ) = checkBalancerTokenBalances();

        executeGetAllLiquidity(usdtPoolToken, usdcPoolToken, daiPoolToken);

        usdtRebalancerPool = _usdtRebalancerPool;
        usdcRebalancerPool = _usdcRebalancerPool;
        daiRebalancerPool = _daiRebalancerPool;
    }

    function changePercentLiquidity(
        uint256 newPercentLiquidity
    ) external onlyOwner {
        if (newPercentLiquidity > 100 || newPercentLiquidity < 0) {
            revert InvalidPercentLiquidity(newPercentLiquidity);
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
}

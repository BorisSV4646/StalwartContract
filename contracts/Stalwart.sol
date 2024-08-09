// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "hardhat/console.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SwapUniswap, ISwapRouter, IQuoterV2, IUniswapV3Factory, TransferHelper} from "./SwapUniswap.sol";
import {IWETH} from "./interfaces/IWETH.sol";
import {StalwartLiquidity} from "./StalwartLiquidity.sol";

contract Stalwart is StalwartLiquidity, SwapUniswap, ERC20 {
    error InvalidStableType();
    error InvalidPoolType();
    error InvalidPoolAddress();
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
    error InsufficientStableBalance(uint256 stableBalance, uint256 amount);

    struct RebalancerPools {
        address usdtRebalancerPool;
        address usdcRebalancerPool;
        address daiRebalancerPool;
    }
    struct TokensSwap {
        address usdt;
        address usdc;
        address dai;
        address weth;
    }
    struct StablePercent {
        uint256 usdtPercentage;
        uint256 usdcPercentage;
        uint256 daiPercentage;
    }

    constructor(
        address[] memory _owners,
        uint256 _requiredSignatures,
        ISwapRouter _swapRouter,
        IQuoterV2 _quoterv2,
        IUniswapV3Factory _uniswapV3Factory,
        TokensSwap memory _tokenswap,
        RebalancerPools memory _rebalancerPools,
        StablePercent memory _stablePercent
    )
        ERC20("Stalwart", "STL")
        SwapUniswap(
            _swapRouter,
            _quoterv2,
            _uniswapV3Factory,
            _tokenswap.dai,
            _tokenswap.usdt,
            _tokenswap.usdc,
            _tokenswap.weth
        )
        StalwartLiquidity(
            _rebalancerPools.usdtRebalancerPool,
            _rebalancerPools.usdcRebalancerPool,
            _rebalancerPools.daiRebalancerPool,
            _stablePercent.usdtPercentage,
            _stablePercent.usdcPercentage,
            _stablePercent.daiPercentage
        )
    {
        _initializeOwners(_owners, _requiredSignatures);
    }

    function _initializeOwners(
        address[] memory _owners,
        uint256 _requiredSignatures
    ) internal {
        if (_owners.length == 0) {
            revert OwnersRequire(_owners.length);
        }
        if (_requiredSignatures <= 2 || _requiredSignatures > _owners.length) {
            revert InvalidNumberSignatures(_requiredSignatures, _owners.length);
        }
        owners = _owners;
        requiredSignatures = _requiredSignatures;
    }

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
            TransferHelper.safeApprove(
                stableAddress,
                poolAddress,
                amountLiquidity
            );
            _sendToPool(poolAddress, amountLiquidity);
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
            TransferHelper.safeApprove(
                needStable,
                poolAddress,
                amountLiquidity
            );
            _sendToPool(poolAddress, amountLiquidity);
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
            TransferHelper.safeApprove(
                needStable,
                poolAddress,
                amountLiquidity
            );
            _sendToPool(poolAddress, amountLiquidity);
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
            _getFromPool(poolAddress, amount);
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
        (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        ) = checkBalancerTokenBalances();

        uint256 totalBalance = (usdtBalance +
            usdcBalance +
            daiBalance +
            usdtPoolToken +
            usdcPoolToken +
            daiPoolToken) / 10 ** 18;

        uint256 targetUSDT = (totalBalance * usdtTargetPercentage) / 100;
        uint256 targetUSDC = (totalBalance * usdcTargetPercentage) / 100;
        uint256 targetDAI = (totalBalance * daiTargetPercentage) / 100;

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
        int256 deviationA = int256(usdtTargetPercentage) - int256(targetUSDT);
        int256 deviationB = int256(usdcTargetPercentage) - int256(targetUSDC);
        int256 deviationC = int256(daiTargetPercentage) - int256(targetDAI);

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
        int256 deviationA = int256(usdtTargetPercentage) - int256(targetUSDT);
        int256 deviationB = int256(usdcTargetPercentage) - int256(targetUSDC);
        int256 deviationC = int256(daiTargetPercentage) - int256(targetDAI);

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

    function getPoolAddress(
        StableType typeStable
    ) internal view returns (address) {
        if (typeStable == StableType.DAI) {
            return daiRebalancerPool;
        } else if (typeStable == StableType.USDT) {
            return usdtRebalancerPool;
        } else if (typeStable == StableType.USDC) {
            return usdcRebalancerPool;
        } else {
            revert InvalidPoolType();
        }
    }

    function getPoolAddress(
        address stableAddress
    ) internal view returns (address) {
        if (stableAddress == DAI) {
            return daiRebalancerPool;
        } else if (stableAddress == USDT) {
            return usdtRebalancerPool;
        } else if (stableAddress == USDC) {
            return usdcRebalancerPool;
        } else {
            revert InvalidPoolAddress();
        }
    }

    function rebalancer() external onlyOwner {
        bytes memory data = abi.encodeWithSignature("executeRebalancer()");
        createTransaction(data);
    }

    function executeRebalancer() internal {
        (
            uint256 usdtPoolToken,
            uint256 usdcPoolToken,
            uint256 daiPoolToken
        ) = checkBalancerTokenBalances();
        (
            uint256 usdtBalance,
            uint256 usdcBalance,
            uint256 daiBalance
        ) = getAllBalances();

        rebalanceTokenPool(usdtBalance, usdtPoolToken, usdtRebalancerPool);
        rebalanceTokenPool(usdcBalance, usdcPoolToken, usdcRebalancerPool);
        rebalanceTokenPool(daiBalance, daiPoolToken, daiRebalancerPool);
    }

    // пока только ребалансирует активы между пулом и контрактом,
    // не делает ребалансировку в процентах между токенами, так как
    // тогда опять меняется соотношение с токенами в пулах
    function rebalanceTokenPool(
        uint256 tokenBalance,
        uint256 poolTokenBalance,
        address rebalancerPool
    ) internal {
        uint256 totalBalance = tokenBalance + poolTokenBalance;
        uint256 targetBalance = (totalBalance * percentLiquidity) / 100;

        if (targetBalance < percentLiquidity) {
            uint256 needAmount = poolTokenBalance - (totalBalance / 2);
            _getFromPool(rebalancerPool, needAmount);
        } else {
            uint256 needAmount = tokenBalance - (totalBalance / 2);
            _sendToPool(rebalancerPool, needAmount);
        }
    }
}

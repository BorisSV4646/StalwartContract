// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./MultiSig.sol";
import "./SwapUniswap.sol";
import "./IWETH.sol";
import "./StalwartLiquidity.sol";

contract Stalwart is StalwartLiquidity, ERC20, MultiSigStalwart, SwapUniswap {
    error InvalidStableType();
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

    constructor(
        address[] memory _owners,
        uint _requiredSignatures,
        ISwapRouter _swapRouter,
        IQuoterV2 _quoterv2,
        IUniswapV3Factory _uniswapV3Factory,
        address _dai,
        address _usdt,
        address _usdc,
        address _weth,
        address _usdtRebalancerPool,
        address _usdcRebalancerPool,
        address _daiRebalancerPool
    )
        ERC20("Stalwart", "STL")
        MultiSigStalwart(_owners, _requiredSignatures)
        SwapUniswap(
            _swapRouter,
            _quoterv2,
            _uniswapV3Factory,
            _dai,
            _usdt,
            _usdc,
            _weth
        )
        StalwartLiquidity(
            _usdtRebalancerPool,
            _usdcRebalancerPool,
            _daiRebalancerPool
        )
    {}

    // need to get approve
    // need give 50% to aave pools
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

        _mint(msg.sender, amount);
    }

    // need to get approve
    // need give 50% to aave pools
    function buyStalwartForToken(uint256 amount, address token) external {
        isERC20(token);

        checkAllowanceAndBalance(msg.sender, token, amount);

        address needStable = checkStableBalance(false);
        uint256 swapAmount = swapExactInputSingle(amount, token, needStable);

        _mint(msg.sender, swapAmount);
    }

    // need give 50% to aave pools
    function buyStalwartForEth() external payable {
        uint256 amount = msg.value;
        IWETH(WETH).deposit{value: amount}();

        address needStable = checkStableBalance(false);
        uint256 swapAmount = swapExactInputSingle(amount, WETH, needStable);

        _mint(msg.sender, swapAmount);
    }

    // need give 50% to aave pools
    function soldStalwart(uint256 amount) external {
        checkAllowanceAndBalance(msg.sender, address(this), amount);

        _burn(msg.sender, amount);

        address needStable = checkStableBalance(true);

        IERC20 stableToken = IERC20(needStable);
        uint256 stableBalance = stableToken.balanceOf(address(this));
        if (stableBalance < amount) {
            revert InsufficientStableBalance(stableBalance, amount);
        }

        TransferHelper.safeTransferFrom(
            needStable,
            address(this),
            msg.sender,
            amount
        );
    }

    function sendToPool() internal {}

    function getFromPool() internal {}

    function checkStableBalance(
        bool getMaxDeviation
    ) internal view returns (address) {
        IERC20 usdt = IERC20(USDT);
        IERC20 usdc = IERC20(USDC);
        IERC20 dai = IERC20(DAI);

        uint256 balanceUSDT = usdt.balanceOf(address(this));
        uint256 balanceUSDC = usdc.balanceOf(address(this));
        uint256 balanceDAI = dai.balanceOf(address(this));

        uint256 totalBalance = (balanceUSDT + balanceUSDC + balanceDAI) /
            10 ** 18;

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

    function showRecieveStable() external view returns (address needStable) {
        needStable = checkStableBalance(true);
    }
}

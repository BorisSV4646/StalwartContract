// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {IQuoterV2} from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";
import {IUniswapV3Factory} from "../interfaces/IUniswapPool.sol";

/**
 * @title Addresses library
 * @notice Contains constant addresses used throughout the Stalwart protocol
 */
library Addresses {
    // AAVE

    /**
     * @dev Address of the Aave Pool contract.
     */
    address public constant AAVE_POOL =
        0x794a61358D6845594F94dc1DB02A252b5b4814aD;

    /**
     * @dev Address of the Aave Incentives contract.
     */
    address public constant AAVE_INCENTIVES =
        0x929EC64c34a17401F460460D4B9390518E5B473e;

    /**
     * @dev Address of the Aave USDT token.
     */
    address public constant AAVE_USDT =
        0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    /**
     * @dev Address of the Aave USDC token.
     */
    address public constant AAVE_USDC =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /**
     * @dev Address of the Aave DAI token.
     */
    address public constant AAVE_DAI =
        0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    // REBALANCER

    /**
     * @dev Address of the USDT pool in the rebalancer contract.
     */
    address public constant REB_USDT_POOL =
        0xCF86c768E5b8bcc823aC1D825F56f37c533d32F9;

    /**
     * @dev Address of the USDC pool in the rebalancer contract.
     */
    address public constant REB_USDC_POOL =
        0x6eAFd6Ae0B766BAd90e9226627285685b2d702aB;

    /**
     * @dev Address of the DAI pool in the rebalancer contract.
     */
    address public constant REB_DAI_POOL =
        0x5A0F7b7Ea13eDee7AD76744c5A6b92163e51a99a;

    // UNISWAP

    /**
     * @dev Address of the Uniswap V3 Swap Router contract.
     */
    ISwapRouter public constant SWAP_ROUTER =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    /**
     * @dev Address of the Uniswap V3 QuoterV2 contract.
     */
    IQuoterV2 public constant QUOTERV2 =
        IQuoterV2(0x61fFE014bA17989E743c5F6cB21bF9697530B21e);

    /**
     * @dev Address of the Uniswap V3 Factory contract.
     */
    IUniswapV3Factory public constant UNISWAP_V3_FACTORY =
        IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    // TOKENS

    /**
     * @dev Address of the USDT token on Arbitrum.
     */
    address public constant USDT_ARB =
        0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    /**
     * @dev Address of the USDC token on Arbitrum.
     */
    address public constant USDC_ARB =
        0xaf88d065e77c8cC2239327C5EDb3A432268e5831;

    /**
     * @dev Address of the DAI token on Arbitrum.
     */
    address public constant DAI_ARB =
        0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1;

    /**
     * @dev Address of the WETH token on Arbitrum.
     */
    address public constant WETH_ARB =
        0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
}

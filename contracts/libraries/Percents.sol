// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title Percents library
 * @notice Contains constants representing percentages used for liquidity distribution in the Stalwart protocol
 */
library Percents {
    // LIQUIDITY

    /**
     * @dev Percentage of total funds allocated to liquidity.
     * This constant defines the percentage of the total funds that should be allocated to liquidity.
     */
    uint256 public constant PERCENT_LIQUIDITY = 50;

    /**
     * @dev Percentage of USDT in the liquidity pool.
     * This constant defines the percentage of the liquidity that should be allocated to USDT.
     */
    uint256 public constant USDT_PERCENT = 70;

    /**
     * @dev Percentage of USDC in the liquidity pool.
     * This constant defines the percentage of the liquidity that should be allocated to USDC.
     */
    uint256 public constant USDC_PERCENT = 20;

    /**
     * @dev Percentage of DAI in the liquidity pool.
     * This constant defines the percentage of the liquidity that should be allocated to DAI.
     */
    uint256 public constant DAI_PERCENT = 10;

    /**
     * @dev Represents the scaling factor for tokens with 6 decimals.
     * This constant is used to convert values between tokens with 6 decimals
     * and tokens with 18 decimals by scaling the amount up or down by 10^12.
     */
    uint256 public constant SMALL_DECIMALS = 10 ** 12;
}

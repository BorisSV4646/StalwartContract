// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IIncentives {
    function claimAllRewards(
        address[] memory assets,
        address receiver
    ) external;

    function claimRewards(
        address[] memory assets,
        uint256 amount,
        address to,
        address reward
    ) external;
}

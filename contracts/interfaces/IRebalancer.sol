// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRebalancer {
    function deposit(
        uint256 assets,
        address receiver
    ) external returns (uint256 shares);

    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) external returns (uint256 shares);

    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) external returns (uint256 assets);

    function previewWithdraw(
        uint256 assets
    ) external view returns (uint256 shares);

    function balanceOf(address account) external view returns (uint256);
}

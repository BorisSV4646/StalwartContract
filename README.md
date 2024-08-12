# StalwartContract

This repository contains the smart contracts for the Stalwart project. These contracts are written in Solidity and are designed to handle liquidity management, token supply, and integration with Aave on the Ethereum and Arbitrum networks.

## Table of Contents

- [Overview](#overview)
- [Contracts](#contracts)
- [Deployment](#deployment)
- [Usage](#usage)
- [Testing](#testing)
- [Security](#security)
- [License](#license)

## Overview

The `StalwartContract` repository is the core of the Stalwart project, providing functionalities for managing liquidity, interacting with Aave pools, and handling token supply operations. The main contracts include functionalities for supplying tokens, checking balances, and interacting with various DeFi protocols.

## Contracts

### Main Contracts

- **StalwartLiquidity.sol**: This contract handles the liquidity management logic, including interactions with Aave pools and rebalancing liquidity between different pools.
- **MultiSigStalwart.sol**: A multisignature wallet implementation to manage contract operations securely.
- **SwapUniswap.sol**: This contract integrates with Uniswap to handle token swaps, providing liquidity management through swaps.

### Interfaces

- **IRebalancer.sol**: Interface for rebalancer contracts used to manage liquidity across different pools.
- **IWETH.sol**: Interface for the Wrapped Ether (WETH) contract.

## Deployment

To deploy the contracts, you can use Hardhat or Truffle. Make sure you have the required environment variables set up:

```bash
# Example .env file
INFURA_API_KEY=your_infura_key
MNEMONIC=your_mnemonic
```

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MultisigToken is ERC20 {
    constructor(address tokenReciever) ERC20("MultisigToken", "MT") {
        _mint(tokenReciever, 2501000000 ether);
    }
}

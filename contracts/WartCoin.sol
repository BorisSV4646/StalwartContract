// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StalwartToken is ERC20 {
    address public immutable SENDER;

    error NotSender(address sender);
    error InvalidLenghtTokens(uint256 tokenReceivers, uint256 amounts);

    constructor(address _sender) ERC20("Stalwart", "WART") {
        SENDER = _sender;
        _mint(address(this), 400000000 ether);
    }

    modifier onlySender() {
        if (SENDER != msg.sender) {
            revert NotSender(msg.sender);
        }
        _;
    }

    /**
     * To transfer tokens from Contract to the
     * provided list of token receivers with respective amount
     *
     * Requirements:
     *
     * - `tokenReceivers` cannot include the zero address.
     */
    //
    function batchTransfer(
        address[] calldata tokenReceivers,
        uint256[] calldata amounts
    ) external onlySender {
        if (tokenReceivers.length != amounts.length) {
            revert InvalidLenghtTokens(tokenReceivers.length, amounts.length);
        }

        for (uint256 indx = 0; indx < tokenReceivers.length; indx++) {
            _transfer(address(this), tokenReceivers[indx], amounts[indx]);
        }
    }
}

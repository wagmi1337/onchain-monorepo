// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract WAGMI is ERC20, ERC20Burnable, ERC20Permit {
    constructor() ERC20("WAGMI", "WAGMI") ERC20Permit("WAGMI") {
        _mint(msg.sender, 900000000 * 10 ** decimals());
    }
}

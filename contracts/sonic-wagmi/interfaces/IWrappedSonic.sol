// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IWrappedSonic is IERC20 {
    function depositFor(address account) external payable returns (bool);
}

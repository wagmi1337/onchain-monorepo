// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IFairLaunch} from "./interfaces/IFairLaunch.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "hardhat/console.sol";

contract FairLaunchQuoter {
    function quoteLaunch(
        IFairLaunch fairLaunch,
        IERC20 token
    ) external payable returns (uint256 initialBuyToken, uint256 totalSupply) {
        uint256 size;
        assembly {
            size := extcodesize(token)
        }
        require(size == 0, "Token already launched");

        fairLaunch.fairLaunch{value: msg.value}("", "");

        assembly {
            size := extcodesize(token)
        }
        require(size > 0, "Token not launched");

        initialBuyToken = token.balanceOf(address(this));
        totalSupply = token.totalSupply();
    }
}

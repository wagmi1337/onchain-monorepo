// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IFairLaunch {
    function fairLaunch(
        string memory name,
        string memory symbol
    ) external payable;
}

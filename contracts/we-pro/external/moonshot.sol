// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMoonshotFactory {
    function migrate(address _token) external;

    function buyExactIn(address _token, uint256 _amountOutMin) external payable;

    function sellExactIn(
        address _token,
        uint256 _tokenAmount,
        uint256 _amountCollateralMin
    ) external;
}

interface IMoonshotToken is IERC20 {
    function sendingToPairNotAllowed() external view returns (bool);

    function tradingStopped() external view returns (bool);

    function factory() external view returns (IMoonshotFactory);
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.26;

interface IPool {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function tickSpacing() external returns (int24);

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IFactory {
    function createPool(
        address tokenA,
        address tokenB,
        int24 tickSpacing,
        uint160 sqrtPriceX96
    ) external returns (address pool);

    function getPool(
        address tokenA,
        address tokenB,
        int24 tickSpacing
    ) external returns (address pool);
}

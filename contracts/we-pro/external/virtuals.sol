// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBonding {
    struct Token {
        address creator;
        address token;
        address pair;
        address agentToken;
        Data data;
        string description;
        string image;
        string twitter;
        string telegram;
        string youtube;
        string website;
        bool trading;
        bool tradingOnUniswap;
    }

    struct Data {
        address token;
        string name;
        string _name;
        string ticker;
        uint256 supply;
        uint256 price;
        uint256 marketCap;
        uint256 liquidity;
        uint256 volume;
        uint256 volume24H;
        uint256 prevPrice;
        uint256 lastUpdated;
    }

    function router() external view returns (address);

    function tokenInfo(address) external view returns (Token memory);

    function buy(
        uint256 amountIn,
        address tokenAddress
    ) external payable returns (bool);

    function sell(
        uint256 amountIn,
        address tokenAddress
    ) external returns (bool);

    function unwrapToken(
        address srcTokenAddress,
        address[] memory accounts
    ) external;
}

IBonding constant bonding = IBonding(
    0xF66DeA7b3e897cD44A5a231c61B6B4423d613259
);

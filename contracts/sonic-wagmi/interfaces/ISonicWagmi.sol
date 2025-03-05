// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ISonicWagmi {
    struct TokenInfo {
        address creator;
        address feeCollector;
        address pool;
        address gauge;
        uint256 positionId;
    }

    error BadDeploySalt(address token);
    error LaunchWithoutBuyout();

    event NewToken(
        address token,
        address pool,
        address creator,
        uint256 buyoutSAmount,
        uint256 buyoutTokenAmount
    );

    function tokenInfo(address token) external view returns (TokenInfo memory);

    function launch(
        int24 tickLower,
        int24 tickUpper,
        int24 tickSpacing,
        bytes32 deploySalt,
        uint256 totalSupply,
        string memory name,
        string memory symbol
    ) external payable returns (address token, uint256 buyoutTokenAmount);

    function calcDeploySalt(
        uint256 totalSupply,
        string memory name,
        string memory symbol
    ) external returns (bytes32 deploySalt);
}

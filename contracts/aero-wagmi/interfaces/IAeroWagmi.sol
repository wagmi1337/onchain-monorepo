// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IAeroWagmi {
    struct TokenInfo {
        address creator;
        address pool;
        uint256 positionId;
    }

    error BadDeploySalt(address token);

    event NewToken(
        address token,
        address pool,
        address creator,
        uint256 buyoutEthAmount,
        uint256 buyoutTokenAmount
    );

    function tokenInfo(address token) external view returns (TokenInfo memory);

    function launch(
        uint256 marketcapUsd,
        int24 tickSpacing,
        bytes32 deploySalt,
        string memory name,
        string memory symbol
    ) external payable returns (address token, uint256 buyoutTokenAmount);

    function calcDeploySalt(
        string memory name,
        string memory symbol
    ) external returns (bytes32 deploySalt);
}

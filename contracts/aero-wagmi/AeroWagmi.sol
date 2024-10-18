// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";

import {INonfungiblePositionManager} from "./aerodrome-finance/interfaces/INonfungiblePositionManager.sol";
import {ICLFactory} from "./aerodrome-finance/interfaces/ICLFactory.sol";
import {IPool} from "./aerodrome-finance/interfaces/IPool.sol";
import {ISwapRouter} from "./aerodrome-finance/interfaces/ISwapRouter.sol";

import {IWETH} from "./interfaces/IWETH.sol";
import {IAeroWagmi} from "./interfaces/IAeroWagmi.sol";
import {AeroWagmiToken} from "./AeroWagmiToken.sol";

contract AeroWagmi is UUPSUpgradeable, OwnableUpgradeable, IAeroWagmi {
    using TickMath for uint160;
    using TickMath for int24;

    uint256 public constant supply = 1e9 * 1e18; // 1b tokens
    uint256 public constant buyoutFeePct = 3; // 3%

    address[] public tokens;
    mapping(address => TokenInfo) _tokenInfos;

    IWETH constant WETH = IWETH(0x4200000000000000000000000000000000000006);
    address constant USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;

    IERC20 constant WAGMI = IERC20(0x7466dE7bb8B5E41Ee572f4167de6be782a7fA75d);
    IPool constant WAGMI_ETH_POOL =
        IPool(0xcB08B5b4E845402331e06441e1cd19A10eaa8289);
    IPool constant ETH_USDC_POOL =
        IPool(0xcDAC0d6c6C59727a65F871236188350531885C43);

    INonfungiblePositionManager constant nonfungiblePositionManager =
        INonfungiblePositionManager(0x827922686190790b37229fd06084350E74485b72);
    ISwapRouter constant swapRouter =
        ISwapRouter(0xBE6D8f0d05cC4be24d5167a3eF062215bE6D18a5);

    constructor() {}

    function initialize(address _owner) public virtual initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    function launch(
        uint256 marketcapUsd,
        int24 tickSpacing,
        bytes32 deploySalt,
        string memory name,
        string memory symbol
    ) external payable returns (address token, uint256 buyoutTokenAmount) {
        return _launch(marketcapUsd, tickSpacing, deploySalt, name, symbol);
    }

    function calcDeploySalt(
        string memory name,
        string memory symbol
    ) external returns (bytes32 deploySalt) {
        require(tx.origin == address(0));
        for (uint8 i = 0; i < 255; i++) {
            deploySalt = keccak256(
                abi.encodePacked(i, tokens.length, name, symbol)
            );
            address token = address(
                new AeroWagmiToken{salt: deploySalt}(supply, name, symbol)
            );
            if (token < address(WAGMI)) break;
        }
    }

    function numTokens() external view returns (uint256) {
        return tokens.length;
    }

    function tokenInfo(address token) external view returns (TokenInfo memory) {
        return _tokenInfos[token];
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _launch(
        uint256 initalMarketcapUsd,
        int24 tickSpacing,
        bytes32 deploySalt,
        string memory name,
        string memory symbol
    ) internal returns (address token, uint256 buyoutTokenAmount) {
        // 1. deploy
        token = address(
            new AeroWagmiToken{salt: deploySalt}(supply, name, symbol)
        );
        require(token < address(WAGMI), BadDeploySalt(token));
        tokens.push(token);

        // 2. provide liquidity and burn it
        IERC20(token).approve(address(nonfungiblePositionManager), supply);
        int24 tick = _calculateSqrtPriceX96(
            _getWagmiUsdPrice(),
            initalMarketcapUsd,
            supply
        ).getTickAtSqrtRatio();
        (uint256 positionId, , , ) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: token,
                token1: address(WAGMI),
                tickSpacing: tickSpacing,
                tickLower: _tick(tick, tickSpacing),
                tickUpper: _tick(TickMath.MAX_TICK, tickSpacing),
                amount0Desired: supply,
                amount0Min: 0,
                amount1Desired: 0,
                amount1Min: 0,
                recipient: 0x000000000000000000000000000000000000dEaD,
                deadline: block.timestamp,
                sqrtPriceX96: _tick(tick, tickSpacing).getSqrtRatioAtTick()
            })
        );
        address pool = ICLFactory(nonfungiblePositionManager.factory()).getPool(
            token,
            address(WAGMI),
            tickSpacing
        );

        // 3. buyout
        WETH.deposit{value: msg.value}();
        uint256 wagmiAmount = WAGMI_ETH_POOL.getAmountOut(
            (msg.value * (100 - buyoutFeePct)) / 100,
            address(WETH)
        );
        WETH.transfer(address(WAGMI_ETH_POOL), msg.value);
        WAGMI_ETH_POOL.swap(0, wagmiAmount, address(this), bytes(""));
        if (WAGMI.allowance(address(this), address(swapRouter)) < wagmiAmount) {
            WAGMI.approve(address(swapRouter), type(uint256).max);
        }
        buyoutTokenAmount = swapRouter.exactInputSingle(
            ISwapRouter.ExactInputSingleParams(
                address(WAGMI),
                token,
                tickSpacing,
                msg.sender,
                block.timestamp,
                wagmiAmount,
                0,
                0
            )
        );

        // 4. Save all info
        _tokenInfos[token] = TokenInfo({
            creator: msg.sender,
            pool: pool,
            positionId: positionId
        });
        emit NewToken(token, pool, msg.sender, msg.value, buyoutTokenAmount);
    }

    function _getWagmiUsdPrice() internal view returns (uint256) {
        uint256 usdAmount = 100;

        return
            (1e12 / usdAmount) *
            ETH_USDC_POOL.quote(
                address(WETH),
                WAGMI_ETH_POOL.quote(address(WAGMI), usdAmount * 1e18, 1),
                1
            );
    }

    function _calculateSqrtPriceX96(
        uint256 wagmiUsdPrice,
        uint256 marketcapUsd,
        uint256 tokenSupply
    ) internal pure returns (uint160) {
        uint256 tokenUsdPrice = Math.mulDiv(marketcapUsd, 1e18, tokenSupply);
        uint256 tokenWagmiPrice = Math.mulDiv(
            tokenUsdPrice,
            1e18,
            wagmiUsdPrice
        );

        return
            uint160(
                Math.mulDiv(Math.sqrt(tokenWagmiPrice), FixedPoint96.Q96, 1e9)
            );
    }

    function _tick(
        int24 tick,
        int24 tickSpacing
    ) internal pure returns (int24) {
        return (tick / tickSpacing) * tickSpacing;
    }
}

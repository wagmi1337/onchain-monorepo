// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";

import {INonfungiblePositionManager} from "./shadow/interfaces/INonfungiblePositionManager.sol";
import {IFactory} from "./shadow/interfaces/IFactory.sol";
import {IPool} from "./shadow/interfaces/IPool.sol";

import {IWrappedSonic} from "./interfaces/IWrappedSonic.sol";
import {ISonicWagmi} from "./interfaces/ISonicWagmi.sol";
import {SonicWagmiToken} from "./SonicWagmiToken.sol";

contract SonicWagmi is UUPSUpgradeable, OwnableUpgradeable, ISonicWagmi {
    using TickMath for int24;

    uint256 public constant buyoutFeePct = 3; // 3%

    address[] public tokens;
    mapping(address => mapping(address => uint256)) public feeCollected;
    mapping(address => TokenInfo) _tokenInfos;

    IWrappedSonic constant wS =
        IWrappedSonic(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    INonfungiblePositionManager constant nonfungiblePositionManager =
        INonfungiblePositionManager(0x12E66C8F215DdD5d48d150c8f46aD0c6fB0F4406);
    IFactory constant factory =
        IFactory(0xcD2d0637c94fe77C2896BbCBB174cefFb08DE6d7);

    function initialize(address _owner) public virtual initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    function launch(
        int24 tickLower,
        int24 tickUpper,
        int24 tickSpacing,
        bytes32 deploySalt,
        uint256 totalSupply,
        string memory name,
        string memory symbol
    ) external payable returns (address token, uint256 buyoutTokenAmount) {
        require(msg.value > 0, LaunchWithoutBuyout());

        token = address(
            new SonicWagmiToken{salt: deploySalt}(totalSupply, name, symbol)
        );
        require(token > address(wS), BadDeploySalt(token));
        tokens.push(token);

        address pool = factory.createPool(
            token,
            address(wS),
            tickSpacing,
            tickUpper.getSqrtRatioAtTick()
        );

        IERC20(token).approve(address(nonfungiblePositionManager), totalSupply);
        (uint256 positionId, , , ) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams({
                token0: address(wS),
                token1: token,
                tickSpacing: tickSpacing,
                tickLower: tickLower,
                tickUpper: tickUpper,
                amount0Desired: 0,
                amount1Desired: totalSupply,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            })
        );

        uint256 buyoutFee = (msg.value * buyoutFeePct) / 100;
        wS.depositFor{value: buyoutFee}(owner());
        (, int256 amount1) = IPool(pool).swap(
            msg.sender,
            true,
            int256(msg.value - buyoutFee),
            TickMath.MIN_SQRT_RATIO + 1,
            bytes("")
        );
        buyoutTokenAmount = uint256(-amount1);

        IERC20(token).transfer(
            msg.sender,
            IERC20(token).balanceOf(address(this))
        ); // dust

        _tokenInfos[token] = TokenInfo({
            creator: msg.sender,
            feeCollector: msg.sender,
            pool: pool,
            gauge: address(0),
            positionId: positionId
        });
        emit NewToken(token, pool, msg.sender, msg.value, buyoutTokenAmount);
    }

    function collectFee(
        address token
    ) external returns (uint256 wsAmount, uint256 tokenAmount) {
        TokenInfo storage info = _tokenInfos[token];

        if (info.gauge == address(0)) {
            (wsAmount, tokenAmount) = nonfungiblePositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: info.positionId,
                    recipient: address(this),
                    amount0Max: type(uint128).max,
                    amount1Max: type(uint128).max
                })
            );
            feeCollected[token][address(wS)] += wsAmount;
            if (tokenAmount > 0)
                IERC20(token).transfer(info.feeCollector, tokenAmount);

            if (wsAmount > 0) wS.transfer(owner(), wsAmount);
            feeCollected[token][token] += tokenAmount;
        } else {}
    }

    function calcDeploySalt(
        uint256 totalSupply,
        string memory name,
        string memory symbol
    ) external returns (bytes32 deploySalt) {
        require(tx.origin == address(0));

        for (uint8 i = 0; i < 256; i++) {
            deploySalt = keccak256(
                abi.encodePacked(i, tokens.length, name, symbol)
            );
            address token = address(
                new SonicWagmiToken{salt: deploySalt}(totalSupply, name, symbol)
            );
            if (token > address(wS)) break;
        }
    }

    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256,
        bytes calldata
    ) external {
        require(
            factory.getPool(
                IPool(msg.sender).token0(),
                IPool(msg.sender).token1(),
                IPool(msg.sender).tickSpacing()
            ) == msg.sender
        );

        wS.depositFor{value: uint256(amount0Delta)}(msg.sender);
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

    function _tick(
        int24 tick,
        int24 tickSpacing
    ) internal pure returns (int24) {
        return (tick / tickSpacing) * tickSpacing;
    }
}

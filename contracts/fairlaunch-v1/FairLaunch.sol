// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

import {FairToken} from "./FairToken.sol";
import {IFairLaunch} from "./interfaces/IFairLaunch.sol";

contract FairLaunch is Ownable, IFairLaunch {
    // Launch helpers
    IFactory factory = IFactory(0x33128a8fC17869897dcE68Ed026d694621f6FDfD);
    INFPManager nfpManager =
        INFPManager(0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1);
    IRouter router = IRouter(0x2626664c2603336E57B271c5C0b26F421741e481);

    uint256 initialBuyFeePct = 3;
    uint256 totalSupply = 1e9 * 1e18; // 1b tokens

    // Pool params
    address public constant weth = 0x4200000000000000000000000000000000000006;
    uint24 fee = 10000;

    uint160 sqrtPriceX96_01 = 2510809139091789284100322; // (token, weth)
    uint160 sqrtPriceX96_10 = 2500031419217008302293562112940196; // (weth, token)

    int24 tickA = 207200;
    int24 tickB = 887200;

    event NewFairLaunch(
        address token,
        address pool,
        address creator,
        uint256 initialBuyAmount,
        uint256 initialBuyToken
    );

    constructor() Ownable(msg.sender) {}

    function fairLaunch(
        string memory name,
        string memory symbol
    ) external payable {
        ERC20 token = new FairToken(totalSupply, name, symbol);

        IPool pool = _createPool(address(token));
        _addLiquidity(address(token), totalSupply);

        uint256 initialBuyToken = 0;
        if (msg.value > 0) {
            uint256 feeAmount = (msg.value * initialBuyFeePct) / 100;
            initialBuyToken = _initalBuy(address(token), msg.value - feeAmount);
            Address.sendValue(payable(owner()), feeAmount);
        }

        emit NewFairLaunch(
            address(token),
            address(pool),
            msg.sender,
            msg.value,
            initialBuyToken
        );
    }

    function changeLaunchParams(
        uint256 totalSupply_,
        uint256 initialBuyFeePct_,
        uint160 sqrtPriceX96_01_,
        uint160 sqrtPriceX96_10_,
        uint24 fee_,
        int24 tickA_,
        int24 tickB_
    ) external onlyOwner {
        totalSupply = totalSupply_;
        initialBuyFeePct = initialBuyFeePct_;
        sqrtPriceX96_01 = sqrtPriceX96_01_;
        sqrtPriceX96_10 = sqrtPriceX96_10_;
        fee = fee_;

        tickA = tickA_;
        tickB = tickB_;
    }

    function _createPool(address token) internal returns (IPool) {
        IPool pool = factory.createPool(token, weth, fee);
        pool.initialize(token < weth ? sqrtPriceX96_01 : sqrtPriceX96_10);

        return pool;
    }

    function _addLiquidity(address token, uint256 amount) internal {
        INFPManager.MintParams memory mintParams;
        if (token < weth) {
            mintParams.token0 = token;
            mintParams.token1 = weth;
            mintParams.amount0Desired = amount;

            mintParams.tickLower = -tickA;
            mintParams.tickUpper = tickB;
        } else {
            mintParams.token0 = weth;
            mintParams.token1 = token;
            mintParams.amount1Desired = amount;

            mintParams.tickLower = -tickB;
            mintParams.tickUpper = tickA;
        }
        mintParams.fee = fee;
        mintParams.recipient = address(this);
        mintParams.deadline = block.timestamp;

        IERC20(token).approve(address(nfpManager), amount);
        (uint256 positionId, , , ) = nfpManager.mint(mintParams);
        nfpManager.approve(owner(), positionId);
    }

    function _initalBuy(
        address token,
        uint256 amount
    ) internal returns (uint256) {
        return
            router.exactInputSingle{value: amount}(
                IRouter.ExactInputSingleParams({
                    tokenIn: weth,
                    tokenOut: token,
                    fee: fee,
                    recipient: msg.sender,
                    amountIn: amount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                })
            );
    }
}

interface IFactory {
    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (IPool);
}

interface IPool {
    function initialize(uint160 sqrtPriceX96) external;
}

interface INFPManager {
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    function mint(
        MintParams calldata params
    )
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    function approve(address to, uint256 tokenId) external;
}

interface IRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams memory params
    ) external payable returns (uint256 amountOut);
}

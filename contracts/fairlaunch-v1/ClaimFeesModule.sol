// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISafe, Enum} from "@safe-global/safe-smart-account/contracts/interfaces/ISafe.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LockUNCXModule} from "./LockUNCXModule.sol";

contract ClaimFeesModule is Ownable {
    error UnsupportedPosition(uint256 positionId);
    error CreatorNotSet(uint256 positionId);
    error TooEarly();

    uint64 public maxClaimAmountBps = 50;
    uint24 public claimInterval = 1 weeks;
    address public operator;

    mapping(uint256 => address) public positionIdToCreator;
    mapping(uint256 => uint256) public lastClaim;

    address constant WETH = 0x4200000000000000000000000000000000000006;

    LockUNCXModule constant lockModule =
        LockUNCXModule(0x2ae762AC100A140671fBB5662366A10Ab082661B);
    address constant FAIR_LAUNCH = 0xFF747D4Cea4ED9c24334A77b0E4824E8EC9A6808;
    address constant TREASURY = 0xb0Cc739c2F7e1232408A2d4e3329fce1693f7713;
    address constant NFP_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant UNCX_LOCKER = 0x231278eDd38B00B07fBd52120CEf685B9BaEBCC1;

    constructor() Ownable(msg.sender) {
        operator = msg.sender;
    }

    function claim(
        uint256 positionId
    ) external returns (uint256 claimableAmount) {
        require(claimTimer(positionId) == 0, TooEarly());

        address creator = positionIdToCreator[positionId];
        IERC20 token = positionToken(positionId);
        _collect(positionId);

        claimableAmount = Math.min(
            token.balanceOf(TREASURY),
            (token.totalSupply() * maxClaimAmountBps) / 1e4
        );

        if (creator != address(0)) {
            ISafe(TREASURY).execTransactionFromModuleReturnData(
                address(token),
                0,
                abi.encodeCall(
                    token.transfer,
                    (positionIdToCreator[positionId], claimableAmount)
                ),
                Enum.Operation.Call
            );
            lastClaim[positionId] = block.timestamp;
        }
    }

    function setCreator(uint256 positionId, address creator) external {
        if (positionIdToCreator[positionId] != address(0)) {
            _checkOwner();
        } else {
            require(owner() == msg.sender || operator == msg.sender);
        }

        positionIdToCreator[positionId] = creator;
    }

    function setCreators(
        uint256[] calldata positionIds,
        address[] calldata creators
    ) external onlyOwner {
        uint256 n = positionIds.length;
        require(creators.length == n);
        for (uint256 i = 0; i < n; i++) {
            positionIdToCreator[positionIds[i]] = creators[i];
        }
    }

    function changeOperator(address newOperator) external onlyOwner {
        operator = newOperator;
    }

    function changeClaimSchedule(
        uint64 maxClaimAmountBps_,
        uint24 claimInterval_
    ) external onlyOwner {
        maxClaimAmountBps = maxClaimAmountBps_;
        claimInterval = claimInterval_;
    }

    function positionToken(uint256 positionId) public view returns (IERC20) {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(NFP_MANAGER).positions(positionId);
        if (token0 == WETH) return IERC20(token1);
        if (token1 == WETH) return IERC20(token0);
        revert UnsupportedPosition(positionId);
    }

    function claimTimer(uint256 positionId) public view returns (uint256) {
        uint256 timeForClaim = lastClaim[positionId] + claimInterval;
        if (block.timestamp > timeForClaim) return 0;
        else return timeForClaim - block.timestamp;
    }

    function _collect(uint256 positionId) internal returns (bool) {
        address positionOwner = IERC721(NFP_MANAGER).ownerOf(positionId);
        if (positionOwner == FAIR_LAUNCH) {
            return
                ISafe(TREASURY).execTransactionFromModule(
                    NFP_MANAGER,
                    0,
                    abi.encodeCall(
                        INonfungiblePositionManager.collect,
                        INonfungiblePositionManager.CollectParams({
                            tokenId: positionId,
                            recipient: TREASURY,
                            amount0Max: type(uint128).max,
                            amount1Max: type(uint128).max
                        })
                    ),
                    Enum.Operation.Call
                );
        }

        uint256 lockId = lockModule.lockByPosition(positionId);
        if (positionOwner == UNCX_LOCKER && lockId > 0) {
            return
                ISafe(TREASURY).execTransactionFromModule(
                    UNCX_LOCKER,
                    0,
                    abi.encodeCall(
                        IUNCXLocker.collect,
                        (
                            lockModule.lockByPosition(positionId),
                            TREASURY,
                            type(uint128).max,
                            type(uint128).max
                        )
                    ),
                    Enum.Operation.Call
                );
        }

        revert UnsupportedPosition(positionId);
    }
}

interface IUNCXLocker {
    function collect(
        uint256 _lockId,
        address _recipient,
        uint128 _amount0Max,
        uint128 _amount1Max
    )
        external
        returns (uint256 amount0, uint256 amount1, uint256 fee0, uint256 fee1);
}

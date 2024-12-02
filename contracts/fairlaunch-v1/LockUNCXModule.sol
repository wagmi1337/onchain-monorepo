// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ISafe, Enum} from "@safe-global/safe-smart-account/contracts/interfaces/ISafe.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {FullMath} from "@uniswap/v3-core/contracts/libraries/FullMath.sol";
import {FixedPoint96} from "@uniswap/v3-core/contracts/libraries/FixedPoint96.sol";
import {TickMath} from "@uniswap/v3-core/contracts/libraries/TickMath.sol";
import {INonfungiblePositionManager} from "@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol";

contract LockUNCXModule is Ownable {
    error PaymentRequired(uint256 minMsgValue);
    error RequirementsForSponshoripNotMet();
    error BadPositionOwner(address positionOwner);
    error BadPositionOperator(address positionOperator);
    error LockFailed();
    error OnlyEOA();

    event PositionLocked(uint256 positionId);

    address constant FAIR_LAUNCH = 0xFF747D4Cea4ED9c24334A77b0E4824E8EC9A6808;
    address constant TREASURY = 0xb0Cc739c2F7e1232408A2d4e3329fce1693f7713;
    address constant NFP_MANAGER = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1;
    address constant UNCX_LOCKER = 0x231278eDd38B00B07fBd52120CEf685B9BaEBCC1;

    // clowns from UNCX don't store this info, so we do
    mapping(uint256 positionId => uint256 lockId) public lockByPosition;

    constructor() Ownable(TREASURY) {}

    string feeName = "LVP";
    uint256 public targetTokenPrice = 30000000000;
    uint256 public lockPeriod = 6 * 30 * 24 * 60 * 60;

    function lock(uint256 positionId) external payable {
        require(msg.value >= lockPrice(), PaymentRequired(lockPrice()));
        Address.sendValue(payable(TREASURY), msg.value);
        _lock(positionId);
    }

    function lockSponsored(uint256 positionId) external {
        require(
            tokenPrice(positionId) >= targetTokenPrice,
            RequirementsForSponshoripNotMet()
        );
        _lock(positionId);
    }

    function changeParams(
        uint256 targetTokenPrice_,
        uint256 lockPeriod_,
        string calldata feeName_
    ) external onlyOwner {
        targetTokenPrice = targetTokenPrice_;
        lockPeriod = lockPeriod_;
        feeName = feeName_;
    }

    function updateLockByPosition(uint256 lockId) external {
        IUNCXLocker.Lock memory lockInfo = IUNCXLocker(UNCX_LOCKER).getLock(
            lockId
        );
        require(lockInfo.nftPositionManager == NFP_MANAGER);
        lockByPosition[lockInfo.nft_id] = lockId;
    }

    function tokenPrice(uint256 positionId) public view returns (uint256) {
        IUniswapV3Pool pool = _getPool(positionId);
        (, int24 tick, , , , , ) = pool.slot0();

        uint256 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(
            pool.token0() == 0x4200000000000000000000000000000000000006
                ? -tick
                : tick
        );
        uint256 priceX96 = FullMath.mulDiv(
            sqrtPriceX96,
            sqrtPriceX96,
            FixedPoint96.Q96
        );

        return FullMath.mulDiv(priceX96, 1e18, FixedPoint96.Q96);
    }

    function lockPrice() public view returns (uint256) {
        return IUNCXLocker(UNCX_LOCKER).getFee(feeName).flatFee;
    }

    function _lock(uint256 positionId) internal {
        require(msg.sender == tx.origin, OnlyEOA());

        address positionOwner = IERC721(NFP_MANAGER).ownerOf(positionId);
        require(positionOwner == FAIR_LAUNCH, BadPositionOwner(positionOwner));

        address positionOperator = IERC721(NFP_MANAGER).getApproved(positionId);
        require(
            positionOperator == TREASURY,
            BadPositionOperator(positionOperator)
        );

        ISafe(TREASURY).execTransactionFromModule(
            NFP_MANAGER,
            0,
            abi.encodeWithSignature(
                "safeTransferFrom(address,address,uint256)",
                FAIR_LAUNCH,
                TREASURY,
                positionId
            ),
            Enum.Operation.Call
        );

        (bool lockResult, bytes memory result) = ISafe(TREASURY)
            .execTransactionFromModuleReturnData(
                UNCX_LOCKER,
                lockPrice(),
                abi.encodeCall(
                    IUNCXLocker.lock,
                    IUNCXLocker.LockParams({
                        nftPositionManager: NFP_MANAGER,
                        nft_id: positionId,
                        dustRecipient: TREASURY,
                        owner: TREASURY,
                        additionalCollector: TREASURY,
                        collectAddress: TREASURY,
                        unlockDate: block.timestamp + lockPeriod,
                        countryCode: 0,
                        feeName: feeName,
                        r: new bytes[](0)
                    })
                ),
                Enum.Operation.Call
            );
        require(lockResult, LockFailed());

        uint256 lockId = abi.decode(result, (uint256));
        lockByPosition[positionId] = lockId;
    }

    function _getPool(
        uint256 positionId
    ) internal view returns (IUniswapV3Pool) {
        (
            ,
            ,
            address token0,
            address token1,
            uint24 fee,
            ,
            ,
            ,
            ,
            ,
            ,

        ) = INonfungiblePositionManager(NFP_MANAGER).positions(positionId);

        return
            IUniswapV3Pool(
                IUniswapV3Factory(
                    INonfungiblePositionManager(NFP_MANAGER).factory()
                ).getPool(token0, token1, fee)
            );
    }
}

interface IUNCXLocker {
    struct LockParams {
        address nftPositionManager;
        uint256 nft_id;
        address dustRecipient;
        address owner;
        address additionalCollector;
        address collectAddress;
        uint256 unlockDate;
        uint16 countryCode;
        string feeName;
        bytes[] r;
    }

    function lock(
        LockParams calldata params
    ) external payable returns (uint256);

    struct FeeStruct {
        string name;
        uint256 lpFee;
        uint256 collectFee;
        uint256 flatFee;
        address flatFeeToken;
    }

    function getFee(
        string memory _name
    ) external view returns (FeeStruct memory);

    struct Lock {
        uint256 lock_id;
        address nftPositionManager;
        address pool;
        uint256 nft_id;
        address owner;
        address pendingOwner;
        address additionalCollector;
        address collectAddress;
        uint256 unlockDate;
        uint16 countryCode;
        uint256 ucf;
    }

    function getLock(uint256) external view returns (Lock memory);
}

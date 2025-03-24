// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {DoubleEndedQueue} from "@openzeppelin/contracts/utils/structs/DoubleEndedQueue.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IPoW} from "./IPoW.sol";
import {secp256k1, ECCPoint} from "./secp256k1.sol";

contract PoW is IPoW, UUPSUpgradeable, OwnableUpgradeable, PausableUpgradeable {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;
    using {secp256k1.toPublicKey} for uint256;

    address constant MAGIC_NUMBER = 0x8888888888888888888888888888888888888888;
    uint256 constant SQRT2 = 1414213562373095168;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IERC20 immutable INFINITY;

    // halving info
    uint256 public numSubmissions;
    uint256 public reward;
    uint256 public halvingPeriod;

    // problem info
    uint256 public privateKeyA;
    uint160 public difficulty;

    uint88 targetTime;
    uint8 sampleSize;
    mapping(uint256 => uint256) _submissionBlocks;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address infinity) {
        _disableInitializers();
        INFINITY = IERC20(infinity);
    }

    function initialize(address _owner) public virtual initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
    }

    function initialize2() external reinitializer(2) {
        __Pausable_init();
        _pause();
    }

    function startMining() external onlyOwner {
        _unpause();
        privateKeyA = block.timestamp;
        difficulty = uint160(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
    }

    function setMiningParams(
        uint256 reward_,
        uint256 halvingPeriod_,
        uint88 targetTime_,
        uint8 sampleSize_
    ) external onlyOwner {
        reward = reward_;
        halvingPeriod = halvingPeriod_;
        targetTime = targetTime_;
        sampleSize = sampleSize_;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function submit(
        address recipient,
        ECCPoint memory publicKeyB,
        bytes memory signatureAB,
        bytes calldata data
    ) external whenNotPaused {
        // Process submition
        address addressAB = publicKeyB
            .ecAdd(privateKeyA.toPublicKey())
            .toAddress();

        // checking, that solution correct
        if ((uint160(addressAB) ^ uint160(MAGIC_NUMBER)) > difficulty) {
            revert BadSolution(
                addressAB,
                address(difficulty ^ uint160(MAGIC_NUMBER))
            );
        }
        emit Submission(addressAB, data);

        // checking, that solver really found privateKeyB
        require(
            addressAB ==
                keccak256(abi.encodePacked(recipient, data))
                    .toEthSignedMessageHash()
                    .recover(signatureAB),
            BadSignature()
        );

        INFINITY.transfer(recipient, reward);
        privateKeyA = uint256(
            keccak256(abi.encodePacked(publicKeyB.x, publicKeyB.y))
        );

        _ajustDifficulty();
        _halving();
        numSubmissions += 1;

        emit NewProblem(privateKeyA, difficulty);
    }

    function _ajustDifficulty() internal {
        _submissionBlocks[numSubmissions] = block.number;
        if (numSubmissions < sampleSize) return;

        uint160 realTime = uint160(
            block.number - _submissionBlocks[numSubmissions - sampleSize]
        );
        // We store info only for last transactions
        delete _submissionBlocks[numSubmissions - sampleSize];

        uint256 ajustedDifficulty = (uint256(difficulty) * realTime) /
            targetTime;

        if (ajustedDifficulty > type(uint160).max) {
            difficulty = type(uint160).max;
        } else {
            difficulty = uint160(ajustedDifficulty);
        }
    }

    function _halving() internal {
        if (numSubmissions > 0 && numSubmissions % halvingPeriod == 0) {
            reward = (reward * 1e18) / SQRT2;
            emit Halving(reward);
        }
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {WETH} from "./external/weth.sol";
import "./external/aerodrome.sol" as aerodrome;

interface IWeProFees {
    event FeesPaid(address ref, uint256 fees);
    event EpochEnded(uint256 epoch, uint256 ethFees, uint256 weBuybacked);
    event Claimed(address ref, uint256 weAmount, uint256 nextClaimEpoch);

    function payFee(address ref) external payable;

    function totalEarnedWE(address ref) external view returns (uint256 earned);
}

contract WeProFees is IWeProFees, Ownable {
    IERC20 constant WE = IERC20(0x740027F1Ade0c4Da59fa90f5ce23c79fF8807cC7);
    aerodrome.ICLPool constant WE_WAGMI_POOL =
        aerodrome.ICLPool(0x3D6F5caB5a2CA17103a2ED0B1254710D28489143);
    aerodrome.IPool constant WETH_WAGMI_POOL =
        aerodrome.IPool(0xcB08B5b4E845402331e06441e1cd19A10eaa8289);

    uint256 public currentEpoch = 0;

    mapping(address => mapping(uint256 => uint256)) public paidRefFees;
    mapping(address => uint256) public nextClaimEpoch;
    mapping(uint256 => uint256) public paidFees;
    mapping(uint256 => uint256) public buybackedWE;

    constructor() Ownable(msg.sender) {}

    function payFee(address ref) external payable {
        paidFees[currentEpoch] += msg.value;
        paidRefFees[ref][currentEpoch] += msg.value;
        emit FeesPaid(ref, msg.value);
    }

    receive() external payable {
        paidFees[currentEpoch] += msg.value;
        emit FeesPaid(address(0), msg.value);
    }

    function endEpoch() external onlyOwner {
        WE_WAGMI_POOL.swap(
            address(this),
            false,
            int256(
                WETH_WAGMI_POOL.getAmountOut(
                    paidFees[currentEpoch],
                    0x4200000000000000000000000000000000000006
                )
            ),
            1461446703485210103287273052203988822378723970342 - 1,
            abi.encode()
        );
    }

    function uniswapV3SwapCallback(
        int256 amount0,
        int256 amount1,
        bytes calldata
    ) external {
        require(msg.sender == address(WE_WAGMI_POOL));
        require(amount0 < 0);
        require(amount1 > 0);

        uint256 weAmount = uint256(-amount0);
        uint256 wagmiAmount = uint256(amount1);
        uint256 ethAmount = paidFees[currentEpoch];

        WETH.deposit{value: ethAmount}();
        WETH.transfer(address(WETH_WAGMI_POOL), ethAmount);
        WETH_WAGMI_POOL.swap(0, wagmiAmount, address(WE_WAGMI_POOL), bytes(""));

        buybackedWE[currentEpoch] = weAmount;
        emit EpochEnded(currentEpoch++, ethAmount, weAmount);
    }

    function claim() external {
        uint256 fromEpoch = nextClaimEpoch[msg.sender];
        uint256 toEpoch = Math.min(currentEpoch, 50);

        nextClaimEpoch[msg.sender] = toEpoch;
        uint256 weAmount = totalEarnedWE(fromEpoch, toEpoch, msg.sender);
        WE.transfer(msg.sender, weAmount);
        emit Claimed(msg.sender, weAmount, toEpoch);
    }

    function claiamble(address ref) external view returns (uint256) {
        return totalEarnedWE(nextClaimEpoch[msg.sender], currentEpoch, ref);
    }

    function totalEarnedWE(address ref) public view returns (uint256 earned) {
        return totalEarnedWE(0, currentEpoch, ref);
    }

    function totalEarnedWE(
        uint256 fromEpoch,
        uint256 toEpoch,
        address ref
    ) public view returns (uint256 earned) {
        for (uint256 epoch = fromEpoch; epoch < toEpoch; epoch++) {
            earned += earnedWE(ref, epoch);
        }
    }

    function earnedWE(
        address ref,
        uint256 epoch
    ) public view returns (uint256) {
        return (buybackedWE[epoch] * paidRefFees[ref][epoch]) / paidFees[epoch];
    }
}

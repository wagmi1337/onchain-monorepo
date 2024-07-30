// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Airdrop is Ownable {
    using MessageHashUtils for bytes32;
    using ECDSA for bytes32;

    error WrongSignature();
    error AlreadyClaimed();

    event Claimed(address user, uint256 amount);

    IERC20 public immutable WAGMI;
    mapping(address => uint256) public claimedAmount;

    constructor(address wagmi) Ownable(msg.sender) {
        WAGMI = IERC20(wagmi);
    }

    function claimAirdrop(
        address recipient,
        uint256 amount,
        bytes calldata signature
    ) external {
        if (claimedAmount[recipient] > 0) revert AlreadyClaimed();

        if (msg.sender != owner()) {
            bytes32 message = keccak256(abi.encodePacked(recipient, amount));
            if (message.toEthSignedMessageHash().recover(signature) != owner())
                revert WrongSignature();

            claimedAmount[recipient] = amount;
            emit Claimed(recipient, amount);
        }

        WAGMI.transfer(recipient, amount);
    }
}

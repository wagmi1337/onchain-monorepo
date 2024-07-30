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

    IERC20 public immutable WAGMI;
    mapping(address => bool) public isClaimed;

    constructor(address wagmi) Ownable(msg.sender) {
        WAGMI = IERC20(wagmi);
    }

    function claimAirdrop(
        address recipient,
        uint256 amount,
        bytes calldata signature
    ) external {
        if (isClaimed[msg.sender]) revert AlreadyClaimed();

        if (msg.sender != owner()) {
            bytes32 message = keccak256(abi.encodePacked(recipient, amount));
            if (message.toEthSignedMessageHash().recover(signature) != owner())
                revert WrongSignature();

            isClaimed[msg.sender] = true;
        }

        WAGMI.transfer(recipient, amount);
    }
}

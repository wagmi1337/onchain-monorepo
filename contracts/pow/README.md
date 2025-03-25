# Infinity (pow memecoin token)

#### Deployments (deployed on Sonic Mainnet and Sonic Blaze Testnet)
| Contract| Address |
|--|--|
| Infinity.sol | 0x888852d1c63c7b333efEb1c4C5C79E36ce918888 |
| PoW.sol | 0x8888FF459Da48e5c9883f893fc8653c8E55F8888 |

#### How to mine

1. You need to get problem parts
- `privateKeyA` - derived from previous solution
-  `difficulty` - controls submissions speed

You can get current values with contract read or listen event with new values
```solidity
function privateKeyA() external view returns (uint256);
function difficulty() external view returns (uint160);

event NewProblem(uint256 privateKeyA, uint160 difficulty);
```

2. Search `privateKeyB` that fits equation `uint160(addressAB ^ MAGIC_NUMBER) < difficulty`, where:
- `addressAB` - evm address from `publicKeyAB`
- `publicKeyAB` - public key, calculated with private key `privateKeyAB`
- `privateKeyAB` - private key, sum of `privateKeyA`, `privateKeyB`*
- `privateKeyB` - random private key (uint256 number)
 *you should use modulo of sum `(privateKeyA  +  privateKeyB) %  0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f`

3. Signature message by `privateKeyAB`. Message should consist of reward recipient and data (any set of bytes, can be empty). Message should be signed using [EIP-191](https://eips.ethereum.org/EIPS/eip-191)

#### How to construct message:
ethers.js
```javascript
ethers.solidityPackedKeccak256(
    ["address", "bytes"],
    [recipient, data]
)
```

solidity
```solidity
keccak256(abi.encodePacked(recipient, data))
```

4. Run transaction with call `PoW.submit`
```solidity
PoW.submit(
    recipient, // used in message in #3
    publicKeyB,
    signatureAB, // calculated in #3
    data, // used in message in #3
);
```
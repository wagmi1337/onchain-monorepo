import { expect } from "chai";
import { ethers, upgrades } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { secp256k1 } from "@noble/curves/secp256k1";
import { PoW } from "../typechain-types";


const pk2hex = (pk: bigint) => ('0'.repeat(64) + pk.toString(16)).slice(-64)

describe("PoW", function () {
    async function deploy() {
        const [owner, submitter, rewardReciever] = await ethers.getSigners()

        const token = await ethers.deployContract("Infinity", [owner])

        const PoW = await ethers.getContractFactory("PoW");
        const pow = (await upgrades.deployProxy(
            PoW,
            [owner.address],
            { constructorArgs: [await token.getAddress()] }
        )) as unknown as PoW;
        await upgrades.upgradeProxy(
            await pow.getAddress(),
            PoW,
            {
                constructorArgs: [await token.getAddress()],
                call: {
                    fn: "initialize2"
                }
            }
        )

        await pow.setMiningParams(
            ethers.parseEther("1"),
            1,
            10,
            9
        )
        await pow.startMining();

        await token.connect(owner).transfer(pow, await token.totalSupply())

        return { token, pow, submitter, rewardReciever }
    }

    it("should mine", async function () {
        const { pow, token, submitter, rewardReciever } = await loadFixture(deploy)
        const MAGIC_NUMBER = 0x8888888888888888888888888888888888888888n;

        let privateKeyA = await pow.privateKeyA();
        let difficulty = await pow.difficulty();

        let privateKeyB = 1n;
        let numSolutions = 0;

        const gasUsed = [];

        while (numSolutions < 500) {
            privateKeyB++;
            const accountB = new ethers.Wallet(pk2hex(privateKeyB));
            const publicKeyB = secp256k1.ProjectivePoint.fromHex(accountB.signingKey.publicKey.substring(2))

            const privateKeyAB = (privateKeyA + privateKeyB) % secp256k1.CURVE.p;
            const accountAB = new ethers.Wallet(pk2hex(privateKeyAB));

            if ((BigInt(accountAB.address) ^ MAGIC_NUMBER) >= difficulty) {
                continue
            }

            const data = ethers.toUtf8Bytes("test")

            const messageHash = ethers.getBytes(ethers.solidityPackedKeccak256(
                ["address", "bytes"],
                [rewardReciever.address, data]
            ))

            const reward = await pow.reward();
            const tx = pow.connect(submitter).submit(
                rewardReciever,
                { x: publicKeyB.px, y: publicKeyB.py },
                await accountAB.signMessage(messageHash),
                data
            )
            const r = await (await tx).wait();
            if (r?.gasUsed)
                gasUsed.push(r?.gasUsed)

            await expect(tx).to.be.not.reverted
            await expect(tx).changeTokenBalance(token, rewardReciever, reward)

            numSolutions += 1;
            privateKeyA = await pow.privateKeyA()
            difficulty = await pow.difficulty()

            console.log(accountAB.address)
        }

        console.log(`Avg gas used: ${Number(gasUsed.reduce((a, b) => a + b)) / gasUsed.length}`)

    })

});
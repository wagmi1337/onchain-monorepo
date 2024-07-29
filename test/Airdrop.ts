import { expect } from "chai"
import { ethers } from "hardhat";
import { loadFixture, reset } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("FairLaunch", function () {
    this.beforeAll(async () => {
        await reset(process.env.BASE_RPC)
    })

    async function deploy() {
        const [owner, user] = await ethers.getSigners()

        const wagmi = await ethers.deployContract("WAGMI", owner)
        const airdrop = await ethers.deployContract("Airdrop", [wagmi], owner)

        return { airdrop, owner, user }
    }

    it("claim", async function () {
        const { airdrop, owner, user } = await loadFixture(deploy)

        const wagmi = await ethers.getContractAt("IERC20", await airdrop.WAGMI())
        await wagmi.connect(owner).transfer(airdrop, await wagmi.balanceOf(owner))

        // owner claim
        await expect(
            airdrop
                .connect(owner)
                .claimAirdrop(user, 111, ethers.randomBytes(65))
        ).changeTokenBalance(wagmi, user, 111)

        // malicious try
        await expect(
            airdrop
                .connect(user)
                .claimAirdrop(user, 123, await user.signMessage(ethers.solidityPackedKeccak256(["address", "uint256"], [user.address, 123])))
        ).revertedWithCustomError(airdrop, "WrongSignature")

        // approved claim
        const message = ethers.getBytes(ethers.solidityPackedKeccak256(["address", "uint256"], [user.address, 222]));
        await expect(
            airdrop
                .connect(user)
                .claimAirdrop(
                    user,
                    222,
                    await owner.signMessage(message)
                )
        ).changeTokenBalance(wagmi, user, 222)


    });
});
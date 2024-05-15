import { expect } from "chai"
import { ethers } from "hardhat";
import { loadFixture, reset } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("FairLaunch", function () {
    this.beforeAll(async () => {
        await reset(process.env.BASE_RPC)
    })

    async function deploy() {
        const [owner, user] = await ethers.getSigners()

        const fairLaunch = await ethers.deployContract("FairLaunch", owner)

        return { fairLaunch, owner, user }
    }

    it("launch", async function () {
        const { fairLaunch, owner, user } = await loadFixture(deploy)

        const weth = await fairLaunch.weth();
        while (true) {
            const tx = await fairLaunch.connect(user).fairLaunch(
                "Token",
                "TKN",
                { value: ethers.parseEther("1") }
            );
            const receipt = await tx.wait();
            const tokenAddress = fairLaunch.interface.parseLog(receipt?.logs.find(l => l.address === fairLaunch.target))?.args[0];
            if (BigInt(tokenAddress) < BigInt(weth)) break
        }

        const tx = await fairLaunch.connect(user).fairLaunch(
            "Token",
            "TKN",
            { value: ethers.parseEther("1") }
        );
        const receipt = await tx.wait();

        const tokenAddress = fairLaunch.interface.parseLog(receipt?.logs.find(l => l.address === fairLaunch.target))?.args[0];
        const token = await ethers.getContractAt("FairToken", tokenAddress);

        expect(await token.balanceOf(user)).to.be.gt(0)
        expect(await token.name()).to.be.eq("Token")
        expect(await token.symbol()).to.be.eq("TKN")
    });
});
import { expect } from "chai"
import { ethers } from "hardhat";
import { loadFixture, reset } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("FairLaunchQuoter", function () {
    this.beforeAll(async () => {
        await reset(process.env.BASE_RPC)
    })

    async function deploy() {
        const [user] = await ethers.getSigners()

        const fairLaunch = await ethers.deployContract("FairLaunch")
        const fairLaunchQuoter = await ethers.deployContract("FairLaunchQuoter")

        return { fairLaunch, fairLaunchQuoter, user }
    }

    it("quote", async function () {
        const { fairLaunch, fairLaunchQuoter, user } = await loadFixture(deploy)

        const computedTokenAddress = ethers.getCreateAddress({
            from: await fairLaunch.getAddress(),
            nonce: await ethers.provider.getTransactionCount(fairLaunch)
        })
        const initialBuyAmount = ethers.parseEther("1");

        const [quoteInitialBuyToken, totalSupply] = await fairLaunchQuoter
            .quoteLaunch
            .staticCall(
                fairLaunch,
                computedTokenAddress,
                { value: initialBuyAmount, from: user.address }
            )

        const tx = await fairLaunch.connect(user).fairLaunch(
            "Token",
            "TKN",
            { value: initialBuyAmount }
        );
        const receipt = await tx.wait()

        const [tokenAddress, _, __, ___, initialBuyToken] = fairLaunch.interface.parseLog(receipt?.logs.find(l => l.address === fairLaunch.target))?.args;
        const token = await ethers.getContractAt("IERC20", tokenAddress)

        expect(computedTokenAddress).to.be.eq(tokenAddress)
        expect(quoteInitialBuyToken).to.be.eq(initialBuyToken)
        expect(totalSupply).to.be.eq(await token.totalSupply())
    })
})
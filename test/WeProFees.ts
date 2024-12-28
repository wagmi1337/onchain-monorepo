import { expect } from "chai"
import { ethers } from "hardhat";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { reset } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("WeProFees", function () {
    this.beforeAll(async () => {
        await reset(process.env.BASE_RPC, 23447000)
    })

    it("one epoch", async function () {
        const [owner, ref1, ref2] = await ethers.getSigners()
        const weProFees = await ethers.deployContract("WeProFees", owner)

        const WE = await ethers.getContractAt("IERC20", "0x740027F1Ade0c4Da59fa90f5ce23c79fF8807cC7")
        const $1eth = ethers.parseEther("1");

        // epoch #0
        expect(await weProFees.currentEpoch()).to.be.eq(0);
        let epoch = 0

        await weProFees.payFee(ref1, { value: $1eth });
        expect(await weProFees.paidRefFees(ref1, epoch)).to.be.eq($1eth);
        expect(await weProFees.paidFees(epoch)).to.be.eq($1eth);

        await weProFees.payFee(ref1, { value: $1eth });
        expect(await weProFees.paidRefFees(ref1, epoch)).to.be.eq($1eth + $1eth);
        expect(await weProFees.paidFees(epoch)).to.be.eq($1eth + $1eth);

        await weProFees.payFee(ref2, { value: $1eth })
        expect(await weProFees.paidRefFees(ref2, epoch)).to.be.eq($1eth);
        expect(await weProFees.paidFees(epoch)).to.be.eq($1eth + $1eth + $1eth);

        await expect(weProFees.connect(owner).endEpoch())
            .emit(weProFees, "EpochEnded")
            .withArgs(epoch, $1eth + $1eth + $1eth, anyValue)
        expect(await weProFees.earnedWE(ref1, epoch)).to.be.approximately(2n * await weProFees.earnedWE(ref2, epoch), 1n)

        expect(weProFees.connect(ref1).claim()).to.be.changeTokenBalance(
            WE,
            ref1,
            await weProFees.earnedWE(ref1, epoch)
        )
        expect(await weProFees.nextClaimEpoch(ref1)).to.be.eq(1n);

        // epoch #1
        expect(await weProFees.currentEpoch()).to.be.eq(1);
        epoch = 1

        await weProFees.payFee(ref2, { value: $1eth })
        expect(await weProFees.paidRefFees(ref2, epoch)).to.be.eq($1eth);
        expect(await weProFees.paidFees(epoch)).to.be.eq($1eth);

        await expect(weProFees.connect(owner).endEpoch())
            .emit(weProFees, "EpochEnded")
            .withArgs(epoch, $1eth, anyValue)

        expect(await weProFees["totalEarnedWE(address)"](ref2)).to.be.eq(await weProFees.earnedWE(ref2, 0) + await weProFees.earnedWE(ref2, 1))
    });

});
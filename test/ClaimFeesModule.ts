import { expect } from "chai"
import { ethers } from "hardhat";
import { loadFixture, reset, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("ClaimFeesModule", function () {
    this.beforeAll(async () => {
        await reset(process.env.BASE_RPC)
    })

    async function deploy() {
        const [creator, creator2, owner, operator] = await ethers.getSigners();
        const safe = await ethers.getContractAt(
            "ISafe", "0xb0Cc739c2F7e1232408A2d4e3329fce1693f7713",
            await ethers.getImpersonatedSigner("0xb0Cc739c2F7e1232408A2d4e3329fce1693f7713")
        );
        const module = await ethers.deployContract("ClaimFeesModule", owner);
        await module.changeOperator(operator);

        await safe.enableModule(module);

        return { safe, module, creator, creator2, owner, operator }
    }

    it("setCreator", async function () {
        const { module, creator, creator2, owner, operator } = await loadFixture(deploy);

        // access
        await expect(module.connect(creator).setCreator(1, creator)).to.be.reverted;

        // operator can set if creator not set
        expect(await module.positionIdToCreator(1)).to.be.eq(ethers.ZeroAddress);
        await module.connect(operator).setCreator(1, creator);

        // only owner can set if creator already set
        expect(await module.positionIdToCreator(1)).to.be.eq(creator);
        await expect(module.connect(operator).setCreator(1, creator2))
            .to
            .be
            .revertedWithCustomError(module, "OwnableUnauthorizedAccount");
        await module.connect(owner).setCreator(1, creator2);
        expect(await module.positionIdToCreator(1)).to.be.eq(creator2);
    })

    it("setCreators", async function () {
        const { module, creator, creator2, owner } = await loadFixture(deploy);

        await module.connect(owner).setCreators([1, 2], [creator, creator2]);
        expect(await module.positionIdToCreator(1)).to.be.eq(creator);
        expect(await module.positionIdToCreator(2)).to.be.eq(creator2);
    })

    it("claim (locked)", async function () {
        const { creator, module, operator } = await loadFixture(deploy);

        const positionId = 906853;
        await module.connect(operator).setCreator(positionId, creator);

        const amountToClaim = await module.claim.staticCall(positionId);
        await expect(module.claim(positionId)).changeTokenBalance(
            await ethers.getContractAt("IERC20", await module.positionToken(positionId)),
            creator,
            amountToClaim
        );

        await expect(module.claim(positionId)).to.be.revertedWithCustomError(module, "TooEarly");
        await time.increase(await module.claimInterval());

    })

    it("claim (unlocked)", async function () {
        const { creator, module, operator } = await loadFixture(deploy);

        const positionId = 1226783;
        await module.connect(operator).setCreator(positionId, creator);

        const amountToClaim = await module.claim.staticCall(positionId);
        await expect(module.claim(positionId)).changeTokenBalance(
            await ethers.getContractAt("IERC20", await module.positionToken(positionId)),
            creator,
            amountToClaim
        );
    })

    it("claim (maxClaimAmountBps)", async function () {
        const { creator, module, operator, owner } = await loadFixture(deploy);

        const positionId = 1000532;
        await module.connect(operator).setCreator(positionId, creator);
        await module.connect(owner).changeClaimSchedule(1, 0);

        const token = await ethers.getContractAt("IERC20", await module.positionToken(positionId));

        await expect(module.claim(positionId)).changeTokenBalance(
            token,
            creator,
            await token.totalSupply() / 10_000n
        );
    })
});
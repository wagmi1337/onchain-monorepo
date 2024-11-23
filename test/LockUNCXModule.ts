import { expect } from "chai"
import { ethers } from "hardhat";
import { loadFixture, reset } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("LockUNCXModule", function () {
    this.beforeAll(async () => {
        await reset(process.env.BASE_RPC, 22667000)
    })

    async function deploy() {
        const safe = await ethers.getContractAt(
            "ISafe", "0xb0Cc739c2F7e1232408A2d4e3329fce1693f7713",
            await ethers.getImpersonatedSigner("0xb0Cc739c2F7e1232408A2d4e3329fce1693f7713")
        );
        const module = await ethers.deployContract("LockUNCXModule");
        await safe.enableModule(module);

        return { safe, module }
    }

    it("tokenPrice", async function () {
        const { module } = await loadFixture(deploy);

        // token0
        expect(await module.tokenPrice(1032401)).to.be.eq(20706558026n);

        // token1
        expect(await module.tokenPrice(458339)).to.be.eq(121129732888n);
    })

    it("lockSponsored", async function () {
        const { module } = await loadFixture(deploy);

        await expect(module.lockSponsored(1032401)).revertedWithCustomError(module, "RequirementsForSponshoripNotMet");
        await module.lockSponsored(458339);

        const nfpManager = await ethers.getContractAt("IERC721", "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1");
        expect(await nfpManager.ownerOf(458339)).to.be.eq("0x231278eDd38B00B07fBd52120CEf685B9BaEBCC1");
    })

    it("lock", async function () {
        const { module } = await loadFixture(deploy);

        await expect(module.lock(1032401)).revertedWithCustomError(module, "PaymentRequired");
        await module.lock(567033, { value: await module.lockPrice() });
        await expect(module.lock(567033, { value: await module.lockPrice() })).revertedWithCustomError(module, "BadPositionOwner");

        const nfpManager = await ethers.getContractAt("IERC721", "0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1");
        expect(await nfpManager.ownerOf(567033)).to.be.eq("0x231278eDd38B00B07fBd52120CEf685B9BaEBCC1");
        expect(await module.lockByPosition(567033)).to.be.gt(0);
    })
});
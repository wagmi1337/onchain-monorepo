import { expect } from "chai"
import { ethers, upgrades } from "hardhat";
import { loadFixture, reset } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { AeroWagmi } from "../typechain-types";

describe("AeroWagmi", function () {
    this.beforeAll(async () => {
        await reset(process.env.BASE_RPC, 21115995)
    })

    async function deploy() {
        const [owner, user] = await ethers.getSigners()

        const aeroWagmi = await upgrades.deployProxy(
            await ethers.getContractFactory("AeroWagmi"),
            [owner.address]
        ).then(c => c.waitForDeployment()) as AeroWagmi

        return { aeroWagmi, owner, user }
    }

    it("launch", async function () {
        const { aeroWagmi, user } = await loadFixture(deploy)

        const name = "Test"
        const symbol = "Test"

        const deploySalt =
            await aeroWagmi
                .connect(await ethers.getImpersonatedSigner(ethers.ZeroAddress))
                .calcDeploySalt.staticCall(name, symbol);

        const [tokenAddress, buyoutTokenAmount] = await aeroWagmi.launch.staticCall(ethers.parseEther("4000"),
            1,
            deploySalt,
            name,
            symbol,
            { value: ethers.parseEther("3") }
        );
        const token = await ethers.getContractAt("IERC20", tokenAddress);

        expect(await aeroWagmi.connect(user).launch(
            ethers.parseEther("4000"),
            1,
            deploySalt,
            name,
            symbol,
            { value: ethers.parseEther("3") }
        )).to.be.changeTokenBalance(token, user, buyoutTokenAmount);

        expect(await aeroWagmi.tokens(0)).to.be.eq(tokenAddress);
        expect((await aeroWagmi.tokenInfo(tokenAddress)).creator).to.be.eq(user.address);

    });
});
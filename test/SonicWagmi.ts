import { expect } from "chai"
import { ethers, upgrades } from "hardhat";
import { loadFixture, reset } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { SonicWagmi } from "../typechain-types";

describe("SonicWagmi", function () {
    this.beforeAll(async () => {
        await reset(process.env.SONIC_RPC, 11864000)
    })

    async function deploy() {
        const [owner, user] = await ethers.getSigners()

        const sonicWagmi = await upgrades.deployProxy(
            await ethers.getContractFactory("SonicWagmi"),
            [owner.address]
        ).then(c => c.waitForDeployment()) as SonicWagmi

        return { sonicWagmi, owner, user }
    }

    it("launch", async function () {
        const { sonicWagmi, user, owner } = await loadFixture(deploy)

        const wS = await ethers.getContractAt("IERC20", "0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38");
        const totalSupply = ethers.parseEther("1000000")
        const name = "Test"
        const symbol = "Test"

        const deploySalt =
            await sonicWagmi
                .connect(await ethers.getImpersonatedSigner(ethers.ZeroAddress))
                .calcDeploySalt.staticCall(totalSupply, name, symbol);

        const [tokenAddress, buyoutTokenAmount] = await sonicWagmi.launch.staticCall(
            -887272,
            54991,
            1,
            deploySalt,
            totalSupply,
            name,
            symbol,
            { value: ethers.parseEther("3") }
        );
        const token = await ethers.getContractAt("IERC20", tokenAddress);

        expect(await sonicWagmi.connect(user).launch(
            -887272,
            54991,
            1,
            deploySalt,
            totalSupply,
            name,
            symbol,
            { value: ethers.parseEther("3") }
        )).to.be.changeTokenBalance(token, user, buyoutTokenAmount);

        expect(await sonicWagmi.tokens(0)).to.be.eq(tokenAddress);
        //expect((await sonicWagmi.tokenInfo(tokenAddress)).creator).to.be.eq(user.address);

        const router = await ethers.getContractAt("contracts/sonic-wagmi/shadow/interfaces/ISwapRouter.sol:ISwapRouter", "0x5543c6176FEb9B4b179078205d7C29EEa2e2d695")
        await router.exactInputSingle({
            tokenIn: wS,
            tokenOut: token,
            tickSpacing: 1,
            recipient: owner.address,
            deadline: Date.now() + 1000,
            amountIn: ethers.parseEther("3"),
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        }, { value: ethers.parseEther("3") })
        await sonicWagmi.collectFee(token);

        expect(sonicWagmi.feeCollected(token, wS)).to.be.gt(0);
    });
});
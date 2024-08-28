const {
    time,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("GoldTokenV2", function () {
    async function deployGoldTokenV2Fixture() {
        const [owner, minter, upgrader, oracle, user] = await ethers.getSigners();

        // Deploy TimeLock
        const TimeLock = await ethers.getContractFactory("TimeLock");
        const timeLock = await TimeLock.deploy();
        await timeLock.waitForDeployment();

        // Deploy GoldToken V1
        const GoldToken = await ethers.getContractFactory("GoldToken");
        const goldTokenV1 = await upgrades.deployProxy(GoldToken, [owner.address, minter.address, await timeLock.getAddress(), [oracle.address]], { kind: 'uups' });
        await goldTokenV1.waitForDeployment();

        // Prepare upgrade to V2
        const GoldTokenV2 = await ethers.getContractFactory("GoldTokenContractV2");
        const newImplementation = await upgrades.prepareUpgrade(await goldTokenV1.getAddress(), GoldTokenV2);

        // Queue the upgrade transaction
        const callData = goldTokenV1.interface.encodeFunctionData("upgradeToAndCall", [newImplementation, "0x"]);
        await timeLock.connect(owner).queueTransaction(await goldTokenV1.getAddress(), 0, callData);

        // Get the queued transaction details
        const logs = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
        const [target, value, data, executionDate] = logs[0].args.slice(1);

        // Increase time to execution date
        await time.increaseTo(executionDate);

        // Execute the upgrade
        await timeLock.executeTransaction(target, value, data, executionDate);

        // Get the upgraded contract instance
        const goldTokenV2 = await ethers.getContractAt("GoldTokenContractV2", await goldTokenV1.getAddress());
  
        await goldTokenV2.connect(oracle).setMintLimitByOracle(1000000000)

        return { goldTokenV2, timeLock, owner, minter, upgrader, oracle, user };
    }

    describe("Burn", function () {
        it("Should allow owner/minter to burn tokens", async function () {
            const { goldTokenV2, owner, minter, user } = await loadFixture(deployGoldTokenV2Fixture);
            // user can't burn tokens
            await goldTokenV2.connect(minter).mint(user.address, 4000000);
            await expect(goldTokenV2.connect(user).burn(1000000)).to.be.revertedWith("unauthorized");

            // minter can burn tokens
            await goldTokenV2.connect(minter).mint(minter.address, 1000000);
            await goldTokenV2.connect(minter).burn(1000000);
            
            // minter balance should be 0
            expect(await goldTokenV2.balanceOf(minter.address)).to.equal(0);

            // owner can burn tokens
            await goldTokenV2.connect(minter).mint(owner.address, 1000000);
            await goldTokenV2.connect(owner).burn(1000000);
            expect(await goldTokenV2.balanceOf(owner.address)).to.equal(0);
        });
    });
});
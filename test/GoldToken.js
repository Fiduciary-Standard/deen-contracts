const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("GoldToken", function () {
  async function deployGoldTokenFixture() {

    const [owner, minter, upgrader, oracle] = await ethers.getSigners();

    const GoldToken = await ethers.getContractFactory("GoldToken");
    const proxy = await upgrades.deployProxy(GoldToken, [owner.address, minter.address, upgrader.address], { kind: 'uups' });
    await proxy.waitForDeployment();
    const goldToken = await ethers.getContractAt("GoldToken", proxy);

    return { goldToken, owner, minter, upgrader, oracle };
  }

  describe("Deployment", function () {
    it("Should set the right name", async function () {
      const { goldToken } = await loadFixture(deployGoldTokenFixture);

      expect(await goldToken.name()).to.equal("GoldToken");
    });

    it("Should set oracle address", async function () {
      const { goldToken, owner, minter, upgrader, oracle } = await loadFixture(deployGoldTokenFixture);

      await goldToken.connect(upgrader).setOracle(oracle.address);

      const oracles = await goldToken.getOracles();

      for (let i = 0; i < oracles.length; i++) {
        expect(oracles[i]).to.equal(oracle.address);
      }
    });

    it("Should set mint limit", async function () {
      const { goldToken, owner, minter, upgrader, oracle } = await loadFixture(deployGoldTokenFixture);

      await goldToken.connect(upgrader).setOracle(oracle.address);

      await goldToken.connect(oracle).setMintLimitByOracle(1000000);

      await goldToken.connect(minter).updateMintLimit();

      expect(await goldToken.mintLimit()).to.equal(1000000);
      const pendingMintLimit = await goldToken.getPendingMintLimit();
      expect(pendingMintLimit.length).to.equal(0);
    });

    it("Should mint tokens", async function () {
      const { goldToken, owner, minter, upgrader, oracle } = await loadFixture(deployGoldTokenFixture);

      await goldToken.connect(upgrader).setOracle(oracle.address);

      await goldToken.connect(oracle).setMintLimitByOracle(1000000);

      await goldToken.connect(minter).updateMintLimit();

      await goldToken.connect(minter).mint(owner.address, 1000000);

      expect(await goldToken.balanceOf(owner.address)).to.equal(1000000);
      expect(await goldToken.totalSupply()).to.equal(1000000);
      expect(await goldToken.mintLimit()).to.equal(0);
    });
  });
});

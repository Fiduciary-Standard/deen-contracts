const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("GoldToken", function () {
  async function deployGoldTokenFixture() {
   
    const [owner, otherAccount] = await ethers.getSigners();

    const GoldToken = await ethers.getContractFactory("GoldToken");
    const goldToken = await GoldToken.deploy(unlockTime, { value: lockedAmount });

    return { goldToken, owner, otherAccount };
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { goldToken } = await loadFixture(deployGoldTokenFixture);

      expect(await goldToken.name()).to.equal("GoldToken");
    });
  });
});

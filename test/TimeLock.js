const {
  time,
  loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("TimeLock", function () {
  async function deployTimeLockFixture() {

    const [owner, minter, upgrader, oracle, newInstance] = await ethers.getSigners();

    const GoldToken = await ethers.getContractFactory("GoldToken");
    const proxy = await upgrades.deployProxy(GoldToken, [owner.address, minter.address, upgrader.address], { kind: 'uups' });
    await proxy.waitForDeployment();
    const goldToken = await ethers.getContractAt("GoldToken", proxy);

    const TimeLock = await ethers.getContractFactory("TimeLock");
    const timeLock = await TimeLock.deploy(owner.address);

    return { goldToken, timeLock, owner, minter, upgrader, oracle, newInstance };
  }

  describe("Deployment", function () {
    it("Should set the right name", async function () {
      const { goldToken } = await loadFixture(deployTimeLockFixture);

      expect(await goldToken.name()).to.equal("GoldToken");
    });

    it("Should add oracle", async function () {
      const { goldToken, timeLock, owner, oracle } = await loadFixture(deployTimeLockFixture);

      // grant role to TimeLock
      const role = await goldToken.UPGRADER_OR_SET_ORACLE_ROLE();

      await goldToken.connect(owner).grantRole(role, await timeLock.getAddress());

      const callData = goldToken.interface.encodeFunctionData("setOracle", [oracle.address]);
      const queueTransactionTx = await timeLock.queueTransaction(await goldToken.getAddress(), 0, callData);
      await queueTransactionTx.wait();

      await expect(timeLock.queueTransaction(await goldToken.getAddress(), 0, callData))
        .to.emit(timeLock, "QueueTransaction");

      // // get logs
      const logs = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
      expect(logs.length).to.equal(2);

      const target = logs[0].args[1];
      const value = logs[0].args[2];
      const data = logs[0].args[3];
      const executionDate = logs[0].args[4];

      await time.increaseTo(executionDate);

      await expect(timeLock.executeTransaction(target, value, data, executionDate)).to.emit(timeLock, "ExecuteTransaction");

      const oracles = await goldToken.getOracles();

      expect(oracles.length).to.equal(1);

      for (let i = 0; i < oracles.length; i++) {
        expect(oracles[i]).to.equal(oracle.address);
      }
    });

    it("Should uppgrade contract", async function () {
      const { goldToken, timeLock, owner } = await loadFixture(deployTimeLockFixture);

      // grant role to TimeLock
      const role = await goldToken.UPGRADER_OR_SET_ORACLE_ROLE();

      await goldToken.connect(owner).grantRole(role, await timeLock.getAddress());

      const GoldTokenV2 = await ethers.getContractFactory("GoldTokenV2");
      const newInstance = await upgrades.prepareUpgrade(await goldToken.getAddress(), GoldTokenV2);

      const callData = goldToken.interface.encodeFunctionData("upgradeToAndCall", [newInstance, "0x"]);

      const queueTransactionTx = await timeLock.queueTransaction(await goldToken.getAddress(), 0, callData);

      await queueTransactionTx.wait();

      let logs = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
      expect(logs.length).to.equal(1);

      const target = logs[0].args[1];
      const value = logs[0].args[2];
      const data = logs[0].args[3];
      const executionDate = logs[0].args[4];

      await time.increaseTo(executionDate);

      await timeLock.executeTransaction(target, value, data, executionDate);

      const goldTokenV2 = await ethers.getContractAt("GoldTokenV2", await goldToken.getAddress());

      expect(await goldTokenV2.v2()).to.equal("v2");
    });
  });
});

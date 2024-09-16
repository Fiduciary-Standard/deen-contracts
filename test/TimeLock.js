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

    const TimeLock = await ethers.getContractFactory("TimeLock");
    const timeLock = await TimeLock.deploy();

    const GoldToken = await ethers.getContractFactory("GoldToken");
    const proxy = await upgrades.deployProxy(GoldToken, [owner.address, minter.address, await timeLock.getAddress(), []], { kind: 'uups' });
    await proxy.waitForDeployment();
    const goldToken = await ethers.getContractAt("GoldToken", proxy);

    return { goldToken, timeLock, owner, minter, upgrader, oracle, newInstance };
  }

  describe("Deployment", function () {
    it("Should set the right name", async function () {
      const { goldToken } = await loadFixture(deployTimeLockFixture);

      expect(await goldToken.name()).to.equal("Deenar");
    });

    it("Should add oracle", async function () {
      const { goldToken, timeLock, owner, oracle } = await loadFixture(deployTimeLockFixture);

      const callData = goldToken.interface.encodeFunctionData("setOracle", [oracle.address]);
      const queueTransactionTx = await timeLock.queueTransaction(await goldToken.getAddress(), callData);
      await queueTransactionTx.wait();

      await expect(timeLock.connect(oracle).queueTransaction(await goldToken.getAddress(), callData)).to.be.revertedWithCustomError(timeLock, "CallerIsNotAdmin()");

      await expect(timeLock.connect(owner).queueTransaction(await goldToken.getAddress(), callData))
        .to.emit(timeLock, "QueueTransaction");

      const logs = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
      expect(logs.length).to.equal(2);

      const target = logs[0].args[1];
      const data = logs[0].args[2];
      const executionDate = logs[0].args[3];

      await time.increaseTo(executionDate);

      await expect(timeLock.executeTransaction(target, data, executionDate)).to.emit(timeLock, "ExecuteTransaction");

      const oracles = await goldToken.getOracles();

      expect(oracles.length).to.equal(1);

      for (let i = 0; i < oracles.length; i++) {
        expect(oracles[i]).to.equal(oracle.address);
      }
    });

    it("Should upgrade contract", async function () {
      const { goldToken, timeLock, owner } = await loadFixture(deployTimeLockFixture);

      const GoldTokenV2 = await ethers.getContractFactory("GoldTokenContractV2");
      const newInstance = await upgrades.prepareUpgrade(await goldToken.getAddress(), GoldTokenV2);

      const callData = goldToken.interface.encodeFunctionData("upgradeToAndCall", [newInstance, "0x"]);

      const queueTransactionTx = await timeLock.connect(owner).queueTransaction(await goldToken.getAddress(), callData);

      await queueTransactionTx.wait();

      let logs = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
      expect(logs.length).to.equal(1);

      const target = logs[0].args[1];
      const data = logs[0].args[2];
      const executionDate = logs[0].args[3];

      await time.increaseTo(executionDate);

      await timeLock.executeTransaction(target, data, executionDate);
    });

    it("Should grant role", async function () {
      const { goldToken, timeLock, owner, minter } = await loadFixture(deployTimeLockFixture);

      const callData = goldToken.interface.encodeFunctionData("grantRole", [await goldToken.MINTER_ROLE(), await minter.getAddress()]);
      const queueTransactionTx = await timeLock.connect(owner).queueTransaction(await goldToken.getAddress(), callData);
      await queueTransactionTx.wait();

      let logs = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
      expect(logs.length).to.equal(1);

      const target = logs[0].args[1];
      const data = logs[0].args[2];
      const executionDate = logs[0].args[3];

      await time.increaseTo(executionDate);

      await timeLock.executeTransaction(target, data, executionDate);

      expect(await goldToken.hasRole(await goldToken.MINTER_ROLE(), minter.address)).to.equal(true);
    });

    it("Should revoke role", async function () {
      const { goldToken, timeLock, owner, minter } = await loadFixture(deployTimeLockFixture);

      const callDataGrantRole = goldToken.interface.encodeFunctionData("grantRole", [await goldToken.MINTER_ROLE(), await minter.getAddress()]);
      const queueTransactionTxGrantRole = await timeLock.connect(owner).queueTransaction(await goldToken.getAddress(), callDataGrantRole);
      await queueTransactionTxGrantRole.wait();

      let logsGrantRole = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
      expect(logsGrantRole.length).to.equal(1);

      const targetGrantRole = logsGrantRole[0].args[1];
      const dataGrantRole = logsGrantRole[0].args[2];
      const executionDateGrantRole = logsGrantRole[0].args[3];

      await time.increaseTo(executionDateGrantRole);

      await timeLock.executeTransaction(targetGrantRole, dataGrantRole, executionDateGrantRole);

      expect(await goldToken.hasRole(await goldToken.MINTER_ROLE(), minter.address)).to.equal(true);

      const callData = goldToken.interface.encodeFunctionData("revokeRole", [await goldToken.MINTER_ROLE(), await minter.getAddress()]);
      const queueTransactionTx = await timeLock.connect(owner).queueTransaction(await goldToken.getAddress(), callData);
      await queueTransactionTx.wait();

      const logs = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
      expect(logs.length).to.equal(2);

      const target = logs[1].args[1];
      const data = logs[1].args[2];
      const executionDate = logs[1].args[3];

      await time.increaseTo(executionDate);

      await timeLock.executeTransaction(target, data, executionDate);

      expect(await goldToken.hasRole(await goldToken.MINTER_ROLE(), minter.address)).to.equal(false);
    });

    it("Should cancel transaction", async function () {
      const { goldToken, timeLock, owner, minter } = await loadFixture(deployTimeLockFixture);

      const callData = goldToken.interface.encodeFunctionData("grantRole", [await goldToken.MINTER_ROLE(), await minter.getAddress()]);
      const queueTransactionTx = await timeLock.connect(owner).queueTransaction(await goldToken.getAddress(), callData);
      await queueTransactionTx.wait();

      const logs = await timeLock.queryFilter(timeLock.filters.QueueTransaction());
      expect(logs.length).to.equal(1);

      const target = logs[0].args[1];
      const data = logs[0].args[2];
      const executionDate = logs[0].args[3];

      await expect(timeLock.connect(owner).cancelTransaction(target, data, executionDate))
        .to.emit(timeLock, "CancelTransaction");
    });
  });
});

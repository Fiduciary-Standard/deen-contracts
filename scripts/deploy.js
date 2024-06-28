const { ethers, upgrades } = require("hardhat");

async function main() {
    // deployer address
    const [deployer] = await ethers.getSigners();
    console.log('Deploying contracts with the account:', deployer.address);
    const GoldToken = await ethers.getContractFactory('GoldToken');
    const defaultAdmin = "0xb32D92ce87a0Ab4B5F69adF7af6629fD1f9cba32";
    const minter = "0xb32D92ce87a0Ab4B5F69adF7af6629fD1f9cba32";
    const oracles = ["0xb3f363A9375F340d3482AF63e397749B001d057E"];

    const TimeLock = await ethers.getContractFactory("TimeLock");
    const timeLock = await TimeLock.deploy();

    console.log("TimeLock deployed to:", await timeLock.getAddress());

    const proxy = await upgrades.deployProxy(GoldToken, [defaultAdmin, minter, await timeLock.getAddress(), oracles], {kind: 'uups'});
    await proxy.waitForDeployment();
    console.log("GoldToken deployed to:", await proxy.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
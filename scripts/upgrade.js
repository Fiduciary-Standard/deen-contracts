const { ethers, upgrades } = require("hardhat");

async function main() {
    // deployer address
    const [deployer] = await ethers.getSigners();
    console.log('Deploying contracts with the account:', deployer.address);
    const GoldToken = await ethers.getContractFactory('GoldToken');

    await upgrades.upgradeProxy('0x4FEBDDe47Ab9a76200e57eFcC80b212a07b3e6cE', GoldToken);
    console.log("ok");
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
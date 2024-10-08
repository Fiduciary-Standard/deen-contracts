const { ethers, upgrades } = require("hardhat");

async function main() {
    // deployer address
    const [deployer] = await ethers.getSigners();
    console.log('Deploying contracts with the account:', deployer.address);
    const GoldTokenContractV2 = await ethers.getContractFactory('GoldTokenContractV2');

    const implAddress = await upgrades.prepareUpgrade('0x4FEBDDe47Ab9a76200e57eFcC80b212a07b3e6cE', GoldTokenContractV2, {kind: 'uups'});
    console.log("Implementation contract address:", implAddress);
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
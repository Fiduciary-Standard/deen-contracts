const { ethers, upgrades } = require("hardhat");

async function main() {
    // deployer address
    const [deployer] = await ethers.getSigners();
    console.log('Deploying contracts with the account:', deployer.address);

    const TimeLock = await ethers.getContractFactory("TimeLock");
    const timeLock = await TimeLock.deploy();

    console.log("TimeLock deployed to:", await timeLock.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
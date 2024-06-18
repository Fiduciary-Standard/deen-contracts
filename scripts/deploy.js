const { ethers, upgrades } = require("hardhat");

async function main() {
    // deployer address
    const [deployer] = await ethers.getSigners();
    console.log('Deploying contracts with the account:', deployer.address);
    const GoldToken = await ethers.getContractFactory('GoldToken');
    const defaultAdmin = "0x6416683f10E14b45319Bd6E0f4e86E51252cc007";
    const minter = "0x6416683f10E14b45319Bd6E0f4e86E51252cc007";
    const upgrader = "0x6416683f10E14b45319Bd6E0f4e86E51252cc007";

    const proxy = await upgrades.deployProxy(GoldToken, [defaultAdmin, minter, upgrader], {kind: 'uups'});
    await proxy.waitForDeployment();
    console.log("GoldToken deployed to:", await proxy.getAddress());
}

main()
    .then(() => process.exit(0))
    .catch(error => {
        console.error(error);
        process.exit(1);
    });
require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

const {vars} = require("hardhat/config");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.24",
  networks: {
    haqqMainnet: {
      url: `https://rpc.eth.haqq.network`,
      chainId: 11235,
      accounts: [PRIVATE_KEY],
    },
    haqqTestnet: {
      url: `https://rpc.eth.testedge2.haqq.network/`,
      chainId: 54211,
      accounts: [PRIVATE_KEY],
    },
  }
};

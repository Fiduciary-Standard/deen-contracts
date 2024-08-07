require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');

const { vars } = require("hardhat/config");
const PRIVATE_KEY = vars.get("PRIVATE_KEY");
require("@nomicfoundation/hardhat-verify");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.26",
    settings: {
      viaIR: true,
    }
  },
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
  },
  etherscan: {
    apiKey: {
      // Is not required by blockscout. Can be any non-empty string
      haqqMainnet: "a"
    },
    customChains: [
      {
        network: "haqqMainnet",
        chainId: 11235,
        urls: {
          apiURL: "https://explorer.haqq.network/api/",
          browserURL: "https://explorer.haqq.network/",
        }
      }
    ]
  },
  sourcify: {
    enabled: false
  }
};

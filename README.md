# Deenar Token

## Overview

A classic ERC20 smart contract with mintable features, upgradeable through a timelock smartcontract, and a token precision of 6 decimals. Minting can only be performed by addresses holding the roles.

Token backed by real gold -> 1 DEEN = 1 gram of gold.

### Roles
* **MINTER_ROLE** - Wallets with this role can mint tokens within the limits authorized by Oracles.
* **TIME_LOCKER_ROLE** - This role is assigned to the timelocker smart contract.
* **ORACLE_ROLE** - Assigned to Oracles, all holders of this role can set the minting limit.
* **DEFAULT_ADMIN_ROLE** - The contract admin.

### Timelocker

* All roles are updateable through the timelocker.
* The timelocker inherits the DEFAULT_ADMIN_ROLE from the main contract.

### Oracle

* The limit on the number of tokens available for minting is set by independent Oracles holding the ORACLE_ROLE.
* Oracles obtain information on the balance of physical gold—number of bars, their weight—and set the maximum minting limit in the smart contract.
* The number of Oracles is unlimited.
* If the values set by the Oracles differ, the minimum allowable value is used.
* An Oracle can only be revoked through the timelocker.

## Build

Try running some of the following tasks:

```shell
npx hardhat help
npx hardhat test
REPORT_GAS=true npx hardhat test
npx hardhat node
npx hardhat run ./scripts/deploy.js --network ....
```

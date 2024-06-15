// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract GoldToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    uint256 public mintLimit; // Maximum amount of tokens that can be minted
    uint256[] public pendingMintLimit; // Amount of tokens that can be added to mintLimit after oracles approve
    address[] public oracles; // List of oracle addresses
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    event MintLimitUpdated(uint256 newLimit);
    event OracleAdded(address newOracle);
    event OracleRemoved(address removedOracle);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address defaultAdmin, // Owner grant roles
        address minter, // Admin
        address upgrader // timeLock contract
    ) public initializer {
        __ERC20_init("GoldToken", "GTK");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(UPGRADER_ROLE, upgrader); // TimeLock smart contract
    }
    
    function setOracle(address newOracles) external onlyRole(UPGRADER_ROLE) {
        require(newOracles != address(0), "Zero address");
        oracles.push(newOracles);
        _grantRole(ORACLE_ROLE, newOracles);
        emit OracleAdded(newOracles);
    }

    function removeOracle(address oracleAddress) external onlyRole(UPGRADER_ROLE) {
        require(oracleAddress != address(0), "Zero address");
        for (uint i = 0; i < oracles.length; i++) {
            if (oracles[i] == oracleAddress) {
                oracles[i] = oracles[oracles.length - 1];
                oracles.pop();
                _revokeRole(ORACLE_ROLE, oracleAddress);
                emit OracleRemoved(oracleAddress);
                break;
            }
        }
    }

    function setMintLimitByOracle(
        uint256 newLimit
    ) public onlyRole(ORACLE_ROLE) {
        require(newLimit > 0, "Zero limit");
        pendingMintLimit.push(newLimit);
    }

    //  after all oracles approve, update mintLimit
    function updateMintLimit() public onlyRole(MINTER_ROLE) {
        uint minimumLimit;
        require(
            pendingMintLimit.length == oracles.length,
            "Not enough oracles"
        );
        for (uint i = 0; i < pendingMintLimit.length; i++) {
            //  find the minimum limit
            if (minimumLimit > pendingMintLimit[i]) {
                minimumLimit = pendingMintLimit[i];
            }
        }
        mintLimit += minimumLimit; // update mintLimit
        // clean pendingMintLimit
        delete pendingMintLimit;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(amount + mintLimit <= mintLimit, "Amount exceeds mint limit");
        mintLimit -= amount;
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_ROLE) {}
}

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.26;

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
    error ErrorZeroAddress();
    error ErrorZeroLimit();
    error ErrorNotEnoughOracles();
    error ErrorOracleAlreadyAdded();
    error ErrorOracleNotFound();
    error ErrorAmountExceedsMintLimit();

    uint256 public mintLimit; // Maximum amount of tokens that can be minted
    uint256[] public pendingMintLimit; // Amount of tokens that can be added to mintLimit after oracles approve
    address[] public oracles; // List of oracle addresses
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant UPGRADER_OR_SET_ORACLE_ROLE =
        keccak256("UPGRADER_OR_SET_ORACLE_ROLE");
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
        _grantRole(UPGRADER_OR_SET_ORACLE_ROLE, upgrader); // TimeLock smart contract
    }

    function setOracle(
        address newOracle
    ) external onlyRole(UPGRADER_OR_SET_ORACLE_ROLE) {
        require(newOracle != address(0), ErrorZeroAddress());
        if (oracles.length == 0) {
            oracles.push(newOracle);
            _grantRole(ORACLE_ROLE, newOracle);
            emit OracleAdded(newOracle);
        } else {
            for (uint i = 0; i < oracles.length; i++) {
                require(oracles[i] != newOracle, ErrorOracleAlreadyAdded());
                oracles.push(newOracle);
                _grantRole(ORACLE_ROLE, newOracle);
                emit OracleAdded(newOracle);
            }
        }
    }

    function removeOracle(
        address oracleAddress
    ) external onlyRole(UPGRADER_OR_SET_ORACLE_ROLE) {
        require(oracleAddress != address(0), ErrorZeroAddress());
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
        require(newLimit > 0, ErrorZeroLimit());
        pendingMintLimit.push(newLimit);
    }

    //  after all oracles approve, update mintLimit
    function updateMintLimit() public onlyRole(MINTER_ROLE) {
        uint minimumLimit;
        require(
            pendingMintLimit.length == oracles.length,
            ErrorNotEnoughOracles()
        );
        for (uint i = 0; i < pendingMintLimit.length; i++) {
            //  find the minimum limit
            if (i == 0) {
                minimumLimit = pendingMintLimit[i];
            } else {
                if (pendingMintLimit[i] < minimumLimit) {
                    minimumLimit = pendingMintLimit[i];
                }
            }
        }
        mintLimit += minimumLimit; // update mintLimit
        // clean pendingMintLimit
        delete pendingMintLimit;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(amount <= mintLimit, ErrorAmountExceedsMintLimit());
        _mint(to, amount);
        mintLimit -= amount;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function getOracles() view external returns (address[] memory) {
        return oracles;
    }

    function getPendingMintLimit() view external returns (uint256[] memory) {
        return pendingMintLimit;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(UPGRADER_OR_SET_ORACLE_ROLE) {}
}

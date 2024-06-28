// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

error ErrorZeroAddress();
error ErrorZeroLimit();
error ErrorNotEnoughOracles();
error ErrorOracleAlreadyAdded();
error ErrorOracleNotFound();
error ErrorAmountExceedsMintLimit();

contract GoldToken is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    address[] public oracles; // List of oracle addresses
    mapping(address => uint256) public oracleMintLimit; // Amount of tokens set by each oracle
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TIME_LOCKER_ROLE = keccak256("TIME_LOCKER_ROLE");
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
        address upgrader, // timeLock contract
        address[] memory _oracles
    ) public initializer {
        __ERC20_init("Deenar", "DEEN");
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(TIME_LOCKER_ROLE, upgrader);

        for (uint i = 0; i < _oracles.length; i++) {
            oracles.push(_oracles[i]);
            _grantRole(ORACLE_ROLE, _oracles[i]);
        }
    }

    function setOracle(address newOracle) external onlyRole(TIME_LOCKER_ROLE) {
        require(newOracle != address(0), ErrorZeroAddress());
        if (oracles.length == 0) {
            oracles.push(newOracle);
            _grantRole(ORACLE_ROLE, newOracle);
            emit OracleAdded(newOracle);
        } else {
            for (uint i = 0; i < oracles.length; i++) {
                if (oracles[i] == newOracle) {
                    revert("Oracle already added");
                }
            }
            oracles.push(newOracle);
            _grantRole(ORACLE_ROLE, newOracle);
            emit OracleAdded(newOracle);
        }
    }

    function removeOracle(
        address oracleAddress
    ) external onlyRole(TIME_LOCKER_ROLE) {
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
        oracleMintLimit[msg.sender] = newLimit;
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(
            amount + totalSupply() <= getMintLimit(),
            ErrorAmountExceedsMintLimit()
        );
        _mint(to, amount);
    }

    function getMintLimit() public view returns (uint256) {
        if (oracles.length == 0) {
            return 0;
        }

        uint256 mintLimit = type(uint256).max;

        for (uint i = 0; i < oracles.length; i++) {
            uint256 oracleLimit = oracleMintLimit[oracles[i]];
            if (oracleLimit < mintLimit) {
                mintLimit = oracleLimit;
            }
        }

        return mintLimit;
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function getOracles() external view returns (address[] memory) {
        return oracles;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(TIME_LOCKER_ROLE) {}

    function grantRole(
        bytes32 role,
        address account
    ) public override onlyRole(TIME_LOCKER_ROLE) {
        _grantRole(role, account);
    }

    function revokeRole(
        bytes32 role,
        address account
    ) public override onlyRole(TIME_LOCKER_ROLE) {
        _revokeRole(role, account);
    }
}

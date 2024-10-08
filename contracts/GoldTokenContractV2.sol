// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.26;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @notice Error thrown when a zero address is provided where a non-zero address is required
error ErrorZeroAddress();
/// @notice Error thrown when a zero limit is set
error ErrorZeroLimit();
/// @notice Error thrown when there are not enough oracles (reserved for future logic upgrade)
error ErrorNotEnoughOracles();
/// @notice Error thrown when attempting to add an oracle that already exists
error ErrorOracleAlreadyAdded();
/// @notice Error thrown when attempting to remove a non-existent oracle
error ErrorOracleNotFound();
/// @notice Error thrown when a mint amount exceeds the current limit
error ErrorAmountExceedsMintLimit();

/// @title GoldTokenContractV2
/// @notice This contract implements an upgradeable ERC20 token with role-based access control and oracle-based mint limits
contract GoldTokenContractV2 is
    Initializable,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    /// @notice List of oracle addresses
    address[] public oracles;
    /// @notice Mapping of oracle addresses to their set mint limits
    mapping(address => uint256) public oracleMintLimit;

    /// @notice Role identifier for minters
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    /// @notice Role identifier for time lockers (upgrade controllers)
    bytes32 public constant TIME_LOCKER_ROLE = keccak256("TIME_LOCKER_ROLE");
    /// @notice Role identifier for oracles
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");

    /// @notice Emitted when a new mint limit is set by an oracle
    /// @param newLimit The new mint limit
    /// @param oracle The address of the oracle that set the new limit
    event MintLimitUpdated(uint256 newLimit, address oracle);
    /// @notice Emitted when a new oracle is added
    /// @param newOracle The address of the newly added oracle
    event OracleAdded(address newOracle);
    /// @notice Emitted when an oracle is removed
    /// @param removedOracle The address of the removed oracle
    event OracleRemoved(address removedOracle);

    /// @notice Disables initialization of the implementation contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Adds a new oracle
    /// @param newOracle Address of the new oracle to add
    function setOracle(address newOracle) external onlyRole(TIME_LOCKER_ROLE) {
        require(newOracle != address(0), ErrorZeroAddress());
        if (oracles.length == 0) {
            oracles.push(newOracle);
            _grantRole(ORACLE_ROLE, newOracle);
            emit OracleAdded(newOracle);
        } else {
            for (uint i = 0; i < oracles.length; i++) {
                require(oracles[i] != newOracle, ErrorOracleAlreadyAdded());
            }
            oracles.push(newOracle);
            _grantRole(ORACLE_ROLE, newOracle);
            emit OracleAdded(newOracle);
        }
    }

    /// @notice Removes an oracle
    /// @param oracleAddress Address of the oracle to remove
    function removeOracle(
        address oracleAddress
    ) external onlyRole(TIME_LOCKER_ROLE) {
        require(oracleAddress != address(0), ErrorZeroAddress());
        bool oracleFound = false;
        for (uint i = 0; i < oracles.length; i++) {
            if (oracles[i] == oracleAddress) {
                oracles[i] = oracles[oracles.length - 1];
                oracles.pop();
                _revokeRole(ORACLE_ROLE, oracleAddress);
                emit OracleRemoved(oracleAddress);
                oracleFound = true;
                break;
            }
        }
        if (!oracleFound) {
            revert ErrorOracleNotFound();
        }
    }

    /// @notice Sets the mint limit for the calling oracle
    /// @param newLimit The new mint limit to set
    function setMintLimitByOracle(
        uint256 newLimit
    ) public onlyRole(ORACLE_ROLE) {
        require(newLimit > 0, ErrorZeroLimit());
        oracleMintLimit[msg.sender] = newLimit;
        emit MintLimitUpdated(newLimit, msg.sender);
    }

    /// @notice Mints new tokens
    /// @param to Address to mint tokens to
    /// @param amount Amount of tokens to mint
    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        require(
            totalSupply() + amount <= getMintLimit(),
            ErrorAmountExceedsMintLimit()
        );
        _mint(to, amount);
    }

    /// @notice Gets the current mint limit
    /// @return mintLimit The current mint limit (lowest limit set by any oracle)
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

    /// @notice Returns the number of decimals used to get its user representation
    /// @return The number of decimals
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Gets the list of current oracles
    /// @return An array of oracle addresses
    function getOracles() external view returns (address[] memory) {
        return oracles;
    }

    /// @notice Grants a role to an account
    /// @param role The role to grant
    /// @param account The account to receive the new role
    function grantRole(
        bytes32 role,
        address account
    ) public override onlyRole(TIME_LOCKER_ROLE) {
        _grantRole(role, account);
    }

    /// @notice Revokes a role from an account
    /// @param role The role to revoke
    /// @param account The account to revoke the role from
    function revokeRole(
        bytes32 role,
        address account
    ) public override onlyRole(TIME_LOCKER_ROLE) {
        _revokeRole(role, account);
    }

    /// @notice Function that should revert when `msg.sender` is not authorized to upgrade the contract
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyRole(TIME_LOCKER_ROLE) {}

    /// @notice Burns tokens from the caller's balance
    /// @param amount The amount of tokens to burn
    function burn(uint256 amount) public {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()) ||
                hasRole(MINTER_ROLE, _msgSender()),
            "unauthorized"
        );
        _burn(_msgSender(), amount);
    }
}

// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";

/// @notice Error thrown when the caller is not an admin
error CallerIsNotAdmin();
/// @notice Error thrown when the caller is not a canceller
error CallerIsNotCanceller();
/// @notice Error thrown when trying to execute a transaction that is not queued
error TransactionNotQueued();
/// @notice Error thrown when trying to execute a transaction before its execution time
error TimeNotReached();
/// @notice Error thrown when a transaction execution fails
error TransactionFailed();

/// @title TimeLock
/// @notice A contract that implements a time-locked execution mechanism for transactions
/// @dev Inherits from OpenZeppelin's AccessControl for role-based access control
contract TimeLock is AccessControl {
    /// @notice The delay period before a queued transaction can be executed
    uint256 public immutable EXECUTION_DELAY;
    
    /// @notice Mapping to track queued transactions
    /// @dev The key is the hash of the transaction details, and the value is a boolean indicating if it's queued
    mapping(bytes32 => bool) public executionQueue;

    /// @notice Role identifier for cancellers
    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    /// @notice Emitted when a transaction is queued
    /// @param txnHash The hash of the transaction details
    /// @param target The address of the contract to be called
    /// @param value The amount of Ether to be sent with the transaction
    /// @param data The calldata of the transaction
    /// @param executionDate The timestamp after which the transaction can be executed
    event QueueTransaction(
        bytes32 indexed txnHash,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executionDate
    );

    /// @notice Emitted when a transaction is executed
    /// @param txnHash The hash of the transaction details
    /// @param target The address of the contract called
    /// @param value The amount of Ether sent with the transaction
    /// @param data The calldata of the transaction
    /// @param executionDate The timestamp after which the transaction was executed
    event ExecuteTransaction(
        bytes32 indexed txnHash,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executionDate
    );

    /// @notice Emitted when a transaction is cancelled
    /// @param txnHash The hash of the cancelled transaction details
    event CancelTransaction(bytes32 indexed txnHash);

    /// @notice Initializes the contract, setting the execution delay and granting roles
    constructor() {
        EXECUTION_DELAY = 3 days;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CANCELLER_ROLE, msg.sender);
    }

    /// @notice Modifier to ensure the caller is an admin of the target contract
    /// @param contractAddress The address of the contract to check admin rights on
    modifier onlyAdmin(address contractAddress) {
        AccessControl ac = AccessControl(contractAddress);
        require(
            ac.hasRole(ac.DEFAULT_ADMIN_ROLE(), msg.sender),
            CallerIsNotAdmin()
        );
        _;
    }

    /// @notice Queues a transaction for later execution
    /// @param target The address of the contract to be called
    /// @param value The amount of Ether to be sent with the transaction
    /// @param data The calldata of the transaction
    function queueTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) external onlyAdmin(target) {
        bytes32 txnHash = keccak256(
            abi.encode(target, value, data, block.timestamp + EXECUTION_DELAY)
        );
        executionQueue[txnHash] = true;
        emit QueueTransaction(
            txnHash,
            target,
            value,
            data,
            block.timestamp + EXECUTION_DELAY
        );
    }

    /// @notice Executes a previously queued transaction
    /// @param target The address of the contract to be called
    /// @param data The calldata of the transaction
    /// @param executionDate The timestamp after which the transaction can be executed
    function executeTransaction(
        address target,
        bytes memory data,
        uint256 executionDate
    ) external {
        bytes32 txnHash = keccak256(abi.encode(target, 0, data, executionDate));
        require(executionQueue[txnHash], TransactionNotQueued());
        require(block.timestamp >= executionDate, TimeNotReached());
        executionQueue[txnHash] = false;
        (bool success, ) = target.call{value: 0}(data);
        require(success, TransactionFailed());
        emit ExecuteTransaction(txnHash, target, 0, data, executionDate);
    }

    /// @notice Cancels a previously queued transaction
    /// @param target The address of the contract to be called
    /// @param value The amount of Ether to be sent with the transaction
    /// @param data The calldata of the transaction
    /// @param executionDate The timestamp after which the transaction can be executed
    function cancelTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 executionDate
    ) external onlyRole(CANCELLER_ROLE) {
        bytes32 txnHash = keccak256(
            abi.encode(target, value, data, executionDate)
        );
        require(executionQueue[txnHash], TransactionNotQueued());
        executionQueue[txnHash] = false;
        emit CancelTransaction(txnHash);
    }
}

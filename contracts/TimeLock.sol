// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";

error CallerIsNotAdmin();
error CallerIsNotCanceller();
error TransactionNotQueued();
error TimeNotReached();
error TransactionFailed();

import "hardhat/console.sol";

contract TimeLock is AccessControl {
    uint256 public immutable EXECUTION_DELAY;
    mapping(bytes32 => bool) public executionQueue;

    bytes32 public constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");

    event QueueTransaction(
        bytes32 indexed txnHash,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executionDate
    );

    event ExecuteTransaction(
        bytes32 indexed txnHash,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 executionDate
    );

    event CancelTransaction(bytes32 indexed txnHash);

    constructor() {
        EXECUTION_DELAY = 3 days;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(CANCELLER_ROLE, msg.sender);
    }

    modifier onlyAdmin(address contractAddress) {
        AccessControl ac = AccessControl(contractAddress);
        require(
            ac.hasRole(ac.DEFAULT_ADMIN_ROLE(), msg.sender),
            CallerIsNotAdmin()
        );
        _;
    }

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

    function executeTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 executionDate
    ) external {
        bytes32 txnHash = keccak256(abi.encode(target, value, data, executionDate));
        require(executionQueue[txnHash], TransactionNotQueued());
        require(block.timestamp >= executionDate, TimeNotReached());
        executionQueue[txnHash] = false;
        (bool success, ) = target.call{value: value}(data);
        require(success, TransactionFailed());
        emit ExecuteTransaction(txnHash, target, value, data, executionDate);
    }

    function cancelTransaction(
        address target,
        uint256 value,
        bytes memory data,
        uint256 executionDate
    ) external onlyRole(CANCELLER_ROLE) {
        bytes32 txnHash = keccak256(abi.encode(target, value, data, executionDate));
        require(executionQueue[txnHash], TransactionNotQueued());
        executionQueue[txnHash] = false;
        emit CancelTransaction(txnHash);
    }
}
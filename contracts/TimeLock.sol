// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.26;

import "@openzeppelin/contracts/access/AccessControl.sol";

error CallerIsNotAdmin();
error TransactionNotQueued();
error TimeNotReached();
error TransactionFailed();

contract TimeLock {
    uint256 public EXECUTION_DELAY;
    mapping(bytes32 => bool) public executionQueue;

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

    modifier onlyAdmin(address contractAddress) {
        AccessControl ac = AccessControl(contractAddress);
        require(
            ac.hasRole(ac.DEFAULT_ADMIN_ROLE(), msg.sender),
            CallerIsNotAdmin()
        );
        _;
    }

    constructor() {
        EXECUTION_DELAY = 3 days;
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

}

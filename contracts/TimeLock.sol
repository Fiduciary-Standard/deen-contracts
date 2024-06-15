// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.0.0
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract TimeLock is Ownable {
    uint256 public EXECUTION_DELAY;
    mapping(bytes32 => bool) public executionQueue;

    event QueueTransaction(
        bytes32 indexed txnHash,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 timestamp
    );

    event ExecuteTransaction(
        bytes32 indexed txnHash,
        address indexed target,
        uint256 value,
        bytes data,
        uint256 timestamp
    );

    constructor(address initialOwner) Ownable(initialOwner) {
        EXECUTION_DELAY = 1 days;
    }

    function queueTransaction(
        address target,
        uint256 value,
        bytes memory data
    ) external {
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
        uint256 timestamp
    ) external {
        bytes32 txnHash = keccak256(abi.encode(target, value, data, timestamp));
        require(executionQueue[txnHash], "Transaction not queued");
        require(block.timestamp >= timestamp, "Time not yet reached");
        executionQueue[txnHash] = false;
        (bool success, ) = target.call{value: value}(data);
        require(success, "Transaction failed");
        emit ExecuteTransaction(txnHash, target, value, data, timestamp);
    }

    function updateDelay(uint256 newDelay) external onlyOwner {
        require(newDelay > 0, "Delay must be greater than 0");
        EXECUTION_DELAY = newDelay;
    }
}

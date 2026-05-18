// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

/// @title Standard structure for passing around EVM-style log record data.
struct LogRecord {
    uint256 chain_id;
    address _contract;
    uint256 topic_0;
    uint256 topic_1;
    uint256 topic_2;
    uint256 topic_3;
    bytes data;
    uint256 block_number;
    uint256 op_code;
    uint256 block_hash;
    uint256 tx_hash;
    uint256 log_index;
}

/// @title Interface for reactive contracts.
interface IReactive {
    /// @notice Entry point for handling new event notifications.
    /// @param log Data structure containing the information about the intercepted log record.
    function react(LogRecord calldata log) external;
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { AbstractERC1967Upgradeable } from "./AbstractERC1967Upgradeable.sol";

/**
 * @title A base contract implementing emission of events signaling subscription changes requested by reactive contracts.
 */
abstract contract AbstractSubscriptionService is ISystemContract, AbstractERC1967Upgradeable {
    /// @notice An event requesting a new subscription from the network.
    event Subscribe (
        address indexed subscriber,
        uint256 indexed chain_id,
        address indexed _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    );

    /// @notice An event requesting the removal of an existing subscription.
    event Unsubscribe (
        address indexed subscriber,
        uint256 indexed chain_id,
        address indexed _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    );

    /// @notice Arbitrarily chosen value set aside for indicating a wildcard match on a given topic.
    uint256 public constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    /// @notice Subscribes the calling contract to receive events matching the criteria specified.
    /// @param chain_id EIP155 source chain ID for the event (as a `uint256`), or `0` for all chains.
    /// @param _contract Contract address to monitor, or `0` for all contracts.
    /// @param topic_0 Topic 0 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic_1 Topic 1 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic_2 Topic 2 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic_3 Topic 3 to monitor, or `REACTIVE_IGNORE` for all topics.
    function subscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) public virtual override onlyProxied {
        emit Subscribe(msg.sender, chain_id, _contract, topic_0, topic_1, topic_2, topic_3);
    }

    /// @notice Removes active subscription of the calling contract, matching the criteria specified, if one exists.
    /// @param chain_id Chain ID criterion of the original subscription.
    /// @param _contract Contract address criterion of the original subscription.
    /// @param topic_0 Topic 0 criterion of the original subscription.
    /// @param topic_1 Topic 0 criterion of the original subscription.
    /// @param topic_2 Topic 0 criterion of the original subscription.
    /// @param topic_3 Topic 0 criterion of the original subscription.
    function unsubscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) public virtual override onlyProxied {
        emit Unsubscribe(msg.sender, chain_id, _contract, topic_0, topic_1, topic_2, topic_3);
    }
}

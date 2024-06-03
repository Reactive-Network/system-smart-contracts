// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import './ISubscriptionService.sol';
import './IReactive.sol';

contract SubscriptionService is ISubscriptionService {
    struct Filter {
        // `true` in case this record has been touched by `subscribe()`.
        bool initialized;
        // List of subscribing contract addresses (unordered, may contain duplicates).
        address[] subscribers;
        // Filter mapping for partial criteria matches.
        mapping(uint256 => Filter) conditional_subscribers;
    }

    // Arbitrarily chosen value set aside for indicating a wildcard match on a given topic.
    uint256 private constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    // Number of filtering criteria supported.
    uint8 private constant NUM_OF_CRITERIA = 6;

    // Recursive data structure for keeping track of subscribers.
    mapping(uint256 => Filter) public subscriptions;

    // @notice Subscribes the calling contract to receive events matching the criteria specified.
    // @param chain_id EIP155 source chain ID for the event (as a `uint256`), or `0` for all chains.
    // @param _contract Contract address to monitor, or `0` for all contracts.
    // @param topic_0 Topic 0 to monitor, or `REACTIVE_IGNORE` for all topics.
    // @param topic_1 Topic 1 to monitor, or `REACTIVE_IGNORE` for all topics.
    // @param topic_2 Topic 2 to monitor, or `REACTIVE_IGNORE` for all topics.
    // @param topic_3 Topic 3 to monitor, or `REACTIVE_IGNORE` for all topics.
    // @dev At least one of criteria above must be non-`REACTIVE_IGNORE`.
    // @dev Will allow duplicate or overlapping subscriptions, clients must ensure idempotency.
    function subscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) external {
        uint256[NUM_OF_CRITERIA] memory criteria = [
            chain_id == 0 ? REACTIVE_IGNORE : chain_id,
            uint256(uint160(_contract)) == 0 ? REACTIVE_IGNORE : uint256(uint160(_contract)),
            topic_0,
            topic_1,
            topic_2,
            topic_3
        ];
        int8 last_non_zero = computeLastNonZeroCriterion(criteria);
        mapping(uint256 => Filter) storage map = subscriptions;
        for (uint256 index = 0; index <= uint8(last_non_zero); ++index) {
            Filter storage filter = map[criteria[index]];
            filter.initialized = true;
            if (index == uint8(last_non_zero)) {
                filter.subscribers.push(msg.sender);
            } else {
                map = filter.conditional_subscribers;
            }
        }
    }

    // @notice Removes active subscription of the calling contract, matching the criteria specified, if one exists.
    // @param chain_id Chain ID criterion of the original subscription.
    // @param _contract Contract address criterion of the original subscription.
    // @param topic_0 Topic 0 criterion of the original subscription.
    // @param topic_1 Topic 0 criterion of the original subscription.
    // @param topic_2 Topic 0 criterion of the original subscription.
    // @param topic_3 Topic 0 criterion of the original subscription.
    // @dev This is very expensive.
    function unsubscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) external {
        uint256[NUM_OF_CRITERIA] memory criteria = [
            chain_id == 0 ? REACTIVE_IGNORE : chain_id,
            uint256(uint160(_contract)) == 0 ? REACTIVE_IGNORE : uint256(uint160(_contract)),
            topic_0,
            topic_1,
            topic_2,
            topic_3
        ];
        int8 last_non_zero = computeLastNonZeroCriterion(criteria);
        mapping(uint256 => Filter) storage map = subscriptions;
        for (uint256 index = 0; index <= uint8(last_non_zero); ++index) {
            Filter storage filter = map[criteria[index]];
            require(filter.initialized, 'NS');
            // We do not try optimize storage by removing `initialized` flag from empty records on unsubscription.
            // Checking for this would be too expensive.
            if (index == uint8(last_non_zero)) {
                address[] memory updated_subscribers = new address[](filter.subscribers.length);
                uint256 updated_length = 0;
                for (uint256 subscriber_index = 0; subscriber_index != filter.subscribers.length; ++subscriber_index) {
                    if (filter.subscribers[subscriber_index] != msg.sender) {
                        updated_subscribers[updated_length++] = filter.subscribers[subscriber_index];
                    }
                }
                while (filter.subscribers.length > 0) {
                    filter.subscribers.pop();
                }
                for (uint256 updated_index = 0; updated_index != updated_length; ++updated_index) {
                    filter.subscribers.push(updated_subscribers[updated_index]);
                }
            } else {
                map = filter.conditional_subscribers;
            }
        }
    }

    // @notice Finds all subscribers matching the specified search criteria.
    // @param chain_id EIP155 source chain ID for the event (as a `uint256`).
    // @param _contract Address of the originating contract for the received event.
    // @param topic_0 Topic 0 of the event (or `0` for `LOG0`).
    // @param topic_1 Topic 1 of the event (or `0` for `LOG0` and `LOG1`).
    // @param topic_2 Topic 2 of the event (or `0` for `LOG0` .. `LOG2`).
    // @param topic_3 Topic 3 of the event (or `0` for `LOG0` .. `LOG3`).
    function findSubscribers(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) external view returns (
        uint256 results,
        address[] memory subscribers
    ) {
        uint256[NUM_OF_CRITERIA] memory criteria = [
            chain_id,
            uint256(uint160(_contract)),
            topic_0,
            topic_1,
            topic_2,
            topic_3
        ];
        results = findSubscribersRecursively(
            subscriptions,
            criteria,
            0,
            false,
            subscribers,
            0
        );
        subscribers = new address[](results);
        findSubscribersRecursively(
            subscriptions,
            criteria,
            0,
            true,
            subscribers,
            0
        );
    }

    // @notice Recursively inspects the `subscriptions` data structure to find active subscribers.
    // @param filter_map Currently active filter mapping.
    // @param criteria Complete list of criteria pattern generated from the event being processed.
    // @param criterion_index Active position in the criteria pattern.
    // @param populate Whether the target array should be populated with results (simply counts the hits if `false`).
    // @param found_subscribers Target array for results. Must be initialized to the correct size.
    // @param next_index Index of the next result in the target array.
    function findSubscribersRecursively(
        mapping(uint256 => Filter) storage filter_map,
        uint256[NUM_OF_CRITERIA] memory criteria,
        uint8 criterion_index,
        bool populate,
        address[] memory found_subscribers,
        uint256 next_index
    ) internal view returns (
        uint256 subscribers
    ) {
        subscribers = 0;
        uint256 cur_crit = criteria[criterion_index];
        while (true) {
            Filter storage filter = filter_map[cur_crit];
            if (filter.initialized) {
                for (uint256 ix = 0; ix != filter.subscribers.length; ++ix) {
                    ++subscribers;
                    if (populate) {
                        found_subscribers[next_index++] = filter.subscribers[ix];
                    }
                }
                if (criterion_index < (NUM_OF_CRITERIA - 1)) {
                    uint256 found_recursively = findSubscribersRecursively(
                        filter.conditional_subscribers,
                        criteria,
                        criterion_index + 1,
                        populate,
                        found_subscribers,
                        next_index
                    );
                    subscribers += found_recursively;
                    next_index += found_recursively;
                }
            }
            if (cur_crit == REACTIVE_IGNORE) {
                break;
            }
            cur_crit = REACTIVE_IGNORE;
        }
    }

    function computeLastNonZeroCriterion(
        uint256[NUM_OF_CRITERIA] memory criteria
    ) pure internal returns (
        int8 last_non_zero
    ) {
        last_non_zero = -1;
        for (uint256 ix = 0; ix != criteria.length; ++ix) {
            if (REACTIVE_IGNORE != criteria[ix]) {
                last_non_zero = int8(int256(ix));
            }
        }
        require(last_non_zero >= 0, 'NZ');
    }
}

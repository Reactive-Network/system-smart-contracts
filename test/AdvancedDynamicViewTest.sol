// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import 'forge-std/Test.sol';
import '../src/SystemContract.sol';
import '../src/demos/basic/BasicDemoReactiveContract.sol';

contract AdvancedDynamicViewTest is Test {
    uint256 private constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    SystemContract service;
    BasicDemoReactiveContract stub;

    function setUp() public {
        service = new SystemContract();
        stub = new BasicDemoReactiveContract(address(service), address(service), 0xdeadbeef, address(service));
    }

    function test_advanced_dynamic_view() public {
        uint256 results;
        address[] memory subscribers;

        // ROUND 1

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 2

        stub.subscribe(address(stub), 0xcafebabe);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 3

        stub.subscribe(address(0x0), 0xcafebabe);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 2);
        assertEq(subscribers.length, 2);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 4

        stub.unsubscribe(address(service), 0xdeadbeef);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 2);
        assertEq(subscribers.length, 2);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 5

        stub.unsubscribe(address(stub), 0xcafebabe);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 6

        stub.unsubscribe(address(0x0), 0xcafebabe);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 1b

        stub.subscribe(address(service), 0xdeadbeef);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 2b

        stub.subscribe(address(stub), 0xcafebabe);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 3b

        stub.subscribe(address(0x0), 0xcafebabe);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 2);
        assertEq(subscribers.length, 2);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 4b

        stub.unsubscribe(address(service), 0xdeadbeef);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 2);
        assertEq(subscribers.length, 2);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 5b

        stub.unsubscribe(address(stub), 0xcafebabe);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        // ROUND 6b

        stub.unsubscribe(address(0x0), 0xcafebabe);

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(stub),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }

        (results, subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xcafebabe,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
        for (uint8 ix = 0; ix != subscribers.length; ++ix) {
            assertEq(subscribers[ix], address(stub));
        }
    }
}

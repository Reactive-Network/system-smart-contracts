// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import 'forge-std/Test.sol';
import '../src/SubscriptionService.sol';
import '../src/demos/basic/BasicDemoReactiveContract.sol';

contract ViewTest is Test {
    uint256 private constant REACTIVE_IGNORE = 0xa65f96fc951c35ead38878e0f0b7a3c744a6f5ccc1476b313353ce31712313ad;

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;

    uint256 private constant STUB_CONTRACTS = 3;

    SubscriptionService service;
    BasicDemoReactiveContract[STUB_CONTRACTS] stub;

    function setUp() public {
        service = new SubscriptionService();
        stub[0] = new BasicDemoReactiveContract(address(service), address(service), 0xdeadbeef, address(service));
        stub[1] = new BasicDemoReactiveContract(address(service), address(0x0), 0xdeadbeef, address(service));
        stub[2] = new BasicDemoReactiveContract(address(service), address(service), REACTIVE_IGNORE, address(service));
    }

    function test_view_0() public view {
        (uint256 results, address[] memory subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(0x0),
            0x1,
            0,
            0,
            0
        );
        assertEq(results, 0);
        assertEq(subscribers.length, 0);
    }

    function test_view_1() public view {
        (uint256 results, address[] memory subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0x1,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        assertEq(subscribers[0], address(stub[2]));
    }

    function test_view_2() public view {
        (uint256 results, address[] memory subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(this),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 1);
        assertEq(subscribers.length, 1);
        assertEq(subscribers[0], address(stub[1]));
    }

    function test_view_3() public view {
        // The 2, 0, 1 order of stubs being triggered is an artifact of how the explores the subscriptions,
        // and not important for contract behavior. Still, we can't tell forge that we want these events in ANY
        // order whatsoever.
        (uint256 results, address[] memory subscribers) = service.findSubscribers(
            SEPOLIA_CHAIN_ID,
            address(service),
            0xdeadbeef,
            0,
            0,
            0
        );
        assertEq(results, 3);
        assertEq(subscribers.length, 3);
        assertEq(subscribers[0], address(stub[2]));
        assertEq(subscribers[1], address(stub[0]));
        assertEq(subscribers[2], address(stub[1]));
    }
}

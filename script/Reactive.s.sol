// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import 'forge-std/Script.sol';

contract ReactiveScript is Script {
    function setUp() public {
    }

    function run() public {
        vm.broadcast();
    }
}

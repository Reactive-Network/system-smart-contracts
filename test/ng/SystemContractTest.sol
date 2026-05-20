// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { Test } from  "forge-std/Test.sol";
import { ERC1967Proxy } from "../../src/ng/proxies/ERC1967Proxy.sol";
import { AbstractSubscriptionService } from "../../src/ng/base/AbstractSubscriptionService.sol";
import { SystemContract } from "../../src/ng/SystemContract.sol";
import { BrokenSystemContractMockup } from "./mockups/BrokenSystemContractMockup.sol";
import { ConditionallyUpgradingSystemContractMockup } from "./mockups/ConditionallyUpgradingSystemContractMockup.sol";

contract SysConProxyingTest is Test {
    bytes32 public constant ERC1967_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public constant SYSCON_INIT_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;
    address public constant ARB_ADDR = 0xF0Be5dB673D1feea5d0D4c6D57A1098Cdc007Ca7;

    SystemContract public _impl;
    SystemContract public _proxy;

    function setUp() public {
        _impl = new SystemContract();

        _proxy = SystemContract(payable(new ERC1967Proxy(address(0), new bytes(0))));

        vm.store(address(_proxy), ERC1967_IMPL_SLOT, bytes32(uint256(uint160(address(_impl)))));
    }

    function test_systemContractProxying() public {
        address[] memory validators = new address[](1);
        validators[0] = address(SYSCON_INIT_ADDR);

        vm.startPrank(ARB_ADDR);

        vm.expectRevert();
        _proxy.initialize(validators);

        vm.stopPrank();

        vm.startPrank(SYSCON_INIT_ADDR);

        vm.expectRevert();
        _impl.initialize(validators);

        _proxy.initialize(validators);

        vm.expectRevert();
        _proxy.initialize(validators);

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        vm.expectEmit();
        emit AbstractSubscriptionService.Subscribe(ARB_ADDR, 1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        _proxy.subscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectEmit();
        emit AbstractSubscriptionService.Unsubscribe(ARB_ADDR, 1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        _proxy.unsubscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        BrokenSystemContractMockup broken = new BrokenSystemContractMockup();
        ConditionallyUpgradingSystemContractMockup cond = new ConditionallyUpgradingSystemContractMockup();

        vm.expectRevert();
        _proxy.upgradeImpl(address(cond), new bytes(1));

        vm.stopPrank();

        vm.startPrank(SYSCON_INIT_ADDR);

        vm.expectRevert();
        _proxy.upgradeImpl(address(broken), new bytes(0));

        vm.expectEmit();
        emit AbstractSubscriptionService.Subscribe(SYSCON_INIT_ADDR, 1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        _proxy.subscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectEmit();
        emit AbstractSubscriptionService.Unsubscribe(SYSCON_INIT_ADDR, 1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        _proxy.unsubscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectRevert();
        _proxy.upgradeImpl(address(cond), new bytes(0));

        _proxy.upgradeImpl(address(cond), new bytes(1));

        vm.expectRevert();
        _proxy.subscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectEmit();
        emit AbstractSubscriptionService.Unsubscribe(SYSCON_INIT_ADDR, 1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        _proxy.unsubscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), new bytes(0));

        vm.store(address(_proxy), ERC1967_IMPL_SLOT, 0);

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), new bytes(0));

        vm.stopPrank();
    }
}

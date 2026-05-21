// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { IReactive, LogRecord } from "../../src/omni/interfaces/IReactive.sol";
import { CallbackVersion, CallbackConfiguration_V_1_0 } from "../../src/omni/interfaces/ICallback.sol";
import { ERC1967Proxy } from "../../src/omni/proxies/ERC1967Proxy.sol";
import { AbstractSubscriptionService } from "../../src/omni/base/AbstractSubscriptionService.sol";
import { SystemContract } from "../../src/omni/SystemContract.sol";
import { BrokenSystemContractMockup } from "./mockups/BrokenSystemContractMockup.sol";
import { ConditionallyUpgradingSystemContractMockup } from "./mockups/ConditionallyUpgradingSystemContractMockup.sol";
import { ReactiveContractMockup } from "./mockups/ReactiveContractMockup.sol";

/**
 * A simple test script for the 2.0 system contract.
 */
contract SystemContractTest is Test {
    bytes32 public constant ERC1967_IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    address public constant SYSCON_INIT_ADDR = 0x038E06667e42782E571EaB20432b9237F9bD6B82;
    address public constant OWNER_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;
    address public constant ARB_ADDR = 0xF0Be5dB673D1feea5d0D4c6D57A1098Cdc007Ca7;

    SystemContract public _impl;
    SystemContract public _proxy;

    ReactiveContractMockup public _reactive;

    function setUp() public {
        _impl = new SystemContract();

        _proxy = SystemContract(payable(new ERC1967Proxy(address(0), new bytes(0))));

        vm.store(address(_proxy), ERC1967_IMPL_SLOT, bytes32(uint256(uint160(address(_impl)))));

        vm.deal(SYSCON_INIT_ADDR, 1e10 ether);
        vm.deal(OWNER_ADDR, 1e10 ether);

        _reactive = new ReactiveContractMockup(true);
    }

    function test_SystemContractWorkflow() public {
        vm.startPrank(SYSCON_INIT_ADDR);

        address[] memory validators = new address[](1);
        validators[0] = SYSCON_INIT_ADDR;

        _proxy.initialize(validators);

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        _proxy.removeValidators(validators);

        _proxy.addValidators(validators);

        (bool success,) = address(_proxy).call{ value: 1 ether }(new bytes(0));

        assertEq(success, true);

        vm.expectEmit();
        emit SystemContract.BlacklistContract(address(0));

        _proxy.blacklist(address(0));

        vm.expectEmit();
        emit SystemContract.WhitelistContract(address(0));

        _proxy.whitelist(address(0));

        LogRecord memory log = LogRecord({
            chain_id: 1,
            _contract: address(_proxy),
            topic_0: 0xcafebabe,
            topic_1: 0,
            topic_2: 0,
            topic_3: 0,
            data: new bytes(0),
            block_number: 123456,
            op_code: 1,
            block_hash: 0xdeadbeef,
            tx_hash: 0xcafedead,
            log_index: 0
        });

        vm.expectRevert();
        _proxy.trigger(_reactive, log);

        vm.stopPrank();

        vm.startPrank(SYSCON_INIT_ADDR);

        vm.txGasPrice(1 gwei);

        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();
        emit SystemContract.BlacklistContract(address(_reactive));

        _proxy.trigger(_reactive, log);

        assertEq(_proxy.reserves(address(_reactive)), 0);

        uint256 debt = _proxy.debt(address(_reactive));

        assertEq(debt > 0, true);

        vm.expectRevert();
        _proxy.trigger(_reactive, log);

        _proxy.depositTo{ value: 1 }(address(_reactive));

        vm.expectEmit();
        emit SystemContract.WhitelistContract(address(_reactive));

        _proxy.depositTo{ value: debt - 1 }(address(_reactive));

        debt = _proxy.debts(address(_reactive));

        assertEq(debt == 0, true);

        (success,) = address(_reactive).call{ value: 10 ether }(new bytes(0));

        assertEq(success, true);

        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();

        _proxy.trigger(_reactive, log);

        _proxy.depositTo{ value: 1 }(address(_reactive));

        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();

        _proxy.trigger(_reactive, log);

        _proxy.depositTo{ value: 100 ether }(address(_reactive));

        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();

        _proxy.trigger(_reactive, log);

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        SystemContract.CallbackInfo[] memory callbacks = new SystemContract.CallbackInfo[](1);
        callbacks[0] = SystemContract.CallbackInfo({
            block_number: 12345,
            rvm_id: address(1),
            rvm_txhash: 0xcafebabe,
            callback_ix: 0,
            dest_chain_id: 11155111,
            dest_txhash: 0xdeadcafe,
            err: new bytes(0)
        });

        vm.expectRevert();
        _proxy.storeCallbacks(callbacks);

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        _proxy.storeCallbacks(callbacks);

        SystemContract.CallbackStore[] memory data = _proxy.getCallbacks(0xcafebabe);

        CallbackConfiguration_V_1_0 memory conf = CallbackConfiguration_V_1_0({
            chainId: 1,
            recipient: ARB_ADDR,
            gasLimit: 1e6,
            payload: new bytes(0)
        });

        bytes memory encConf = abi.encode(conf);

        vm.expectEmit();
        emit SystemContract.CallbackRequest(1, OWNER_ADDR, ARB_ADDR, CallbackVersion.V_1_0, encConf);

        _proxy.requestCallback(CallbackVersion.V_1_0, encConf);

        vm.expectEmit();
        emit SystemContract.CallbackRequest(1, OWNER_ADDR, ARB_ADDR, CallbackVersion.V_1_0, encConf);

        _proxy.requestCallbackV_1_0(conf);

        assertEq(data.length, 1);

        vm.stopPrank();
    }

    function test_SystemContractProxying() public {
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

        vm.startPrank(OWNER_ADDR);

        vm.expectRevert();
        _proxy.upgradeImpl(address(broken), new bytes(0));

        vm.expectEmit();
        emit AbstractSubscriptionService.Subscribe(OWNER_ADDR, 1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        _proxy.subscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectEmit();
        emit AbstractSubscriptionService.Unsubscribe(OWNER_ADDR, 1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        _proxy.unsubscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectRevert();
        _proxy.upgradeImpl(address(cond), new bytes(0));

        _proxy.upgradeImpl(address(cond), new bytes(1));

        vm.expectRevert();
        _proxy.subscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectEmit();
        emit AbstractSubscriptionService.Unsubscribe(OWNER_ADDR, 1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        _proxy.unsubscribe(1, SYSCON_INIT_ADDR, 0, 1, 2, 3);

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), new bytes(0));

        vm.store(address(_proxy), ERC1967_IMPL_SLOT, 0);

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), new bytes(0));

        vm.stopPrank();
    }
}

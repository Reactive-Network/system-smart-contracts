// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { Test, Vm } from "forge-std/Test.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractMetaDataStorage } from "../../src/omni/base/AbstractMetaDataStorage.sol";
import { SystemContract } from "../../src/SystemContract.sol";
import { LegacySystemContract } from "../../src/omni/LegacySystemContract.sol";
import { RvmProxy } from "../../src/omni/proxies/RvmProxy.sol";
import { ReactiveContractMockup } from "./mockups/ReactiveContractMockup.sol";

/**
 * A simple test script for the legacy system contract.
 */
contract LegacySystemContractTest is Test {
    address public constant SYSCON_INIT_ADDR = 0x038E06667e42782E571EaB20432b9237F9bD6B82;
    address public constant OWNER_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;
    address public constant ARB_ADDR = 0xF0Be5dB673D1feea5d0D4c6D57A1098Cdc007Ca7;

    address payable public constant SYSTEM = payable(0x0000000000000000000000000000000000fffFfF);

    bytes32 public constant TEST_EVENT_TOPIC_0 = 0x24ec1d3ff24c2f6ff210738839dbc339cd45a5294d85c79361016243157aae7b;
    bytes32 public constant PAYMENT_FAILURE_TOPIC_0 = 0xade428889ac75005bd70004e1b1e262be6bf4f97bad5827315a7d58261a6dac7;
    bytes32 public constant BLACKLIST_TOPIC_0 = 0x930136576d6bd679046e0c2e6212ce4cacec0401db71e9a27f906d2bab5e08f3;
    bytes32 public constant WHITELIST_TOPIC_0 = 0xc91181be4112cf78026ec1c30b4f5ecac00faa44c8d5e9523e08325cf186d8a7;
    
    ReactiveContractMockup public _reactive;
    RvmProxy public _proxy;

    function setUp() public {
        _reactive = new ReactiveContractMockup(false);
        _proxy = new RvmProxy();

        vm.store(address(_proxy), 0, bytes32(uint256(1)));

        LegacySystemContract sys = new LegacySystemContract();

        vm.etch(SYSTEM, address(sys).code);

        vm.deal(SYSCON_INIT_ADDR, 1e10 ether);
    }

    function test_LegacySystemContractWhitelistingFlow() public {
        LegacySystemContract system = LegacySystemContract(SYSTEM);

        vm.startPrank(OWNER_ADDR);

        system.init();

        vm.stopPrank();

        AbstractMetaDataStorage.RnkRvmMetaData[] memory mappings = new AbstractMetaDataStorage.RnkRvmMetaData[](1);
        mappings[0] = AbstractMetaDataStorage.RnkRvmMetaData({
            rvmContract: address(_proxy),
            rvmId: address(1),
            rnkContract: address(_reactive)
        });

        vm.startPrank(SYSCON_INIT_ADDR);

        system.updateMetaData(mappings);
        system.finalize();

        IReactive.LogRecord memory log = IReactive.LogRecord({
            chainId: 1,
            contractAddress: SYSTEM,
            topic0: 0xcafebabe,
            topic1: 0,
            topic2: 0,
            topic3: 0,
            data: new bytes(0),
            blockNumber: 123456,
            opCode: 1,
            blockHash: 0xdeadbeef,
            txHash: 0xcafedead,
            logIndex: 0
        });

        Vm.Log[] memory logs;

        vm.txGasPrice(1 gwei);

        vm.recordLogs();

        system.trigger(IReactive(payable(address(_proxy))), log);

        logs = vm.getRecordedLogs();

        assertEq(logs.length, 3);
        assertEq(logs[0].topics[0], TEST_EVENT_TOPIC_0);
        assertEq(logs[1].topics[0], PAYMENT_FAILURE_TOPIC_0);
        assertEq(logs[2].topics[0], BLACKLIST_TOPIC_0);

        (bool success,) = address(_reactive).call{ value: 10 ether }(new bytes(0));

        assertEq(success, true);

        vm.recordLogs();

        _reactive.coverDebt();

        logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], WHITELIST_TOPIC_0);

        vm.recordLogs();

        system.trigger(IReactive(payable(address(_proxy))), log);

        logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);
        assertEq(logs[0].topics[0], TEST_EVENT_TOPIC_0);

        vm.stopPrank();
    }

    function test_LegacySystemContractWorkflow() public {
        LegacySystemContract system = LegacySystemContract(SYSTEM);

        vm.startPrank(OWNER_ADDR);

        system.init();

        vm.stopPrank();

        AbstractMetaDataStorage.RnkRvmMetaData[] memory mappings = new AbstractMetaDataStorage.RnkRvmMetaData[](1);
        mappings[0] = AbstractMetaDataStorage.RnkRvmMetaData({
            rvmContract: address(_proxy),
            rvmId: address(1),
            rnkContract: address(_reactive)
        });

        vm.startPrank(ARB_ADDR);

        vm.expectRevert();
        system.updateMetaData(mappings);

        vm.stopPrank();

        vm.startPrank(SYSCON_INIT_ADDR);

        system.updateMetaData(mappings);
        system.updateMetaData(mappings);
        system.finalize();

        vm.expectRevert();
        system.updateMetaData(mappings);

        vm.expectEmit();
        emit SystemContract.Cron1(1);

        system.triggerCron();

        IReactive.LogRecord memory log = IReactive.LogRecord({
            chainId: 1,
            contractAddress: SYSTEM,
            topic0: 0xcafebabe,
            topic1: 0,
            topic2: 0,
            topic3: 0,
            data: new bytes(0),
            blockNumber: 123456,
            opCode: 1,
            blockHash: 0xdeadbeef,
            txHash: 0xcafedead,
            logIndex: 0
        });

        vm.expectRevert();
        _reactive.react(log);

        vm.expectRevert();
        ReactiveContractMockup(payable(address(_proxy))).react(log);
        
        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();

        system.trigger(IReactive(payable(address(_proxy))), log);

        vm.txGasPrice(1 ether);
        
        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();

        system.trigger(IReactive(payable(address(_proxy))), log);

        uint256 debt = system.debt(address(_reactive));

        assertEq(debt > 0, true);

        vm.expectRevert();
        system.trigger(IReactive(payable(address(_proxy))), log);

        system.depositTo{ value: debt }(address(_reactive));

        debt = system.debt(address(_reactive));

        assertEq(debt == 0, true);

        vm.txGasPrice(1 gwei);

        (bool success,) = address(_reactive).call{ value: 10 ether }(new bytes(0));

        assertEq(success, true);

        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();

        system.trigger(IReactive(payable(address(_proxy))), log);

        vm.stopPrank();

        vm.startPrank(SYSTEM);

        vm.expectRevert();
        ReactiveContractMockup(payable(address(_proxy))).pay(1 ether);

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        vm.expectRevert();
        _reactive.react(log);

        vm.expectRevert();

        system.triggerCron();

        vm.stopPrank();

        vm.startPrank(SYSCON_INIT_ADDR);

        RvmProxy proxy = new RvmProxy();

        vm.expectRevert();
        system.trigger(IReactive(payable(address(proxy))), log);

        vm.stopPrank();
    }
}

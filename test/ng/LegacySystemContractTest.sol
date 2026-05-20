// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { Test } from "forge-std/Test.sol";
import { IReactive, LogRecord } from "../../src/ng/interfaces/IReactive.sol";
import { AbstractMetaDataStorage } from "../../src/ng/base/AbstractMetaDataStorage.sol";
import { SystemContract } from "../../src/SystemContract.sol";
import { LegacySystemContract } from "../../src/ng/LegacySystemContract.sol";
import { RvmProxy } from "../../src/ng/proxies/RvmProxy.sol";
import { ReactiveContractMockup } from "./mockups/ReactiveContractMockup.sol";

/**
 * A simple test script for the legacy system contract.
 */
contract LegacySystemContractTest is Test {
    address public constant SYSCON_INIT_ADDR = 0x038E06667e42782E571EaB20432b9237F9bD6B82;
    address public constant OWNER_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;
    address public constant ARB_ADDR = 0xF0Be5dB673D1feea5d0D4c6D57A1098Cdc007Ca7;

    address payable public constant SYSTEM = payable(0x0000000000000000000000000000000000fffFfF);

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

    function test_LegacySystemContractWorkflow() public {
        LegacySystemContract system = LegacySystemContract(SYSTEM);

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

        LogRecord memory log = LogRecord({
            chain_id: 1,
            _contract: SYSTEM,
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
        _reactive.react(log);

        vm.expectRevert();
        ReactiveContractMockup(payable(address(_proxy))).react(log);

        vm.txGasPrice(1 ether);
        
        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();

        system.trigger(IReactive(address(_proxy)), log);

        uint256 debt = system.debt(address(_reactive));

        assertEq(debt > 0, true);

        vm.expectRevert();
        system.trigger(IReactive(address(_proxy)), log);

        system.depositTo{ value: debt }(address(_reactive));

        debt = system.debt(address(_reactive));

        assertEq(debt == 0, true);

        vm.txGasPrice(1 gwei);

        (bool success,) = address(_reactive).call{ value: 10 ether }(new bytes(0));

        assertEq(success, true);

        vm.expectEmit();
        emit ReactiveContractMockup.TestEvent();

        system.trigger(IReactive(address(_proxy)), log);

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
        system.trigger(IReactive(address(proxy)), log);

        vm.stopPrank();
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { Test, Vm } from "forge-std/Test.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { CallbackContractMockup } from "./mockups/CallbackContractMockup.sol";
import { ConditionallyUpgradingCallbackProxyMockup } from "./mockups/ConditionallyUpgradingCallbackProxyMockup.sol";
import { ERC1967Proxy } from "../../src/omni/proxies/ERC1967Proxy.sol";
import { CallbackProxy } from "../../src/omni/CallbackProxy.sol";
import { CallbackProxyDeployer } from "../../src/omni/deployers/CallbackProxyDeployer.sol";

/**
 * A simple test script for the omni-style callback proxy.
 */
contract CallbackProxyTest is Test {
    address public constant OWNER_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;
    address public constant ARB_ADDR = 0xF0Be5dB673D1feea5d0D4c6D57A1098Cdc007Ca7;

    CallbackProxy public _proxy;
    CallbackProxy public _impl;

    function setUp() public {
        vm.deal(OWNER_ADDR, 1000000 ether);
        vm.deal(ARB_ADDR, 1000000 ether);
    }

    function test_CallbackProxyWorkflow() public {
        vm.startPrank(OWNER_ADDR);

        address[] memory senders = new address[](1);
        senders[0] = OWNER_ADDR;

        vm.recordLogs();

        new CallbackProxyDeployer(0, 50000, 100000, 1000, senders);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);

        _proxy = CallbackProxy(payable(address(uint160(uint256(logs[0].topics[2])))));
        _impl = CallbackProxy(payable(address(uint160(uint256(logs[0].topics[1])))));

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        vm.expectRevert();
        _impl.removeCallbackSenders(senders);

        vm.expectRevert();
        _proxy.removeCallbackSenders(senders);

        vm.expectRevert();
        _impl.onImplUpgrade("");

        vm.expectRevert();
        _proxy.onImplUpgrade("");

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        vm.txGasPrice(1 gwei);

        CallbackContractMockup cbk = new CallbackContractMockup();

        bytes memory payload = abi.encodeWithSignature("callback(address,string)", ARB_ADDR, "test message");
        ISystemContract.CallbackConfiguration_V_1_0 memory cfg = ISystemContract.CallbackConfiguration_V_1_0({
            chainId: 1,
            recipient: address(cbk),
            gasLimit: 1000000,
            payload: payload
        });

        vm.expectEmit();
        emit CallbackContractMockup.TestEvent("test message");

        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        uint256 debt = _proxy.debts(address(cbk));

        assertEq(debt > 0, true);

        vm.expectRevert();
        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        _proxy.depositTo{ value: debt }(address(cbk));

        (bool success,) = payable(cbk).call{ value: 10 ether }("");

        assertEq(success, true);

        vm.expectEmit();
        emit CallbackContractMockup.TestEvent("test message");

        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        assertEq(_proxy.debts(address(cbk)), 0);
        assertEq(_proxy.reserves(address(cbk)), 0);

        senders[0] = ARB_ADDR;

        _proxy.addCallbackSenders(senders);

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        vm.expectEmit();
        emit CallbackContractMockup.TestEvent("test message");

        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        _proxy.removeCallbackSenders(senders);

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        vm.expectRevert();
        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        vm.expectRevert();
        _proxy.deliverCallback{ gas: 150000 }(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        cfg = ISystemContract.CallbackConfiguration_V_1_0({
            chainId: 1,
            recipient: ARB_ADDR,
            gasLimit: 1000000,
            payload: payload
        });

        vm.expectRevert();
        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        payload = abi.encodeWithSignature("callback(address,string)", ARB_ADDR, "");
        cfg = ISystemContract.CallbackConfiguration_V_1_0({
            chainId: 1,
            recipient: address(cbk),
            gasLimit: 1000000,
            payload: payload
        });

        vm.expectEmit();
        emit CallbackProxy.CallbackFailure(address(cbk), payload);

        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        _impl = new CallbackProxy();

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), "");

        _impl = new ConditionallyUpgradingCallbackProxyMockup();

        vm.expectRevert();
        _proxy.upgradeImpl(ARB_ADDR, bytes("!"));

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), bytes("!"));

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), bytes("!!"));

        _proxy.upgradeImpl(address(_impl), bytes("!!!"));

        vm.expectRevert();
        new ERC1967Proxy(ARB_ADDR, bytes("!"));

        vm.expectRevert();
        new ERC1967Proxy(address(_impl), bytes("!"));

        vm.expectRevert();
        new ERC1967Proxy(address(_impl), bytes("!!"));

        new ERC1967Proxy(address(_impl), bytes("!!!"));

        vm.stopPrank();
    }

    function test_CallbackProxySaltedWorkflow() public {
        vm.startPrank(OWNER_ADDR);

        address[] memory senders = new address[](1);
        senders[0] = OWNER_ADDR;

        vm.recordLogs();

        new CallbackProxyDeployer(0xdeadbeef, 50000, 100000, 1000, senders);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 1);

        _proxy = CallbackProxy(payable(address(uint160(uint256(logs[0].topics[2])))));
        _impl = CallbackProxy(payable(address(uint160(uint256(logs[0].topics[1])))));

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        vm.expectRevert();
        _impl.removeCallbackSenders(senders);

        vm.expectRevert();
        _proxy.removeCallbackSenders(senders);

        vm.expectRevert();
        _impl.onImplUpgrade("");

        vm.expectRevert();
        _proxy.onImplUpgrade("");

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        vm.txGasPrice(1 gwei);

        CallbackContractMockup cbk = new CallbackContractMockup();

        bytes memory payload = abi.encodeWithSignature("callback(address,string)", ARB_ADDR, "test message");
        ISystemContract.CallbackConfiguration_V_1_0 memory cfg = ISystemContract.CallbackConfiguration_V_1_0({
            chainId: 1,
            recipient: address(cbk),
            gasLimit: 1000000,
            payload: payload
        });

        vm.expectEmit();
        emit CallbackContractMockup.TestEvent("test message");

        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        uint256 debt = _proxy.debts(address(cbk));

        assertEq(debt > 0, true);

        vm.expectRevert();
        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        _proxy.depositTo{ value: debt }(address(cbk));

        (bool success,) = payable(cbk).call{ value: 10 ether }("");

        assertEq(success, true);

        vm.expectEmit();
        emit CallbackContractMockup.TestEvent("test message");

        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        assertEq(_proxy.debts(address(cbk)), 0);
        assertEq(_proxy.reserves(address(cbk)), 0);

        senders[0] = ARB_ADDR;

        _proxy.addCallbackSenders(senders);

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        vm.expectEmit();
        emit CallbackContractMockup.TestEvent("test message");

        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        _proxy.removeCallbackSenders(senders);

        vm.stopPrank();

        vm.startPrank(ARB_ADDR);

        vm.expectRevert();
        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        vm.expectRevert();
        _proxy.deliverCallback{ gas: 150000 }(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        cfg = ISystemContract.CallbackConfiguration_V_1_0({
            chainId: 1,
            recipient: ARB_ADDR,
            gasLimit: 1000000,
            payload: payload
        });

        vm.expectRevert();
        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        payload = abi.encodeWithSignature("callback(address,string)", ARB_ADDR, "");
        cfg = ISystemContract.CallbackConfiguration_V_1_0({
            chainId: 1,
            recipient: address(cbk),
            gasLimit: 1000000,
            payload: payload
        });

        vm.expectEmit();
        emit CallbackProxy.CallbackFailure(address(cbk), payload);

        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, abi.encode(cfg));

        _impl = new CallbackProxy();

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), "");

        _impl = new ConditionallyUpgradingCallbackProxyMockup();

        vm.expectRevert();
        _proxy.upgradeImpl(ARB_ADDR, bytes("!"));

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), bytes("!"));

        vm.expectRevert();
        _proxy.upgradeImpl(address(_impl), bytes("!!"));

        _proxy.upgradeImpl(address(_impl), bytes("!!!"));

        vm.expectRevert();
        new ERC1967Proxy(ARB_ADDR, bytes("!"));

        vm.expectRevert();
        new ERC1967Proxy(address(_impl), bytes("!"));

        vm.expectRevert();
        new ERC1967Proxy(address(_impl), bytes("!!"));

        new ERC1967Proxy(address(_impl), bytes("!!!"));

        vm.stopPrank();
    }
}

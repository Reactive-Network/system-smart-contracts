// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { Test, Vm } from "forge-std/Test.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { CallbackContractMockup } from "./mockups/CallbackContractMockup.sol";
import { GasBurningCallbackMockup, ReturnBombCallbackMockup } from "./mockups/GasGriefingCallbackMockup.sol";
import { L1FeeOracleMockup, RevertingL1FeeOracleMockup } from "./mockups/L1FeeOracleMockup.sol";
import { AbstractProxiedPayableBridge } from "../../src/omni/base/AbstractProxiedPayableBridge.sol";
import { CallbackProxy } from "../../src/omni/CallbackProxy.sol";
import { CallbackProxyDeployer } from "../../src/omni/deployers/CallbackProxyDeployer.sol";
import { IL1FeeOracle } from "../../src/omni/interfaces/IL1FeeOracle.sol";

/**
 * Tests for calldata, L1 data fee and post-callback reserve accounting of the omni-style callback proxy.
 */
contract CallbackProxyFeesTest is Test {
    address public constant OWNER_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;
    address public constant ARB_ADDR = 0xF0Be5dB673D1feea5d0D4c6D57A1098Cdc007Ca7;

    uint256 public constant MAX_CHARGE_GAS = 50000;
    uint256 public constant EXTRA_GAS = 80000;
    uint256 public constant COEFF = 1100;

    CallbackProxy public _proxy;

    function setUp() public {
        vm.deal(OWNER_ADDR, 1000000 ether);
        vm.deal(ARB_ADDR, 1000000 ether);

        address[] memory senders = new address[](1);
        senders[0] = OWNER_ADDR;

        vm.recordLogs();

        vm.prank(OWNER_ADDR);
        new CallbackProxyDeployer(0, MAX_CHARGE_GAS, EXTRA_GAS, COEFF, 0, IL1FeeOracle(address(0)), senders);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        _proxy = CallbackProxy(payable(address(uint160(uint256(logs[0].topics[2])))));
    }

    function test_InitialConfig() public {
        address[] memory senders = new address[](1);
        senders[0] = OWNER_ADDR;

        vm.recordLogs();

        vm.prank(OWNER_ADDR);
        new CallbackProxyDeployer(0, MAX_CHARGE_GAS, EXTRA_GAS, COEFF, 16, IL1FeeOracle(address(0x42)), senders);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        CallbackProxy proxy = CallbackProxy(payable(address(uint160(uint256(logs[0].topics[2])))));

        assertEq(proxy._calldataGasPerByte(), 16);
        assertEq(address(proxy._l1FeeOracle()), address(0x42));
    }

    function test_SettersAreOwnerOnly() public {
        vm.startPrank(ARB_ADDR);

        vm.expectRevert(AbstractProxiedPayableBridge.NotAuthorized.selector);
        _proxy.setCalldataGasPerByte(16);

        vm.expectRevert(AbstractProxiedPayableBridge.NotAuthorized.selector);
        _proxy.setL1FeeOracle(IL1FeeOracle(address(0x42)));

        vm.stopPrank();

        vm.startPrank(OWNER_ADDR);

        _proxy.setCalldataGasPerByte(16);
        _proxy.setL1FeeOracle(IL1FeeOracle(address(0x42)));

        vm.stopPrank();

        assertEq(_proxy._calldataGasPerByte(), 16);
        assertEq(address(_proxy._l1FeeOracle()), address(0x42));
    }

    function test_CalldataGasPerByte() public {
        CallbackContractMockup cbk = _fundedCallback();
        bytes memory config = _config(address(cbk), abi.encodeWithSignature("callback(address,string)", ARB_ADDR, "test message"));
        uint256 msgLen = abi.encodeCall(CallbackProxy.deliverCallback, (ISystemContract.CallbackVersion.V_1_0, config)).length;

        vm.txGasPrice(1 gwei);

        uint256 snapshot = vm.snapshotState();
        uint256 baseCharge = _deliverAndMeasure(address(cbk), config);

        vm.revertToState(snapshot);

        vm.prank(OWNER_ADDR);
        _proxy.setCalldataGasPerByte(16);

        uint256 charge = _deliverAndMeasure(address(cbk), config);

        assertEq(charge - baseCharge, 16 * msgLen * ((1 gwei * COEFF) / 1000));
    }

    function test_L1FeeOracle() public {
        CallbackContractMockup cbk = _fundedCallback();
        bytes memory config = _config(address(cbk), abi.encodeWithSignature("callback(address,string)", ARB_ADDR, "test message"));
        uint256 msgLen = abi.encodeCall(CallbackProxy.deliverCallback, (ISystemContract.CallbackVersion.V_1_0, config)).length;

        // Zero L2 gas price isolates the L1 component of the charge.
        vm.txGasPrice(0);
        vm.fee(0);

        assertEq(_deliverAndMeasure(address(cbk), config), 0);

        IL1FeeOracle oracle = new L1FeeOracleMockup();

        vm.prank(OWNER_ADDR);
        _proxy.setL1FeeOracle(oracle);

        uint256 l1Fee = (msgLen + _proxy.TX_ENVELOPE_SIZE()) * 1000;

        assertEq(_deliverAndMeasure(address(cbk), config), (l1Fee * COEFF) / 1000);
    }

    function test_RevertingL1FeeOracleIsIgnored() public {
        CallbackContractMockup cbk = _fundedCallback();
        bytes memory config = _config(address(cbk), abi.encodeWithSignature("callback(address,string)", ARB_ADDR, "test message"));

        vm.txGasPrice(0);
        vm.fee(0);

        IL1FeeOracle oracle = new RevertingL1FeeOracleMockup();

        vm.prank(OWNER_ADDR);
        _proxy.setL1FeeOracle(oracle);

        vm.expectEmit();
        emit CallbackContractMockup.TestEvent("test message");

        assertEq(_deliverAndMeasure(address(cbk), config), 0);
    }

    function test_GasBurningCallbackWithLargePayload() public {
        vm.txGasPrice(1 gwei);

        uint256[4] memory sizes = [uint256(0), 4096, 16384, 65536];

        for (uint256 ix = 0; ix != sizes.length; ++ix) {
            GasBurningCallbackMockup cbk = new GasBurningCallbackMockup();
            bytes memory payload = _nonZeroBytes(sizes[ix]);

            vm.expectEmit();
            emit CallbackProxy.CallbackFailure(address(cbk), payload);

            vm.prank(OWNER_ADDR, OWNER_ADDR);
            _proxy.deliverCallback{ gas: 2000000 }(ISystemContract.CallbackVersion.V_1_0, _config(address(cbk), payload));

            assertGt(_proxy.debts(address(cbk)), 0);
        }
    }

    function test_ReturnBombCallback() public {
        vm.txGasPrice(1 gwei);

        ReturnBombCallbackMockup cbk = new ReturnBombCallbackMockup();

        vm.prank(OWNER_ADDR, OWNER_ADDR);
        _proxy.deliverCallback{ gas: 2000000 }(ISystemContract.CallbackVersion.V_1_0, _config(address(cbk), hex"01"));

        assertGt(_proxy.debts(address(cbk)), 0);
    }

    function _fundedCallback() internal returns (CallbackContractMockup cbk_) {
        cbk_ = new CallbackContractMockup();

        vm.prank(OWNER_ADDR);
        _proxy.depositTo{ value: 100 ether }(address(cbk_));
    }

    function _deliverAndMeasure(address contract_, bytes memory config_) internal returns (uint256 charge_) {
        uint256 reserves = _proxy.reserves(contract_);

        vm.prank(OWNER_ADDR, OWNER_ADDR);
        _proxy.deliverCallback(ISystemContract.CallbackVersion.V_1_0, config_);

        return reserves - _proxy.reserves(contract_);
    }

    function _config(address recipient_, bytes memory payload_) internal pure returns (bytes memory config_) {
        return abi.encode(ISystemContract.CallbackConfiguration_V_1_0({
            chainId: 1,
            recipient: recipient_,
            gasLimit: 1000000,
            payload: payload_
        }));
    }

    function _nonZeroBytes(uint256 length_) internal pure returns (bytes memory bytes_) {
        bytes_ = new bytes(length_);
        for (uint256 ix = 0; ix != length_; ++ix) {
            bytes_[ix] = 0xab;
        }
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { Vm } from "forge-std/Test.sol";
import { Script } from "forge-std/Script.sol";
import { Config } from "forge-std/Config.sol";
import { console } from "forge-std/console.sol";
import { CallbackProxy } from "../src/omni/CallbackProxy.sol";
import { CallbackProxyDeployer } from "../src/omni/deployers/CallbackProxyDeployer.sol";

/**
 * @title Deployment script for callback proxies.
 */
contract DeployCallbackProxy is Script, Config {
    CallbackProxy public _proxy;
    CallbackProxy public _impl;

    address[] _callbackSenders;

    function run() public {
        uint256 chainId = block.chainid;
        console.log("Deploying to chain:", chainId);

        string memory cfgFile = "deployment_values/";
        cfgFile = string.concat(cfgFile, _toStr(chainId));
        cfgFile = string.concat(cfgFile, "/callback_proxy_deployment.toml");
        console.log("Configuration file:", cfgFile);

        _loadConfig(cfgFile, true);

        uint256 salt = config.get("salt").toUint256();
        uint256 maxChargeGas = config.get("max_charge_gas").toUint256();
        uint256 extraGas = config.get("extra_gas").toUint256();
        uint256 gasPriceCoeffPer1000 = config.get("gas_price_coeff_per_1000").toUint256();

        address callbackSender1 = config.get("callback_sender_1").toAddress();
        address callbackSender2 = config.get("callback_sender_2").toAddress();
        address callbackSender3 = config.get("callback_sender_3").toAddress();

        if (callbackSender1 != address(0)) {
            _callbackSenders.push(callbackSender1);
        }
        if (callbackSender2 != address(0)) {
            _callbackSenders.push(callbackSender2);
        }
        if (callbackSender3 != address(0)) {
            _callbackSenders.push(callbackSender3);
        }

        require(_callbackSenders.length > 0);

        console.log("Configuration:");
        console.log("Salt:", salt);
        console.log("Max Charge Gas:", maxChargeGas);
        console.log("Extra Gas:", extraGas);
        console.log("Gas Price Coefficient (per 1000th):", gasPriceCoeffPer1000);
        console.log("Callback Sender #1:", callbackSender1);
        console.log("Callback Sender #2:", callbackSender2);
        console.log("Callback Sender #3:", callbackSender3);

        console.log("----------");

        console.log("Deploying...");

        vm.createSelectFork(config.getRpcUrl(chainId));

        vm.startBroadcast();

        vm.recordLogs();

        new CallbackProxyDeployer(salt, maxChargeGas, extraGas, gasPriceCoeffPer1000, _callbackSenders);

        Vm.Log[] memory logs = vm.getRecordedLogs();

        require(logs.length == 1);

        _proxy = CallbackProxy(payable(address(uint160(uint256(logs[0].topics[2])))));
        _impl = CallbackProxy(payable(address(uint160(uint256(logs[0].topics[1])))));

        vm.stopBroadcast();

        console.log("Contracts deployed.");

        console.log("----------");

        console.log("Implementation contract:", address(_impl));
        console.log("Proxy contract:", address(_proxy));

        config.set("callback_proxy_implementation", address(_impl));
        config.set("callback_proxy", address(_proxy));
    }

    function _toStr(uint256 v_) internal pure returns (string memory str_) {
        unchecked {
            uint256 p;
            uint256 len = 1;
            uint256 v = v_;
            if (v >= 10 ** 64) {
                v /= 10 ** 64;
                len += 64;
            }
            if (v >= 10 ** 32) {
                v /= 10 ** 32;
                len += 32;
            }
            if (v >= 10 ** 16) {
                v /= 10 ** 16;
                len += 16;
            }
            if (v >= 10 ** 8) {
                v /= 10 ** 8;
                len += 8;
            }
            if (v >= 10000) {
                v /= 10000;
                len += 4;
            }
            if (v >= 100) {
                v /= 100;
                len += 2;
            }
            if (v >= 10) {
                ++len;
            }
            str_ = new string(len);
            assembly ("memory-safe") {
                p := add(str_, add(32, len))
            }
            do {
                p--;
                assembly ("memory-safe") {
                    mstore8(p, byte(mod(v_, 10), "0123456789abcdef"))
                }
                v_ /= 10;
            } while (v_ != 0);
        }
    }
}
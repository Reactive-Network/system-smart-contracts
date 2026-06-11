// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { CallbackProxy } from "../../../src/omni/CallbackProxy.sol";

/**
 * @title A mockup of a callback proxy with conditional upgrade.
 */
contract ConditionallyUpgradingCallbackProxyMockup is CallbackProxy {
    error Failure();

    function onImplUpgrade(bytes calldata data_) public virtual override onlyProxied returns (bool /* success_ */) {
        if (data_.length == 1) {
            revert Failure();
        } else {
            return data_.length != 2;
        }
    }
}

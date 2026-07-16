// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { ERC1967Proxy } from "../proxies/ERC1967Proxy.sol";
import { CallbackProxy } from "../CallbackProxy.sol";

/**
 * Deployer contract for omni-style `CallbackProxy`.
 */
contract CallbackProxyDeployer {
    /// @param callbackProxy_ Address of the freshly deployed implementation.
    /// @param proxy_ Address of the deployed proxy pointing to the implementation.
    event Deployed(
        CallbackProxy indexed callbackProxy_,
        ERC1967Proxy indexed proxy_
    );

    /// @param salt_ Optional salt for `CREATE2` deployment. Set to `0` to use `CREATE`.
    /// @param maxChargeGas_ Gas limit for reactive transaction payments.
    /// @param extraGas_ Extra gas to be paid for when executing a callback transaction.
    /// @param gasPriceCoeffPer1000_ Gas price coefficient (in promille) when executing a callback transactions.
    /// @param callbackSenders_ List of addresses of the authorized callback senders.
    constructor(
        uint256 salt_,
        uint256 maxChargeGas_,
        uint256 extraGas_,
        uint256 gasPriceCoeffPer1000_,
        address[] memory callbackSenders_
    ) {
        CallbackProxy callbackProxy;
        ERC1967Proxy proxy;

        if (salt_ == 0) {
            callbackProxy = new CallbackProxy();

            proxy = new ERC1967Proxy(address(callbackProxy), abi.encode(CallbackProxy.InitialConfig({
                owner: msg.sender,
                maxChargeGas: maxChargeGas_,
                extraGas: extraGas_,
                gasPriceCoeffPer1000: gasPriceCoeffPer1000_,
                callbackSenders: callbackSenders_
            })));
        } else {
            bytes32 salt = bytes32(salt_);

            callbackProxy = new CallbackProxy{ salt: salt }();

            proxy = new ERC1967Proxy{ salt: salt }(address(callbackProxy), abi.encode(CallbackProxy.InitialConfig({
                owner: msg.sender,
                maxChargeGas: maxChargeGas_,
                extraGas: extraGas_,
                gasPriceCoeffPer1000: gasPriceCoeffPer1000_,
                callbackSenders: callbackSenders_
            })));
        }

        emit Deployed(callbackProxy, proxy);

        selfdestruct(payable(msg.sender));
    }
}

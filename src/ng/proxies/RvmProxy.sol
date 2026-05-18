// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { DelegateCall } from "../lib/DelegateCall.sol";
import { AbstractMetaDataStorage } from "../base/AbstractMetaDataStorage.sol";

/**
 * @title A proxy contract for reactive contracts imported from 1.0's RVMs. Uses `MetaDataStorage` to get the implementation address.
 */
contract RvmProxy {
    /// @notice Address of the legacy (1.0) system contract.
    address private constant SYSTEM = 0x0000000000000000000000000000000000fffFfF;

    /// @notice Function selector of the standard `react()` method.
    bytes4 private constant REACT_SELECTOR = 0x0d152c2c;

    /// @notice Indicates that the transaction sender is not authorized to perform the operation.
    /// @param sender_ Unauthorized address.
    error NotAuthorized(address sender_);

    /// @notice Indicates that the call wasn't to the expected `react()` method of the target contract.
    /// @param selector_ Function selector received.
    error InvalidReactiveFunctionCall(bytes4 selector_);

    /// @notice `delegatecall` proxy for contract imported from 1.0's RVMs.
    /// @dev We don't need to support transactions with value, as there was no REACT inside RVMs.
    fallback() external {
        if (msg.sender != SYSTEM) {
            revert NotAuthorized(msg.sender);
        }

        if (msg.sig != REACT_SELECTOR) {
            revert InvalidReactiveFunctionCall(msg.sig);
        }

        (, address impl) = AbstractMetaDataStorage(SYSTEM)._rvm2rnk(address(this));
        
        DelegateCall.delegateCall(impl);
    }
}

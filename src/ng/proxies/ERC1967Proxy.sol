// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { DelegateCall } from "../lib/DelegateCall.sol";
import { ERC1967 } from "../lib/ERC1967.sol";
import { AbstractERC1967Upgradeable } from "../base/AbstractERC1967Upgradeable.sol";

/**
 * A simple ERC1967 proxy contract.
 */
contract ERC1967Proxy {
    /// @param impl_ Address of the initial implementation.
    /// @param data_ The data to be passed to implementation's `onImplUpgrade()` method. Zero-length `data_` will skip the call altogether.
    constructor(address impl_, bytes memory data_) {
        ERC1967.getImplSlot().v = impl_;

        if (data_.length > 0) {
            require(AbstractERC1967Upgradeable(address(this)).onImplUpgrade(data_));
        }
    }

    /// @notice ERC1967 `delegatecall` proxy.
    fallback() external payable {
        address impl = ERC1967.getImplSlot().v;

        DelegateCall.delegateCall(impl);
    }
}

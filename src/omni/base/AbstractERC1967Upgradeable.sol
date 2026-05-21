// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { ERC1967 } from "../lib/ERC1967.sol";
import { IERC1967Upgradeable } from "../interfaces/IERC1967Upgradeable.sol";

/**
 * @title A base class for ERC1967 upgradeable proxied contracts.
 */
abstract contract AbstractERC1967Upgradeable is IERC1967Upgradeable {
    /// @notice Indicates that the `onImplUpgrade()` call to the new implementaton returned `false`.
    error UpgradeFailed();

    /// @notice Indicates that the call was directly to an implementation contract.
    error DirectCallToImplementation();

    /// @notice A modifier for guarding methods depending on the state kept by the proxy contract.
    modifier onlyProxied() {
        _onlyProxied();
        _;
    }

    /// @notice An implementation function for the `onlyProxied` modifier.
    function _onlyProxied() internal view {
        if (ERC1967.getImplSlot().v == address(0)) {
            revert DirectCallToImplementation();
        }
    }

    /// @notice Upgrades the contract to a new implementation.
    /// @param newImpl_ New implementation's address.
    /// @param data_ Arbitrary data to be passed to the new implementation.
    /// @dev Reverts on failure.
    function _upgradeImpl(address newImpl_, bytes calldata data_) internal virtual {
        ERC1967.getImplSlot().v = newImpl_;

        if (!this.onImplUpgrade(data_)) {
            revert UpgradeFailed();
        }
    }
}

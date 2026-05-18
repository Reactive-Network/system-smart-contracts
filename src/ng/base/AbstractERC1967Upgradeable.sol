// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { ERC1967 } from "../lib/ERC1967.sol";
import { IERC1967Upgradeable } from "../interfaces/IERC1967Upgradeable.sol";

/**
 * @title A base class for ERC1967 upgradeable proxied contracts.
 */
abstract contract AbstractERC1967Upgradeable is IERC1967Upgradeable {
    /// @notice Indicates that this is an initial implementation that cannot be upgraded to.
    error InitialImplementation();

    /// @notice Indicates that the `onImplUpgrade()` call to the new implementaton returned `false`.
    error UpgradeFailed();

    /// @notice Indicates that the call was directly to an implementation contract.
    error DirectCallToImplementation();

    /// @inheritdoc IERC1967Upgradeable
    function upgradeImpl(address newImpl_, bytes calldata data_) public virtual override onlyProxied {
        ERC1967.getImplSlot().v = newImpl_;

        if (!this.onImplUpgrade(data_)) {
            revert UpgradeFailed();
        }
    }

    /// @inheritdoc IERC1967Upgradeable
    function onImplUpgrade(bytes calldata /* data_ */) public virtual override onlyProxied returns (bool /* success_ */) {
        revert InitialImplementation();
    }

    /// @notice A modifier for guarding methods depending on the state kept by the proxy contract.
    modifier onlyProxied() {
        _onlyProxied();
        _;
    }

    /// @notice An implementation function for the `onlyProxied` modifier.
    function _onlyProxied() internal view {
        if (ERC1967.getImplSlot().v == address(0)) {
            revert DirectCallToImplementation ();
        }
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

/**
 * @title An arbitrary common interface for ERC1967 upgradeable proxied contracts.
 */
interface IERC1967Upgradeable {
    /// @notice Upgrades the contract to a new implementation.
    /// @param newImpl_ New implementation's address.
    /// @param data_ Arbitrary data to be passed to the new implementation.
    /// @dev Should revert on failure.
    function upgradeImpl(address newImpl_, bytes calldata data_) external;

    /// @notice Called by the old implementation when upgrading to a new one.
    /// @param data_ Arbitrary data to be passed to the new implementation.
    /// @return success_ Indicates whether the upgrade was successful.    
    function onImplUpgrade(bytes calldata data_) external returns (bool success_);
}

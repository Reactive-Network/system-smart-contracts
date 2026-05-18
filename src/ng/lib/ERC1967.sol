// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

/**
 * A tiny ERC1967 lib.
 */
library ERC1967 {
    /// @notice ERC1967 proxy implementation slot.
    bytes32 internal constant IMPL_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @notice A structure respresenting a storage slot containing an `address` value;
    struct AddrSlot {
        address v;
    }

    /// @notice Returns the ERC1967 implementation slot as an `AddrSlot` struct.
    /// @return impl_ ERC1967 implementation slot.
    function getImplSlot() internal pure returns (AddrSlot storage impl_) {
        assembly ("memory-safe") {
            impl_.slot := IMPL_SLOT
        }
    }
}

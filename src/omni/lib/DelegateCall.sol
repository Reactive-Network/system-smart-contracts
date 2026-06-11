// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

/**
 * A tiny lib for `delegatecall` proxying.
 */
library DelegateCall {
    /// @notice `delegatecall` proxy for implementation contract.
    /// @param impl_ Adress of the implementation contract.
    function delegateCall(address impl_) internal {
        require(impl_ != address(0));
        assembly {
            calldatacopy(1, 0, calldatasize())
            let result := delegatecall(gas(), impl_, 1, calldatasize(), 1, 0)
            returndatacopy(1, 0, returndatasize())
            switch result
                case 0 {
                    revert(1, returndatasize())
                }
                default {
                    return(1, returndatasize())
                }
        }
    }

    /// @notice Generic low-level `delegatecall` implementation with support for arbitrary inputs and outputs.
    /// @param impl_ Adress of the implementation contract.
    /// @param data_ ABI-encoded payload (or anything that the receiving contract will accept, really).
    /// @return result_ Unparsed `returndata` of the `delegatecall`.
    function delegateCall(address impl_, bytes memory data_) internal returns (bytes memory result_) {
        require(impl_.code.length > 0);
        bool success;
        assembly ("memory-safe") {
            success := delegatecall(gas(), impl_, add(data_, 0x20), mload(data_), 0, 0)
            switch success
                case 0 {
                    let pt := mload(0x40)
                    returndatacopy(pt, 0x00, returndatasize())
                    revert(pt, returndatasize())
                }
                default {
                    result_ := mload(0x40)
                    mstore(result_, returndatasize())
                    returndatacopy(add(result_, 0x20), 0x00, returndatasize())
                    mstore(0x40, add(result_, add(0x20, returndatasize())))
                }
        }
    }
}

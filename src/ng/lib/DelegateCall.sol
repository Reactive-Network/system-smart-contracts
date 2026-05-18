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
                    revert(0, 0)
                }
                default {
                    return(1, returndatasize())
                }
        }
    }
}

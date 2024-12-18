// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '../lib/reactive-lib/src/libraries/SystemLib.sol';

contract DelegateProxy {
    fallback() external payable {
        address impl = getSystemContractImpl();
        assembly {
            calldatacopy(1, 0, calldatasize())
            let result := delegatecall(gas(), impl, 1, calldatasize(), 1, 0)
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

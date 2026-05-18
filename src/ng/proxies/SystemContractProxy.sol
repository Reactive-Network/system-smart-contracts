// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { DelegateCall } from "../lib/DelegateCall.sol";
import { ERC1967 } from "../lib/ERC1967.sol";

/**
 * A proxy contract for 2.0 system contract. ERC1967 upgradeable.
 */
contract SystemContractProxy {
    /// @notice `delegatecall` proxy for 2.0 system contract.
    fallback() external payable {
        address impl = ERC1967.getImplSlot().v;

        DelegateCall.delegateCall(impl);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IL1FeeOracle } from "../../../src/omni/interfaces/IL1FeeOracle.sol";

/**
 * @title An L1 fee oracle mockup charging a fixed price per byte.
 */
contract L1FeeOracleMockup is IL1FeeOracle {
    uint256 public constant FEE_PER_BYTE = 1000;

    function getL1FeeUpperBound(uint256 unsignedTxSize_) external pure returns (uint256 fee_) {
        return unsignedTxSize_ * FEE_PER_BYTE;
    }
}

/**
 * @title An L1 fee oracle mockup that always reverts, e.g. a pre-Fjord `GasPriceOracle`.
 */
contract RevertingL1FeeOracleMockup is IL1FeeOracle {
    function getL1FeeUpperBound(uint256 /* unsignedTxSize_ */) external pure returns (uint256 /* fee_ */) {
        revert();
    }
}

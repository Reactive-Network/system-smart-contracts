// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

/**
 * @title Interface for estimating the L1 data fee of an L2 transaction.
 * @dev Matches the OP Stack `GasPriceOracle` predeploy at `0x420000000000000000000000000000000000000F` (Fjord+),
 *      so it can be used directly on OP Stack chains. Other L2s need an adapter implementing the same method.
 */
interface IL1FeeOracle {
    /// @notice Returns an upper bound for the L1 data fee of a transaction of the given size.
    /// @param unsignedTxSize_ Size of the RLP-encoded unsigned transaction in bytes.
    /// @return fee_ L1 data fee upper bound in wei.
    function getL1FeeUpperBound(uint256 unsignedTxSize_) external view returns (uint256 fee_);
}

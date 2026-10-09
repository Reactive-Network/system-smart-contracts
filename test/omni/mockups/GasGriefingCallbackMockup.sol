// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

/**
 * @title A callback contract mockup that burns all the gas it is given, including on `pay()`.
 */
contract GasBurningCallbackMockup {
    fallback() external payable {
        assembly ("memory-safe") {
            for {} 1 {} {}
        }
    }
}

/**
 * @title A callback contract mockup returning as much data as its gas allows, including on `pay()`.
 */
contract ReturnBombCallbackMockup {
    fallback() external payable {
        uint256 g = (gasleft() * 9) / 10;
        // Largest `w` such that memory expansion cost `3w + w^2 / 512` fits into `g`.
        uint256 w = _sqrt(512 * g + 768 * 768) - 768;
        assembly ("memory-safe") {
            return(0, mul(w, 32))
        }
    }

    function _sqrt(uint256 x_) internal pure returns (uint256 y_) {
        y_ = x_;
        uint256 z = (x_ + 1) / 2;
        while (z < y_) {
            y_ = z;
            z = (x_ / z + z) / 2;
        }
    }
}

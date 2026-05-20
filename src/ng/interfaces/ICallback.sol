// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

/// @title List of supported callback configuration versions.
enum CallbackVersion { V_1_0 }

/// @title Callback configuration struct for legacy-style callbacks.
struct CallbackConfiguration_V_1_0 {
    uint256 chainId;
    address recipient;
    uint64 gasLimit;
    bytes payload;
}

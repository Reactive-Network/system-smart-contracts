// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { SystemContract } from "../../../src/ng/SystemContract.sol";

/**
 * @title A mockup of system contract with alternate behavior, that also validates its own upgrade data.
 */
contract ConditionallyUpgradingSystemContractMockup is SystemContract {
    error Failure();

    function onImplUpgrade(bytes calldata data_) public virtual override onlyProxied returns (bool /* success_ */) {
        return data_.length != 0;
    }

    function subscribe(
        uint256,
        address,
        uint256,
        uint256,
        uint256,
        uint256
    ) public virtual override onlyProxied {
        revert Failure();
    }
}

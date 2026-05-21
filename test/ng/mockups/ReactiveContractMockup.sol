// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IReactive, LogRecord } from "../../../src/omni/interfaces/IReactive.sol";

/**
 * A trivial reactive contract mockup.
 */
contract ReactiveContractMockup is IReactive {
    bool public _vm;

    event TestEvent();

    constructor(bool vm_) {
        _vm = vm_;
    }

    receive() external payable {
    }

    function react(LogRecord calldata /* log */) external {
        require(_vm);

        emit TestEvent();
    }

    function pay(uint256 amount_) external {
        (bool success,) = payable(msg.sender).call{ value: amount_ }(new bytes(0));
        require(success);
    }
}

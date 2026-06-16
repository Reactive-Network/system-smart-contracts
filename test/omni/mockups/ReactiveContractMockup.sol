// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";

/**
 * A trivial reactive contract mockup.
 */
contract ReactiveContractMockup is IReactive {
    address payable public constant SYSTEM = payable(0x0000000000000000000000000000000000fffFfF);

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

    function coverDebt() external {
        (bool success,) = SYSTEM.call{ value: ISystemContract(SYSTEM).debt(address(this)) }(new bytes(0));
        require(success);
    }
}

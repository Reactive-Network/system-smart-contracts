// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IPayer } from "@reactive/src/interfaces/IPayer.sol";

/**
 * A trivial callback contract mockup.
 */
contract CallbackContractMockup is IPayer {
    event TestEvent(string msg_);

    receive() external payable {
    }

    function callback(address /* sender_ */, string memory msg_) external {
        require(bytes(msg_).length > 0);
        emit TestEvent(msg_);
    }

    function pay(uint256 amount_) external {
        (bool success,) = payable(msg.sender).call{ value: amount_ }(new bytes(0));
        require(success);
    }
}

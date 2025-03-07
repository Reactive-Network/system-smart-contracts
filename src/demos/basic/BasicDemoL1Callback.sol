// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity >=0.8.0;

import '../../../lib/reactive-lib/src/abstract-base/AbstractCallback.sol';

contract BasicDemoL1Callback is AbstractCallback {
    event CallbackReceived(
        address indexed origin,
        address indexed sender,
        address indexed reactive_sender
    );

    constructor(address _proxy) AbstractCallback(_proxy) payable {
    }

    function callback(address sender) external {
        emit CallbackReceived(
            tx.origin,
            msg.sender,
            sender
        );
    }
}

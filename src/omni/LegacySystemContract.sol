// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { AbstractMetaDataStorage } from "./base/AbstractMetaDataStorage.sol";
import { SystemContract } from "../SystemContract.sol";

/**
 * @title An 1.0 system contract for supporting legacy reacive contracts in 2.0 networks.
 */
contract LegacySystemContract is SystemContract, AbstractMetaDataStorage {
    /// @notice Fixed address for node-injected transactions.
    address public constant INJ_ADDR = 0x038E06667e42782E571EaB20432b9237F9bD6B82;

    /// @notice Indicates that the method may only be called through node-injected transactions.
    error OnlyInjected();

    /// @notice Proxy method for calling `react()` methods on reactive contracts imported from RVMs.
    /// @param rvmAddress_ Generated address for a legacy reactive contracted imported from a 1.0 RVM.
    /// @param log_ Log record to pass to the reactive contract.
    function trigger(IReactive rvmAddress_, IReactive.LogRecord calldata log_) external onlyInjected {
        ContractMapping memory meta = _rvm2rnk[address(rvmAddress_)];
        address rnkAddress = meta._contract;
        require(rnkAddress != address(0));
        require(debts[address(rnkAddress)] == 0, "Reactive transaction target currently in debt");
        uint256 gasInit = gasleft();
        rvmAddress_.react(log_);
        uint256 price = tx.gasprice > block.basefee ? tx.gasprice : block.basefee;
        uint256 adjustedGasPrice = (extra_gas_fee + gasInit - gasleft()) * price;
        __whitelisted = true;
        _charge(rnkAddress, adjustedGasPrice);
        __whitelisted = false;
        uint256 kickback = (adjustedGasPrice * kickback_coefficient_promille) / 1000;
        bool result = true;
        if (kickback > 0 && kickback <= address(this).balance) {
            (result,) = tx.origin.call{ value: kickback }(new bytes(0));
        }
        if (!result) {
            emit Unkickbackable();
        }
    }

    /// @notice Triggers the generation of the `CronFoo()` events by the system contract.
    function triggerCron() external onlyInjected {
        _cron(block.number);
    }

    /// @notice A modifier from guarding methods that may only be called through node-injected transactions.
    modifier onlyInjected() {
        _onlyInjected();
        _;
    }

    /// @notice An implementation of the `onlyInjected` modifier.
    function _onlyInjected() internal view {
        if (msg.sender != INJ_ADDR) {
            revert OnlyInjected();
        }
    }
}

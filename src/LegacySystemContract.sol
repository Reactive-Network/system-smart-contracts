// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { MetaDataStorage } from "./MetaDataStorage.sol";
import { SystemContract } from "./SystemContract.sol";

/// @title Standard structure for passing around EVM-style log record data.
struct LogRecord {
    uint256 chain_id;
    address _contract;
    uint256 topic_0;
    uint256 topic_1;
    uint256 topic_2;
    uint256 topic_3;
    bytes data;
    uint256 block_number;
    uint256 op_code;
    uint256 block_hash;
    uint256 tx_hash;
    uint256 log_index;
}

/// @title Interface for reactive contracts.
interface IReactive {
    /// @notice Entry point for handling new event notifications.
    /// @param log Data structure containing the information about the intercepted log record.
    function react(LogRecord calldata log) external;
}

/**
 * An 1.0 system contract for supporting legacy reacive contracts in 2.0 networks.
 */
contract LegacySystemContract is SystemContract {
    /// @notice Address of the meta data storage contract.
    /// @dev Update before compiling the artifacts for generating the genesis block.
    MetaDataStorage private constant METADATA = MetaDataStorage(0x7f19DAc8a241eAc2DD355E85fF1c2C0CDB940b90);
    
    /// @notice Proxy method for calling `react()` methods on reactive contracts imported from RVMs.
    /// @param rvmAddress_ Generated address for a legacy reactive contracted imported from a 1.0 RVM.
    /// @param log_ Log record to pass to the reactive contract.
    function trigger(IReactive rvmAddress_, LogRecord calldata log_) external callbackOnly {
        (, address rnkAddress) = METADATA._rvm2rnk(address(rvmAddress_));
        require(rnkAddress != address(0));
        require(debts[address(rnkAddress)] == 0, "Reactive transaction target currently in debt");
        uint256 gasInit = gasleft();
        rvmAddress_.react(log_);
        uint256 price = tx.gasprice > block.basefee ? tx.gasprice : block.basefee;
        uint256 adjustedGasPrice = (extra_gas_fee + gasInit - gasleft()) * ((price * gas_price_coefficient_promille) / 1000);
        _charge(rnkAddress, adjustedGasPrice);
        uint256 kickback = (adjustedGasPrice * kickback_coefficient_promille) / 1000;
        bool result = false;
        if (kickback <= address(this).balance) {
            (result,) = tx.origin.call{ value: kickback }(new bytes(0));
        }
        if (!result) {
            emit Unkickbackable();
        }

    }
}

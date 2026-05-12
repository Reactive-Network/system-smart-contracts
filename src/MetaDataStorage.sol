// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

/**
 * @title Contract for publicly storing the meta data of the legacy RVM contracts.
 */
contract MetaDataStorage {
    /// @notice Dedicated address allowed to perform the initialization of this contract.
    /// @dev Update before compiling the artifacts for generating the genesis block.
    address public constant ADMIN = 0x7f19DAc8a241eAc2DD355E85fF1c2C0CDB940b90;

    /// @notice Indicates that the transaction sender is not authorized to perform the operation.
    /// @param sender_ Unauthorized address.
    error NotAuthorized(address sender_);

    /// @notice Indicates that the contract has already been initialized, and will not accept further updates.
    error AlreadyFinalized();

    /// @notice Two-way mapping of native RVM addresses with flat address spece of RNK, with added field for RVM ID.
    struct RnkRvmMetaData {
        address rvmContract;
        address rvmId;
        address rnkContract;
    }

    /// @notice Return value format for RVM to RNK and RNK to RVM mappings.
    struct ContractMapping {
        address rvmId;
        address _contract;
    }

    /// @notice Indicates that the contract state has been finalized.
    bool public _finalized;

    /// @notice Maps native RVM addresses to generated RNK addresses.
    mapping(address => ContractMapping) public _rvm2rnk;

    /// @notice Maps generated RNK addresses to native RVM addresses.
    mapping(address => ContractMapping) public _rnk2rvm;

    /// @notice Accepts a chunk of contract meta data, and updates the state accordingly.
    /// @param _mappings A chunk of meta data.
    function updateMetaData(RnkRvmMetaData[] memory _mappings) public onlyAdmin onlyUnfinalized {
        for (uint256 ix = 0; ix != _mappings.length; ++ix) {
            _rvm2rnk[_mappings[ix].rvmContract] = ContractMapping({
                rvmId: _mappings[ix].rvmId,
                _contract: _mappings[ix].rnkContract
            });
            _rnk2rvm[_mappings[ix].rnkContract] = ContractMapping({
                rvmId: _mappings[ix].rvmId,
                _contract: _mappings[ix].rvmContract
            });
        }
    }

    /// @notice Finalized the contract, preventing future updates.
    function finalize() public onlyAdmin onlyUnfinalized {
        _finalized = true;
    }

    /// @notice A modifier preventing calls from unauthorized addresses.
    modifier onlyAdmin() {
        _onlyAdmin();

        _;
    }

    /// @notice A modifier preventing call to a finalized contract.
    modifier onlyUnfinalized() {
        _onlyUnfinalized();

        _;
    }

    /// @notice An implementation of the `onlyAdmin` modifier.
    function _onlyAdmin() private view {
        if (msg.sender != ADMIN) {
            revert NotAuthorized(msg.sender);
        }
    }

    /// @notice An implementation of the `onlyUnfinalized` modifier.
    function _onlyUnfinalized() private view {
        if (_finalized) {
            revert AlreadyFinalized();
        }
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IERC1967Upgradeable } from "./interfaces/IERC1967Upgradeable.sol";
import { AbstractProxiedPayableBridge } from "./base/AbstractProxiedPayableBridge.sol";

/**
 * @title New version of callback proxy contract for reactive network.
 */
contract CallbackProxy is AbstractProxiedPayableBridge {
    /// @notice Indicates that this is an initial implementation that cannot be upgraded to.
    error InitialImplementation();

    /// @notice Indicates that the supplied callback configuration version is not supported.
    /// @param version_ Callback configuration version provided.
    error InvalidCallbackVersion(ISystemContract.CallbackVersion version_);

    /// @notice Indicates that a callback target address is not a contract.
    /// @param target_ Callback target address.
    error NotAContract(address target_);

    /// @notice Indicates that the allocated gas limit is too low to perform the operation.
    /// @param remaining_ Gas remaining at the point of checking.
    /// @param required_ Minimum gas required.
    error InsufficientGas(uint256 remaining_, uint256 required_);

    /// @param target_ Target contract for the callback.
    /// @param payload_ Payload sent to the contract.
    event CallbackFailure(address indexed target_, bytes payload_);

    /// @notice Structure contraining initial contract configuration.
    struct InitialConfig {
        address owner;
        uint256 maxChargeGas;
        uint256 extraGas;
        uint256 gasPriceCoeffPer1000;
        address[] callbackSenders;
    }

    /// @notice Indicates that the proxied contract has been initializied.
    bool public _initialized;

    /// @notice Address of the contract's owner.
    address public _owner;

    /// @inheritdoc IERC1967Upgradeable
    function upgradeImpl(address newImpl_, bytes calldata data_) public virtual override onlyProxied onlyOwner {
        _upgradeImpl(newImpl_, data_);
    }

    /// @inheritdoc IERC1967Upgradeable
    function onImplUpgrade(bytes calldata data_) public virtual override onlyProxied returns (bool /* success_ */) {
        require(!_initialized);

        _initialized = true;

        InitialConfig memory config = abi.decode(data_, (InitialConfig));

        _owner = config.owner;
        _maxChargeGas = config.maxChargeGas;
        _extraGas = config.extraGas;
        _gasPriceCoeffPer1000 = config.gasPriceCoeffPer1000;

        _updateOperators(config.callbackSenders, true);

        return true;
    }

    /// @notice Adds a list of addresses provided to the callback sender list.
    /// @param callbackSenders_ List of new callback senders.
    function addCallbackSenders(address[] calldata callbackSenders_) public virtual onlyProxied onlyOwner {
        _updateOperators(callbackSenders_, true);
    }

    /// @notice Removes a list of addresses provided from the callback sender list.
    /// @param callbackSenders_ List of callback senders to be removed.
    function removeCallbackSenders(address[] calldata callbackSenders_) public virtual onlyProxied onlyOwner {
        _updateOperators(callbackSenders_, false);
    }

    /// @notice Performs callback delivery on this network.
    /// @param version_ Version of the callback configuration used.
    /// @param config_  ABI-encoded callback configration in a format corresponding to the version specified.
    function deliverCallback(ISystemContract.CallbackVersion version_, bytes memory config_) external virtual onlyProxied onlyOperators {
        if (version_ == ISystemContract.CallbackVersion.V_1_0) {
            ISystemContract.CallbackConfiguration_V_1_0 memory config = abi.decode(config_, (ISystemContract.CallbackConfiguration_V_1_0));

            _callback(config.recipient, config.payload);
        } else {
            revert InvalidCallbackVersion(version_);
        }
    }

    /// @inheritdoc AbstractProxiedPayableBridge
    function _onlyOwner() internal virtual override view {
        if (msg.sender != _owner) {
            revert NotAuthorized();
        }
    }

    /// @notice Internal implementation of the callback delivery.
    /// @param contract_ Address of the callback recipient contract.
    /// @param payload_ Payload to be send to the target contract.
    function _callback(address contract_, bytes memory payload_) internal {
        if (_debts[address(contract_)] > 0) {
            revert InDebt(address(contract_), _debts[address(contract_)]);
        }

        if (contract_.code.length == 0) {
            revert NotAContract(contract_);
        }

        uint256 overhead = _extraGas + _maxChargeGas;
        uint256 gasInit = gasleft();

        if (gasInit <= overhead) {
            revert InsufficientGas(gasInit, overhead);
        }

        (bool result,) = contract_.call{ gas: gasInit - overhead }(payload_);

        if (!result) {
            emit CallbackFailure(contract_, payload_);
        }

        uint256 price = tx.gasprice > block.basefee ? tx.gasprice : block.basefee;
        uint256 adjustedGasPrice = (_extraGas + gasInit - gasleft()) * ((price * _gasPriceCoeffPer1000) / 1000);

        __whitelisted = true;
        _charge(address(contract_), adjustedGasPrice);
        __whitelisted = false;
        
        uint256 kickback = adjustedGasPrice;

        result = true;

        if (kickback > 0 && kickback <= address(this).balance) {
            (result,) = tx.origin.call{ value: kickback }(new bytes(0));
        }

        if (!result) {
            emit Unkickbackable();
        }
    }
}

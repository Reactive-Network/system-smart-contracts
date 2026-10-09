// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IERC1967Upgradeable } from "./interfaces/IERC1967Upgradeable.sol";
import { IL1FeeOracle } from "./interfaces/IL1FeeOracle.sol";
import { AbstractProxiedPayableBridge } from "./base/AbstractProxiedPayableBridge.sol";

/**
 * @title New version of callback proxy contract for reactive network.
 */
contract CallbackProxy is AbstractProxiedPayableBridge {
    /// @notice Approximate size of the RLP-encoded unsigned transaction envelope, excluding calldata.
    uint256 public constant TX_ENVELOPE_SIZE = 64;

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
        uint256 calldataGasPerByte;
        IL1FeeOracle l1FeeOracle;
        address[] callbackSenders;
    }

    /// @notice Indicates that the proxied contract has been initializied.
    bool public _initialized;

    /// @notice Address of the contract's owner.
    address public _owner;

    /// @notice Gas charged per byte of the transaction's calldata, on top of the metered gas.
    uint256 public _calldataGasPerByte;

    /// @notice Optional L1 data fee oracle; `address(0)` on L1 and on L2s without L1 data fees.
    IL1FeeOracle public _l1FeeOracle;

    /// @inheritdoc IERC1967Upgradeable
    function upgradeImpl(address newImpl_, bytes calldata data_) public virtual override onlyProxied onlyOwner {
        _upgradeImpl(newImpl_, data_);
    }

    /// @inheritdoc IERC1967Upgradeable
    /// @dev On a fresh proxy `data_` is an ABI-encoded `InitialConfig`. When upgrading an already initialized proxy,
    ///      `data_` is `abi.encode(uint256 calldataGasPerByte, IL1FeeOracle l1FeeOracle)` for the fields added since.
    function onImplUpgrade(bytes calldata data_) public virtual override onlyProxied returns (bool /* success_ */) {
        if (_initialized) {
            // Only reachable through `upgradeImpl()`, which calls back into the proxy.
            if (msg.sender != address(this)) {
                revert NotAuthorized();
            }

            (_calldataGasPerByte, _l1FeeOracle) = abi.decode(data_, (uint256, IL1FeeOracle));

            return true;
        }

        _initialized = true;

        InitialConfig memory config = abi.decode(data_, (InitialConfig));

        _owner = config.owner;
        _maxChargeGas = config.maxChargeGas;
        _extraGas = config.extraGas;
        _gasPriceCoeffPer1000 = config.gasPriceCoeffPer1000;
        _calldataGasPerByte = config.calldataGasPerByte;
        _l1FeeOracle = config.l1FeeOracle;

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

    /// @notice Updates the gas charged per byte of the transaction's calldata.
    /// @param calldataGasPerByte_ New per-byte gas charge.
    function setCalldataGasPerByte(uint256 calldataGasPerByte_) public virtual onlyProxied onlyOwner {
        _calldataGasPerByte = calldataGasPerByte_;
    }

    /// @notice Updates the L1 data fee oracle.
    /// @param l1FeeOracle_ New oracle address, or `address(0)` to disable L1 data fee charging.
    function setL1FeeOracle(IL1FeeOracle l1FeeOracle_) public virtual onlyProxied onlyOwner {
        _l1FeeOracle = l1FeeOracle_;
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

        uint256 gasStart = gasleft();
        uint256 l1Fee = _l1Fee();
        uint256 overhead = _extraGas + _maxChargeGas + _failureEventGas(payload_.length);
        uint256 gasInit = gasleft();

        if (gasInit <= overhead) {
            revert InsufficientGas(gasInit, overhead);
        }

        bool result;
        uint256 callbackGas = gasInit - overhead;

        // Return data is not copied, so the callback cannot eat into the reserve with a huge return value.
        assembly ("memory-safe") {
            result := call(callbackGas, contract_, 0, add(payload_, 0x20), mload(payload_), 0, 0)
        }

        if (!result) {
            emit CallbackFailure(contract_, payload_);
        }

        uint256 price = tx.gasprice > block.basefee ? tx.gasprice : block.basefee;
        uint256 gasCharged = _extraGas + gasStart - gasleft() + _calldataGasPerByte * msg.data.length;
        uint256 fee = gasCharged * ((price * _gasPriceCoeffPer1000) / 1000) + (l1Fee * _gasPriceCoeffPer1000) / 1000;

        __whitelisted = true;
        _charge(address(contract_), fee);
        __whitelisted = false;
        
        uint256 kickback = fee;

        result = true;

        if (kickback > 0 && kickback <= address(this).balance) {
            (result,) = tx.origin.call{ value: kickback }(new bytes(0));
        }

        if (!result) {
            emit Unkickbackable();
        }
    }

    /// @notice Returns the L1 data fee estimate for the current transaction, or zero if unavailable.
    /// @return fee_ L1 data fee in wei.
    function _l1Fee() internal view returns (uint256 fee_) {
        if (address(_l1FeeOracle) != address(0)) {
            try _l1FeeOracle.getL1FeeUpperBound(msg.data.length + TX_ENVELOPE_SIZE) returns (uint256 fee) {
                fee_ = fee;
            } catch {
            }
        }
    }

    /// @notice Returns the gas needed to emit `CallbackFailure` for a payload of the given size.
    /// @dev Covers the per-byte log data cost, copying, and memory expansion past the current free memory pointer.
    ///      Fixed costs of the log are expected to be covered by `_extraGas`.
    /// @param length_ Payload length in bytes.
    /// @return gas_ Payload-dependent gas cost of the event.
    function _failureEventGas(uint256 length_) internal pure returns (uint256 gas_) {
        uint256 freeMem;

        assembly ("memory-safe") {
            freeMem := mload(0x40)
        }

        // ABI-encoded event data: offset, length and the padded payload.
        uint256 words = 2 + (length_ + 31) / 32;
        uint256 memWords = (freeMem + 31) / 32;
        uint256 newMemWords = memWords + words;

        return 8 * 32 * words
            + 3 * words
            + (3 * newMemWords + (newMemWords * newMemWords) / 512)
            - (3 * memWords + (memWords * memWords) / 512);
    }
}

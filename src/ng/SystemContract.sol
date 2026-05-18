// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { LogRecord, IReactive } from "./interfaces/IReactive.sol";
import { AbstractERC1967Upgradeable } from "./base/AbstractERC1967Upgradeable.sol";
import { AbstractSubscriptionService } from "./base/AbstractSubscriptionService.sol";

/**
 * System contract for the 2.0 version of the reactive network.
 */
contract SystemContract is AbstractERC1967Upgradeable, AbstractSubscriptionService {
    /// @notice Address used for network initialization.
    address public constant INIT_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;

    /// @notice Privileged network administrator address.
    address public constant OWNER_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;

    /// @notice Gas limit for reactive transaction payments.
    uint256 public constant MAX_CHARGE_GAS = 100000;

    /// @notice Indicates that the contract has already been initialized.
    error AlreadyInitialized();

    /// @notice Indicates that the message sender is not authorized to perform the operation.
    error NotAuthorized();

    /// @notice Indicates that reactive the contract is currently in debt.
    /// @param contract_ Reactive contract's address.
    /// @param debt_ Current debt.
    error InDebt(address contract_, uint256 debt_);

    /// @notice Indicates that the supplied callback configuration version is not supported.
    /// @param version_ Callback configuration version provided.
    error InvalidCallbackVersion(CallbackVersion version_);

    /// @notice List of supported callback configuration versions.
    enum CallbackVersion { V_1_0 }

    /// @notice Callback configuration struct for legacy-style callbacks.
    struct CallbackConfiguration_V_1_0 {
        uint256 chainId;
        address recipient;
        uint64 gasLimit;
        bytes payload;
    }

    /// @notice Indicates a pending callback request received from a reactive contract.
    /// @param chainId Destination chain ID.
    /// @param sender Message sender's address.
    /// @param recipient Destination contract's address.
    /// @param version Callback configuration version.
    /// @param configuration ABI-encoded callback configuration struct in the format matching the `version` provided.
    event CallbackRequest(
        uint256 indexed chainId,
        address indexed sender,
        address indexed recipient,
        CallbackVersion version,
        bytes configuration
    );

    /// @notice A struct for suppling callback info to the on-chain callback data storage.
    struct CallbackInfo {
        uint256 block_number;
        address rvm_id;
        uint256 rvm_txhash;
        uint256 callback_ix;
        uint256 dest_chain_id;
        uint256 dest_txhash;
        bytes err;
    }

    /// @notice A struct for returning the requested information about a given callback from the callback storage.
    struct CallbackStore {
        uint256 block_number;
        address rvm_id;
        uint256 callback_ix;
        uint256 dest_chain_id;
        uint256 dest_txhash;
        bytes err;
    }

    /// @notice Indicates the payment failure on the part of the reactive contract.
    /// @param contract_ Address of the reactive contract in question.
    /// @param amount_ Requested payment amount.
    event PaymentFailure(address indexed contract_, uint256 indexed amount_);

    /// @notice Indicates that the validator failed to accept reactive transaction kickback.
    event Unkickbackable();

    /// @notice Requests a given contract to be blacklisted.
    /// @param reactive_ Reactive contract's address.
    event BlacklistContract(address indexed reactive_);

    /// @notice Requests a given contract to be removed from the blacklist.
    /// @param reactive_ Reactive contract's address.
    event WhitelistContract(address indexed reactive_);

    /// @notice Indicates a fresh update to the on-chain callback sotrage.
    event CallbackPosted(
        uint256 indexed blockNumber_,
        address indexed reactiveContract_,
        uint256 indexed rvmTxHash_,
        uint256 callbackIx_,
        uint256 destChainId_,
        uint256 destTxHash_,
        bytes err
    );

    /// @notice Indicates that the system contract has been successfully initialized.
    bool public _initialized;

    /// @notice Indicates that the address is a known validator.
    mapping(address => bool) internal _validators;

    /// @notice Reactive contracts' current reserves for paying for reactive transactions.
    mapping(address => uint256) public _reserves;

    /// @notice Outstanding debts of reactive contracts.
    mapping(address => uint256) public _debts;

    /// @notice On-chain storage for callbacks successfully posted to destination chains.
    mapping(uint256 => CallbackStore[]) public _callbacks;

    /// @inheritdoc AbstractERC1967Upgradeable
    function upgradeImpl(address newImpl_, bytes calldata data_) public virtual override onlyNetworkAdmin {
        super.upgradeImpl(newImpl_, data_);
    }

    /// @notice Adds a list of addresses provided to the validator set.
    /// @param validators_ List of new validator addresses.
    function initialize(address[] memory validators_) external onlyProxied onlyInitializer {
        _init(validators_);
    }

    /// @notice Adds a list of addresses provided to the validator set.
    /// @param validators_ List of new validator addresses.
    function addValidators(address[] calldata validators_) external onlyProxied onlyNetworkAdmin {
        for (uint256 ix = 0; ix != validators_.length; ++ix) {
            _validators[validators_[ix]] = true;
        }
    }

    /// @notice Removes a list of addresses provided from the validator set.
    /// @param validators_ List of validators to be evicted.
    function removeCallbackSenders(address[] calldata validators_) external onlyProxied onlyNetworkAdmin {
        for (uint256 ix = 0; ix != validators_.length; ++ix) {
            _validators[validators_[ix]] = false;
        }
    }

    /// @notice Method for covering reactive transaction debts.
    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    /// @notice Method for covering reactive transaction debts.
    /// @param contract_ Address of the reactive contract the balance of which should be updated.
    function depositTo(address contract_) external payable {
        _deposit(contract_, msg.value);
    }

    /// @notice Returns the reactive contract's current reserves.
    /// @param contract_ Address of the reactive contract.
    /// @param reserves_ Current reserves.
    /// @dev For compatibility with the legacy system contract.
    function reserves(address contract_) external view returns (uint256 reserves_) {
        return _reserves[contract_];
    }

    /// @notice Returns the reactive contract's outstanding debt.
    /// @param contract_ Address of the reactive contract.
    /// @param debt_ Outstanding debt.
    /// @dev For compatibility with the legacy system contract.
    function debt(address contract_) external view returns (uint256 debt_) {
        return _debts[contract_];
    }

    /// @notice Returns the reactive contract's outstanding debt.
    /// @param contract_ Address of the reactive contract.
    /// @param debt_ Outstanding debt.
    /// @dev For compatibility with the legacy system contract.
    function debts(address contract_) external view returns (uint256 debt_) {
        return _debts[contract_];
    }

    /// @notice Stores the provided callback data on-chain.
    /// @param callbacks_ List of callbacks to be stored.
    function storeCallbacks(CallbackInfo[] calldata callbacks_) external onlyProxied onlyValidator {
        for (uint256 ix = 0; ix != callbacks_.length; ++ix) {
            emit CallbackPosted(
                callbacks_[ix].block_number,
                callbacks_[ix].rvm_id,
                callbacks_[ix].rvm_txhash,
                callbacks_[ix].callback_ix,
                callbacks_[ix].dest_chain_id,
                callbacks_[ix].dest_txhash,
                callbacks_[ix].err
            );
            _callbacks[callbacks_[ix].rvm_txhash].push(CallbackStore(
                callbacks_[ix].block_number,
                callbacks_[ix].rvm_id,
                callbacks_[ix].callback_ix,
                callbacks_[ix].dest_chain_id,
                callbacks_[ix].dest_txhash,
                callbacks_[ix].err
            ));
        }
    }

    /// @notice Fetches the known callback data associated with a given reactive transaction.
    /// @param rvmTxHash_ The hash of the reactive transaction.
    /// @return callbacks_ List of known callbacks.
    function getCallbacks(uint256 rvmTxHash_) external view onlyProxied returns (CallbackStore[] memory callbacks_) {
        return _callbacks[rvmTxHash_];
    }

    /// @notice Requests blacklisting of a given reactive contract.
    /// @param reactive_ Reactive contract's address.
    function blacklist(address reactive_) external onlyProxied onlyNetworkAdmin {
        _blacklist(reactive_);
    }

    /// @notice Requests whitelisting of a given reactive contract.
    /// @param reactive_ Reactive contract's address.
    function whitelist(address reactive_) external onlyProxied onlyNetworkAdmin {
        _whitelist(reactive_);
    }

    /// @notice Requests the posting of a callback to some destination network.
    /// @param version_ Version of the callback configuration used.
    /// @param config_  ABI-encoded callback configration in a format corresponding to the version specified.
    function requestCallback(CallbackVersion version_, bytes memory config_) public onlyProxied {
        _requestCallback(version_, config_);
    }

    /// @notice Requests the posting of a legacy style callback to some destination network.
    /// @param config_  Callback configration in V_1_0 format.
    function requestCallback(CallbackConfiguration_V_1_0 memory config_) public onlyProxied {
        _requestCallback(CallbackVersion.V_1_0, abi.encode(config_));
    }

    /// @notice Proxy method for calling `react()` methods on reactive contracts.
    /// @param contract_ Generated address for a legacy reactive contracted imported from a 1.0 RVM.
    /// @param log_ Log record to pass to the reactive contract.
    function trigger(IReactive contract_, LogRecord calldata log_) external onlyProxied onlyValidator {
        if (_debts[address(contract_)] > 0) {
            revert InDebt(address(contract_), _debts[address(contract_)]);
        }

        uint256 gasInit = gasleft();

        contract_.react(log_);

        uint256 price = tx.gasprice > block.basefee ? tx.gasprice : block.basefee;
        uint256 adjustedGasPrice = (gasInit - gasleft()) * price;

        _charge(address(contract_), adjustedGasPrice);
        
        uint256 kickback = adjustedGasPrice;

        bool result = false;

        if (kickback <= address(this).balance) {
            (result,) = tx.origin.call{ value: kickback }(new bytes(0));
        }

        if (!result) {
            emit Unkickbackable();
        }

    }

    /// @notice Modifier for guarding the methods that may only be called at network initialization.
    modifier onlyInitializer() {
        _onlyInitializer();
        _;
    }

    /// @notice Modifier for guarding the methods that may only be called by the designated network administrator.
    modifier onlyNetworkAdmin() {
        _onlyNetworkAdmin();
        _;
    }

    /// @notice Modifier for guarding the methods that may only be called by network validators.
    modifier onlyValidator() {
        _onlyValidator();
        _;
    }

    /// @notice Implementation for the `onlyInitializer` modifier.
    function _onlyInitializer() internal view {
        require(msg.sender == INIT_ADDR);
    }

    /// @notice Implementation for the `onlyNetworkAdmin` modifier.
    function _onlyNetworkAdmin() internal view {
        require(msg.sender == OWNER_ADDR);
    }

    /// @notice Implementation for the `onlyValidator` modifier.
    function _onlyValidator() internal view {
        if (!_validators[msg.sender]) {
            revert NotAuthorized();
        }
    }

    /// @notice Adds a list of addresses provided to the validator set.
    /// @param validators_ List of new validator addresses.
    function _init(address[] memory validators_) internal {
        if (_initialized) {
            revert AlreadyInitialized();
        }

        _initialized = true;

        _validators[OWNER_ADDR] = true;

        for (uint256 ix = 0; ix != validators_.length; ++ix) {
            _validators[validators_[ix]] = true;
        }
    }

    /// @notice Deposits the specified amount to a given contract's balance.
    /// @param contract_ Reactive contract's address.
    /// @param amount_ Amount to be added to the balance.
    function _deposit(address contract_, uint256 amount_) internal {
        if (amount_ > 0) {
            if (_debts[contract_] > 0) {
                if (amount_ < _debts[contract_]) {
                    _debts[contract_] -= amount_;
                } else {
                    uint256 remainder = amount_ - _debts[contract_];
                    _debts[contract_] = 0;
                    _whitelist(contract_);
                    _deposit(contract_, remainder);
                }
            } else {
                _reserves[contract_] += amount_;
            }
        }
    }

    /// @notice Attempt to charge the given reactive contract for the amount specified.
    /// @param contract_ Reactive contract's address.
    /// @param amount_ Amount to be charged.
    function _charge(address contract_, uint256 amount_) internal {
        if (amount_ > 0) {
            if (_reserves[contract_] > 0) {
                if (amount_ <= _reserves[contract_]) {
                    _reserves[contract_] -= amount_;
                } else {
                    uint256 remainder = amount_ - _reserves[contract_];
                    _reserves[contract_] = 0;
                    _charge(contract_, remainder);
                }
            } else {
                uint256 currentDebt = _debts[contract_];
                _debts[contract_] += amount_;
                bytes memory payload = abi.encodeWithSignature("pay(uint256)", _debts[contract_]);
                (bool success,) = contract_.call{ gas: MAX_CHARGE_GAS }(payload);
                if (!success) {
                    emit PaymentFailure(contract_, _debts[contract_]);
                }
                if (currentDebt == 0 && _debts[contract_] > 0) {
                    _blacklist(contract_);
                }
            }
        }
    }

    /// @notice Requests the posting of a callback to some destination network.
    /// @param version_ Version of the callback configuration used.
    /// @param config_  ABI-encoded callback configration in a format corresponding to the version specified.
    function _requestCallback(CallbackVersion version_, bytes memory config_) internal {
        if (version_ == CallbackVersion.V_1_0) {
            CallbackConfiguration_V_1_0 memory config = abi.decode(config_, (CallbackConfiguration_V_1_0));

            emit CallbackRequest(config.chainId, msg.sender, config.recipient, version_, config_);
        } else {
            revert InvalidCallbackVersion(version_);
        }
    }

    /// @notice Requests blacklisting of a given reactive contract.
    /// @param reactive_ Reactive contract's address.
    function _blacklist(address reactive_) internal {
        emit BlacklistContract(reactive_);
    }

    /// @notice Requests whitelisting of a given reactive contract.
    /// @param reactive_ Reactive contract's address.
    function _whitelist(address reactive_) internal {
        emit WhitelistContract(reactive_);
    }
}

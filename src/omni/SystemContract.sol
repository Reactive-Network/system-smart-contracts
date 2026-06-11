// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { ISystemContract } from "@reactive/src/interfaces/ISystemContract.sol";
import { IReactive } from "@reactive/src/interfaces/IReactive.sol";
import { IERC1967Upgradeable } from "./interfaces/IERC1967Upgradeable.sol";
import { AbstractProxiedPayableBridge } from "./base/AbstractProxiedPayableBridge.sol";

/**
 * System contract for the 2.0 version of the reactive network.
 */
contract SystemContract is ISystemContract, AbstractProxiedPayableBridge {
    /// @notice Address used for network initialization.
    address public constant INIT_ADDR = 0x038E06667e42782E571EaB20432b9237F9bD6B82;

    /// @notice Privileged network administrator address.
    address public constant OWNER_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;

    /// @notice Fixed address for node-injected transactions.
    address public constant INJ_ADDR = 0x038E06667e42782E571EaB20432b9237F9bD6B82;

    /// @notice Default gas limit for reactive transaction payments.
    uint256 public constant DEFAULT_MAX_CHARGE_GAS = 50000;

    /// @notice Default extra gas to be paid for when executing reactive transaction.
    uint256 public constant DEFAULT_EXTRA_GAS = 100000;

    /// @notice Default gas price coefficient (in promille) when executing reactive transactions.
    uint256 public constant DEFAULT_GAS_PRICE_COEFF_PER_1000 = 1000;
    
    /// @notice Indicates that this is an initial implementation that cannot be upgraded to.
    error InitialImplementation();

    /// @notice Indicates that the contract has already been initialized.
    error AlreadyInitialized();

    /// @notice Indicates that the method may only be called through node-injected transactions.
    error OnlyInjected();

    /// @notice Indicates that the supplied callback configuration version is not supported.
    /// @param version_ Callback configuration version provided.
    error InvalidCallbackVersion(CallbackVersion version_);

    /// @notice An event requesting a new subscription from the network.
    event Subscribe (
        address indexed subscriber,
        uint256 indexed chain_id,
        address indexed _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    );

    /// @notice An event requesting the removal of an existing subscription.
    event Unsubscribe (
        address indexed subscriber,
        uint256 indexed chain_id,
        address indexed _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    );

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

    /// @notice On-chain storage for callbacks successfully posted to destination chains.
    mapping(uint256 => CallbackStore[]) public _callbacks;

    /// @inheritdoc IERC1967Upgradeable
    function upgradeImpl(address newImpl_, bytes calldata data_) public virtual override onlyProxied onlyOwner {
        _upgradeImpl(newImpl_, data_);
    }

    /// @inheritdoc IERC1967Upgradeable
    function onImplUpgrade(bytes calldata /* data_ */) public virtual override onlyProxied returns (bool /* success_ */) {
        revert InitialImplementation();
    }

    /// @notice Adds a list of addresses provided to the validator set.
    /// @param validators_ List of new validator addresses.
    function initialize(address[] memory validators_) external onlyProxied onlyInitializer {
        _init(validators_);
    }

    /// @notice Adds a list of addresses provided to the validator set.
    /// @param validators_ List of new validator addresses.
    function addValidators(address[] calldata validators_) public virtual onlyProxied onlyOwner {
        _updateOperators(validators_, true);
    }

    /// @notice Removes a list of addresses provided from the validator set.
    /// @param validators_ List of validators to be evicted.
    function removeValidators(address[] calldata validators_) public virtual onlyProxied onlyOwner {
        _updateOperators(validators_, false);
    }

    /// @notice Subscribes the calling contract to receive events matching the criteria specified.
    /// @param chain_id EIP155 source chain ID for the event (as a `uint256`), or `0` for all chains.
    /// @param _contract Contract address to monitor, or `0` for all contracts.
    /// @param topic_0 Topic 0 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic_1 Topic 1 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic_2 Topic 2 to monitor, or `REACTIVE_IGNORE` for all topics.
    /// @param topic_3 Topic 3 to monitor, or `REACTIVE_IGNORE` for all topics.
    function subscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) public virtual override onlyProxied {
        emit Subscribe(msg.sender, chain_id, _contract, topic_0, topic_1, topic_2, topic_3);
    }

    /// @notice Removes active subscription of the calling contract, matching the criteria specified, if one exists.
    /// @param chain_id Chain ID criterion of the original subscription.
    /// @param _contract Contract address criterion of the original subscription.
    /// @param topic_0 Topic 0 criterion of the original subscription.
    /// @param topic_1 Topic 0 criterion of the original subscription.
    /// @param topic_2 Topic 0 criterion of the original subscription.
    /// @param topic_3 Topic 0 criterion of the original subscription.
    function unsubscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) public virtual override onlyProxied {
        emit Unsubscribe(msg.sender, chain_id, _contract, topic_0, topic_1, topic_2, topic_3);
    }

    /// @notice Stores the provided callback data on-chain.
    /// @param callbacks_ List of callbacks to be stored.
    function storeCallbacks(CallbackInfo[] calldata callbacks_) public virtual onlyProxied onlyOperators {
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
    function getCallbacks(uint256 rvmTxHash_) public virtual view onlyProxied returns (CallbackStore[] memory callbacks_) {
        return _callbacks[rvmTxHash_];
    }

    /// @notice Requests the posting of a callback to some destination network.
    /// @param version_ Version of the callback configuration used.
    /// @param config_  ABI-encoded callback configration in a format corresponding to the version specified.
    function requestCallback(CallbackVersion version_, bytes memory config_) public virtual onlyProxied {
        _requestCallback(version_, config_);
    }

    /// @notice Requests the posting of a legacy style callback to some destination network.
    /// @param config_  Callback configration in V_1_0 format.
    function requestCallbackV_1_0(CallbackConfiguration_V_1_0 memory config_) public virtual onlyProxied {
        _requestCallback(CallbackVersion.V_1_0, abi.encode(config_));
    }

    /// @notice Proxy method for calling `react()` methods on reactive contracts.
    /// @param contract_ Generated address for a legacy reactive contracted imported from a 1.0 RVM.
    /// @param log_ Log record to pass to the reactive contract.
    function trigger(IReactive contract_, IReactive.LogRecord calldata log_) public virtual onlyProxied onlyInjected {
        if (_debts[address(contract_)] > 0) {
            revert InDebt(address(contract_), _debts[address(contract_)]);
        }

        uint256 gasInit = gasleft();

        contract_.react(log_);

        uint256 price = tx.gasprice > block.basefee ? tx.gasprice : block.basefee;
        uint256 adjustedGasPrice = (_extraGas + gasInit - gasleft()) * ((price * _gasPriceCoeffPer1000) / 1000);

        __whitelisted = true;
        _charge(address(contract_), adjustedGasPrice);
        __whitelisted = false;
        
        uint256 kickback = adjustedGasPrice;

        bool result = true;

        if (kickback > 0 && kickback <= address(this).balance) {
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

    /// @notice Implementation for the `onlyInitializer` modifier.
    function _onlyInitializer() internal view {
        require(msg.sender == INIT_ADDR);
    }

    /// @inheritdoc AbstractProxiedPayableBridge
    function _onlyOwner() internal virtual override view {
        if (msg.sender != OWNER_ADDR) {
            revert NotAuthorized();
        }
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

    /// @notice Adds a list of addresses provided to the validator set.
    /// @param validators_ List of new validator addresses.
    function _init(address[] memory validators_) internal {
        if (_initialized) {
            revert AlreadyInitialized();
        }

        _initialized = true;

        _maxChargeGas = DEFAULT_MAX_CHARGE_GAS;
        _extraGas = DEFAULT_EXTRA_GAS;
        _gasPriceCoeffPer1000 = DEFAULT_GAS_PRICE_COEFF_PER_1000;

        address[] memory owner = new address[](1);
        owner[0] = OWNER_ADDR;

        _updateOperators(owner, true);
        _updateOperators(validators_, true);
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
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '../lib/reactive-lib/src/interfaces/IReactive.sol';
import '../lib/reactive-lib/src/interfaces/ISystemContract.sol';
import './AbstractSubscriptionService.sol';
import './CallbackProxy.sol';

contract SystemContract is AbstractSubscriptionService, CallbackProxy, ISystemContract {
    struct Check {
        address _contract;
        uint256 amount;
    }

    event Cron1(uint256 indexed number);
    event Cron10(uint256 indexed number);
    event Cron100(uint256 indexed number);
    event Cron1000(uint256 indexed number);
    event Cron10000(uint256 indexed number);

    address public constant SYSTEM_CONTRACT_ADDR = 0x0000000000000000000000000000000000fffFfF;
    address public constant OWNER_ADDR = 0x10be5Db673D1FEEA5d0D4C6d57A1098CDC007c89;
    address public constant VALIDATOR_ROOT_ADDR_1 = 0xAa24633108FD1D87371c55ee5d7FAfA4D6cdeb26;
    address public constant VALIDATOR_ROOT_ADDR_2 = 0x777f67156e2bb3ee9CEA6866C2656b099b67D132;
    address public constant VALIDATOR_ROOT_ADDR_3 = 0x15AD6093CB58540ec143267B5c71E974643e1041;

    uint256 private constant GAS_PRICE_COEFFICIENT_PROMILLE = 1050;
    uint256 private constant KICKBACK_COEFFICIENT_PROMILLE = 1000;
    uint256 private constant EXTRA_GAS_FEE = 150000;
    uint256 private constant INIT_BONUS = 0 ether;
    uint256 private constant MAX_CHARGE_GAS = 50000;

    bool private initialized;

    struct CallbackInfo {
        uint256 block_number;
        address rvm_id;
        uint256 rvm_txhash;
        uint256 callback_ix;
        uint256 dest_chain_id;
        uint256 dest_txhash;
        bytes err;
    }

    struct CallbackStore {
        uint256 block_number;
        address rvm_id;
        uint256 callback_ix;
        uint256 dest_chain_id;
        uint256 dest_txhash;
        bytes err;
    }

    event CallbackPosted(
        uint256 indexed block_number,
        address indexed rvm_id,
        uint256 indexed rvm_txhash,
        uint256 callback_ix,
        uint256 dest_chain_id,
        uint256 dest_txhash,
        bytes err
    );

    mapping(uint256 => CallbackStore[]) public callbacks;

    constructor() CallbackProxy(
        GAS_PRICE_COEFFICIENT_PROMILLE,
        KICKBACK_COEFFICIENT_PROMILLE,
        EXTRA_GAS_FEE,
        INIT_BONUS,
        MAX_CHARGE_GAS,
        new address[](0)
    ) {
    }

    modifier networkAdminOnly() {
        require(msg.sender == OWNER_ADDR);
        _;
    }

    modifier conditionalInit() {
        if (!initialized) {
            _init();
        }
        _;
    }

    function init() external {
        _init();
    }

    // @notice To be called by reactive node only to charge the reactive contracts for services.
    // @param _contract Reactive contract to be charged.
    // @param amount Total amount to be paid.
    function requestPayment(
        address _contract,
        uint256 amount
    ) external callbackOnly {
        _charge(_contract, amount);
    }

    function requestPayments(Check[] calldata list) external callbackOnly {
        for (uint256 ix = 0; ix != list.length; ++ix) {
            _charge(list[ix]._contract, list[ix].amount);
        }
    }

    function storeCallbacks(CallbackInfo[] calldata _callbacks) external callbackOnly {
        for (uint256 ix = 0; ix != _callbacks.length; ++ix) {
            emit CallbackPosted(
                _callbacks[ix].block_number,
                _callbacks[ix].rvm_id,
                _callbacks[ix].rvm_txhash,
                _callbacks[ix].callback_ix,
                _callbacks[ix].dest_chain_id,
                _callbacks[ix].dest_txhash,
                _callbacks[ix].err
            );
            callbacks[_callbacks[ix].rvm_txhash].push(CallbackStore(
                _callbacks[ix].block_number,
                _callbacks[ix].rvm_id,
                _callbacks[ix].callback_ix,
                _callbacks[ix].dest_chain_id,
                _callbacks[ix].dest_txhash,
                _callbacks[ix].err
            ));
        }
    }

    function getCallbacks(uint256 rvm_txhash) external view returns (CallbackStore[] memory) {
        return callbacks[rvm_txhash];
    }

    function blacklist(
        address reactive
    ) external networkAdminOnly {
        _blacklist(reactive);
    }

    function whitelist(
        address reactive
    ) external networkAdminOnly {
        _whitelist(reactive);
    }

    function cron() external conditionalInit callbackOnly {
        _cron(block.number);
    }

    function cron(uint256 number) external conditionalInit callbackOnly {
        _cron(number);
    }

    function _init() internal {
        require(!initialized, 'Already initialized');
        initialized = true;
        gas_price_coefficient_promille = GAS_PRICE_COEFFICIENT_PROMILLE;
        kickback_coefficient_promille = KICKBACK_COEFFICIENT_PROMILLE;
        extra_gas_fee = EXTRA_GAS_FEE;
        init_bonus = INIT_BONUS;
        max_charge_gas = MAX_CHARGE_GAS;
        owner = payable(OWNER_ADDR);
        callback_senders[OWNER_ADDR] = true;
        callback_senders[VALIDATOR_ROOT_ADDR_1] = true;
        callback_senders[VALIDATOR_ROOT_ADDR_2] = true;
        callback_senders[VALIDATOR_ROOT_ADDR_3] = true;
    }

    function _cron(uint256 number) internal {
        emit Cron1(number);
        if (number % 10 == 0) {
            emit Cron10(number);
            if (number % 100 == 0) {
                emit Cron100(number);
                if (number % 1000 == 0) {
                    emit Cron1000(number);
                    if (number % 10000 == 0) {
                        emit Cron10000(number);
                    }
                }
            }
        }
    }
}

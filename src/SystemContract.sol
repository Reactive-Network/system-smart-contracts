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
    address public constant TESTNET_ADMIN_ADDR = 0xFe5A45dB052489cbc16d882404bcFa4f6223A55E;
    address public constant VALIDATOR_ROOT_ADDR_1 = 0x97CeD11ff024e3BC4F31222D447860d1e3EcEC52;
    address public constant VALIDATOR_ROOT_ADDR_2 = 0xb493c1e73B878541cf2E130c4ce5300ce78fC847;
    address public constant VALIDATOR_ROOT_ADDR_3 = 0xa73659c1594923249622a17C3E3900DdFd99bbB1;


    uint256 private constant GAS_PRICE_COEFFICIENT_PROMILLE = 1250;
    uint256 private constant KICKBACK_COEFFICIENT_PROMILLE = 900;
    uint256 private constant EXTRA_GAS_FEE = 100000;
    uint256 private constant INIT_BONUS = 0 ether;
    uint256 private constant MAX_CHARGE_GAS = 100000;

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

    modifier testnetAdminOnly() {
        require(msg.sender == TESTNET_ADMIN_ADDR);
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
    ) external testnetAdminOnly {
        _blacklist(reactive);
    }

    function whitelist(
        address reactive
    ) external testnetAdminOnly {
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
        owner = payable(TESTNET_ADMIN_ADDR);
        callback_senders[TESTNET_ADMIN_ADDR] = true;
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

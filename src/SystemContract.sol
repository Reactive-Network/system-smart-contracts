// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import './IReactive.sol';
import './ISystemContract.sol';
import './AbstractSubscriptionService.sol';
import './CallbackProxy.sol';

contract SystemContract is AbstractSubscriptionService, CallbackProxy, ISystemContract {
    struct Check {
        address _contract;
        uint256 amount;
    }

    address public constant SYSTEM_CONTRACT_ADDR = 0x0000000000000000000000000000000000fffFfF;
    address public constant TESTNET_ADMIN_ADDR = 0xFe5A45dB052489cbc16d882404bcFa4f6223A55E;

    uint256 private constant GAS_PRICE_COEFFICIENT = 2;
    uint256 private constant EXTRA_GAS_FEE = 100000;
    uint256 private constant INIT_BONUS = 0 ether;
    uint256 private constant MAX_CHARGE_GAS = 100000;

    bool private initialized;

    constructor() CallbackProxy(GAS_PRICE_COEFFICIENT, EXTRA_GAS_FEE, INIT_BONUS, MAX_CHARGE_GAS, new address[](0)) {
    }

    modifier testnetAdminOnly() {
        require(msg.sender == TESTNET_ADMIN_ADDR);
        _;
    }

    function init() external {
        require(!initialized, 'Already initialized');
        initialized = true;
        gas_price_coefficient = GAS_PRICE_COEFFICIENT;
        extra_gas_fee = EXTRA_GAS_FEE;
        init_bonus = INIT_BONUS;
        max_charge_gas = MAX_CHARGE_GAS;
        owner = payable(TESTNET_ADMIN_ADDR);
        callback_senders[TESTNET_ADMIN_ADDR] = true;
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
}

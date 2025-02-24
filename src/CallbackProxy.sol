// SPDX-License-Identifier: UNLICENSED

pragma solidity >=0.8.0;

import '../lib/reactive-lib/src/interfaces/IPayable.sol';
import '../lib/reactive-lib/src/interfaces/IPayer.sol';

contract CallbackProxy is IPayable {
    event BlacklistContract (
        address indexed reactive
    );

    event WhitelistContract (
        address indexed reactive
    );

    event CallbackFailure(address indexed target, bytes payload);

    event Unkickbackable();

    event PaymentFailure(address indexed _contract, uint256 indexed amount);

    address payable internal owner;

    mapping(address => bool) internal callback_senders;
    mapping(address => bool) private seen;
    mapping(address => uint256) public reserves;
    mapping(address => uint256) public debts;

    uint256 gas_price_coefficient_promille;
    uint256 kickback_coefficient_promille;
    uint256 extra_gas_fee;
    uint256 init_bonus;
    uint256 max_charge_gas;

    constructor(
        uint256 _gas_price_coefficient_promille, // Suggested: 1050
        uint256 _kickback_coefficient_promille, // Suggested: 1000
        uint256 _extra_gas_fee, // Suggested: 150000
        uint256 _init_bonus, // Suggested: 0
        uint256 _max_charge_gas, // Suggested: 50000
        address[] memory _callback_senders
    ) {
        owner = payable(msg.sender);
        callback_senders[owner] = true;
        for (uint256 ix = 0; ix != _callback_senders.length; ++ix) {
            callback_senders[_callback_senders[ix]] = true;
        }
        gas_price_coefficient_promille = _gas_price_coefficient_promille;
        kickback_coefficient_promille = _kickback_coefficient_promille;
        extra_gas_fee = _extra_gas_fee;
        init_bonus = _init_bonus;
        max_charge_gas = _max_charge_gas;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, 'Not authorized');
        _;
    }

    modifier callbackOnly() {
        require(callback_senders[msg.sender], 'Callback only');
        _;
    }

    function withdraw() external onlyOwner {
        owner.transfer(address(this).balance);
    }

    function addCallbackSenders(address[] calldata _callback_senders) external callbackOnly {
        for (uint256 ix = 0; ix != _callback_senders.length; ++ix) {
            callback_senders[_callback_senders[ix]] = true;
        }
    }

    function removeCallbackSenders(address[] calldata _callback_senders) external callbackOnly() {
        for (uint256 ix = 0; ix != _callback_senders.length; ++ix) {
            callback_senders[_callback_senders[ix]] = false;
        }
    }

    function callback(address _contract, bytes calldata payload) external callbackOnly {
        _callback(_contract, payload);
    }

    function callbackRnk(uint64 /* block_number */, address _contract, bytes calldata payload) external callbackOnly {
        _callback(_contract, payload);
    }

    receive() external payable {
        _deposit(msg.sender, msg.value);
    }

    function depositTo(address _contract) external payable {
        _deposit(_contract, msg.value);
    }

    function debt(address _contract) external view returns (uint256) {
        return debts[_contract];
    }

    function _init(address _contract) internal {
        if (!seen[_contract]) {
            seen[_contract] = true;
            reserves[_contract] = init_bonus;
        }
    }

    function _callback(address _contract, bytes calldata payload) internal {
        require(debts[_contract] == 0, 'Callback target currently in debt');
        uint256 gas_init = gasleft();
        (bool result,) = _contract.call{ gas: gasleft() - extra_gas_fee - max_charge_gas }(payload);
        if (!result) {
            emit CallbackFailure(_contract, payload);
        }
        uint256 price = tx.gasprice > block.basefee ? tx.gasprice : block.basefee;
        uint256 adjusted_gas_price = ((price * gas_price_coefficient_promille) / 1000) * (extra_gas_fee + gas_init - gasleft());
        _charge(_contract, adjusted_gas_price);
        uint256 kickback = (adjusted_gas_price * kickback_coefficient_promille) / 1000;
        result = false;
        if (kickback <= address(this).balance) {
            (result,) = tx.origin.call{ value: kickback }(new bytes(0));
        }
        if (!result) {
            emit Unkickbackable();
        }
    }

    function _deposit(address _contract, uint256 amount) internal {
        _init(_contract);
        if (amount > 0) {
            if (debts[_contract] > 0) {
                if (amount < debts[_contract]) {
                    debts[_contract] -= amount;
                } else {
                    uint256 remainder = amount - debts[_contract];
                    debts[_contract] = 0;
                    _whitelist(_contract);
                    _deposit(_contract, remainder);
                }
            } else {
                reserves[_contract] += amount;
            }
        }
    }

    function _charge(address _contract, uint256 amount) internal {
        _init(_contract);
        if (amount > 0) {
            if (reserves[_contract] > 0) {
                if (amount <= reserves[_contract]) {
                    reserves[_contract] -= amount;
                } else {
                    uint256 remainder = amount - reserves[_contract];
                    reserves[_contract] = 0;
                    _charge(_contract, remainder);
                }
            } else {
                debts[_contract] = amount;
                bytes memory payload = abi.encodeWithSignature("pay(uint256)", debts[_contract]);
                (bool success,) = _contract.call{ gas: max_charge_gas }(payload);
                if (!success) {
                    emit PaymentFailure(_contract, debts[_contract]);
                }
                if (debts[_contract] > 0) {
                    _blacklist(_contract);
                }
            }
        }
    }

    function _blacklist(
        address reactive
    ) internal {
        emit BlacklistContract(reactive);
    }

    function _whitelist(
        address reactive
    ) internal {
        emit WhitelistContract(reactive);
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.29;

import { IPayable } from "@reactive/src/interfaces/IPayable.sol";
import { AbstractERC1967Upgradeable } from "./AbstractERC1967Upgradeable.sol";

/**
 * @title Abstract base contract for `SystemContract` and `CallbackProxy`.
 */
abstract contract AbstractProxiedPayableBridge is IPayable, AbstractERC1967Upgradeable {
    /// @notice Indicates that the message sender is not authorized to perform the operation.
    error NotAuthorized();

    /// @notice Requests a given contract to be blacklisted.
    /// @param callback_ Contract's address.
    event BlacklistContract(address indexed callback_);

    /// @notice Requests a given contract to be removed from the blacklist.
    /// @param callback_ Contract's address.
    event WhitelistContract(address indexed callback_);

    /// @notice Indicates that the contract is currently in debt.
    /// @param contract_ Contract's address.
    /// @param debt_ Current debt.
    error InDebt(address contract_, uint256 debt_);

    /// @notice Indicates the payment failure on the part of the contract.
    /// @param contract_ Address of the contract in question.
    /// @param amount_ Requested payment amount.
    event PaymentFailure(address indexed contract_, uint256 indexed amount_);

    /// @notice Indicates that the operator EOA or contract has failed to accept transaction kickback.
    event Unkickbackable();

    /// @notice Mapping listing authorized bridge operators.
    mapping(address => bool) public _operators;

    /// @notice Contracts' pre-paid reserves for covering transaction costs.
    mapping(address => uint256) public _reserves;

    /// @notice Outstanding debts of target contracts.
    mapping(address => uint256) public _debts;

    /// @notice Default gas limit for transaction payments.
    uint256 public _maxChargeGas;

    /// @notice Extra gas to be paid for when executing a transaction.
    uint256 public _extraGas;

    /// @notice Gas price coefficient (in promille) when executing a transactions.
    uint256 public _gasPriceCoeffPer1000;

    /// @notice Transient variable to prevent emission of unnecessary `WhitelistContract()` events.
    bool transient __whitelisted;

    /// @notice Method for covering callback fee debts.
    receive() external virtual payable onlyProxied {
        _deposit(msg.sender, msg.value);
    }

    /// @notice Method for covering callback fee debts.
    /// @param contract_ Address of the callback contract the balance of which should be updated.
    function depositTo(address contract_) public virtual payable onlyProxied {
        _deposit(contract_, msg.value);
    }

    /// @notice Returns the contract's current reserves.
    /// @param contract_ Address of the contract.
    /// @param reserves_ Current reserves.
    function reserves(address contract_) public virtual view onlyProxied returns (uint256 reserves_) {
        return _reserves[contract_];
    }

    /// @notice Returns the given contract's outstanding debt.
    /// @param contract_ Address of the contract.
    /// @param debt_ Outstanding debt.
    function debt(address contract_) public virtual view onlyProxied returns (uint256 debt_) {
        return _debts[contract_];
    }

    /// @notice Returns the given contract's outstanding debt.
    /// @param contract_ Address of the contract.
    /// @param debt_ Outstanding debt.
    function debts(address contract_) public virtual view onlyProxied returns (uint256 debt_) {
        return _debts[contract_];
    }

    /// @notice Requests blacklisting of a given contract.
    /// @param contract_ Contract's address.
    function blacklist(address contract_) public virtual onlyProxied onlyOwner {
        _blacklist(contract_);
    }

    /// @notice Requests whitelisting of a given contract.
    /// @param contract_ Contract's address.
    function whitelist(address contract_) public virtual onlyProxied onlyOwner {
        _whitelist(contract_);
    }

    /// @notice Modifier for guarding the methods that may only be called by the trusted operator EOA or contracts.
    modifier onlyOperators() {
        _onlyOperators();
        _;
    }

    /// @notice Implementation for the `onlyCallbackSenders` modifier.
    function _onlyOperators() internal view {
        if (!_operators[msg.sender]) {
            revert NotAuthorized();
        }
    }

    /// @notice Modifier for guarding the methods that may only be called by the contract owner.
    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    /// @notice Implementation for the `onlyOwner` modifier.
    function _onlyOwner() internal virtual;

    /// @notice Adds or removed a list of addresses provided to or from the authorized operators list.
    /// @param operators_ List of new callback senders.
    /// @param authorize_ Indicates that the access should be granted.
    function _updateOperators(address[] memory operators_, bool authorize_) internal virtual {
        for (uint256 ix = 0; ix != operators_.length; ++ix) {
            _operators[operators_[ix]] = authorize_;
        }
    }

    /// @notice Deposits the specified amount to a given contract's balance.
    /// @param contract_ Contract's address.
    /// @param amount_ Amount to be added to the balance.
    function _deposit(address contract_, uint256 amount_) internal {
        if (amount_ > 0) {
            if (_debts[contract_] > 0) {
                if (amount_ < _debts[contract_]) {
                    _debts[contract_] -= amount_;
                } else {
                    uint256 remainder = amount_ - _debts[contract_];
                    _debts[contract_] = 0;
                    if (!__whitelisted) {
                        _whitelist(contract_);
                    }
                    _deposit(contract_, remainder);
                }
            } else {
                _reserves[contract_] += amount_;
            }
        }
    }

    /// @notice Attempt to charge the given contract for the amount specified.
    /// @param contract_ Contract's address.
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
                (bool success,) = contract_.call{ gas: _maxChargeGas }(payload);
                if (!success) {
                    emit PaymentFailure(contract_, _debts[contract_]);
                }
                if (currentDebt == 0 && _debts[contract_] > 0) {
                    _blacklist(contract_);
                }
            }
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

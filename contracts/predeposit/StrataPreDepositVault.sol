// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

contract StrataPreDepositVault is ERC4626, Ownable {
    bool public depositsEnabled;
    bool public withdrawalsEnabled;

    error DepositsDisabled();
    error WithdrawalsDisabled();

    event DepositsEnabled(bool enabled);
    event WithdrawalsEnabled(bool enabled);

    constructor(address initialOwner_, IERC20 asset_, string memory name_, string memory symbol_)
        ERC4626(asset_)
        ERC20(name_, symbol_)
        Ownable(initialOwner_)
    {}

    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {
        if (!depositsEnabled) {
            revert DepositsDisabled();
        }

        super._deposit(caller, receiver, assets, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares)
        internal
        override
    {
        if (!withdrawalsEnabled) {
            revert WithdrawalsDisabled();
        }

        super._withdraw(caller, receiver, owner, assets, shares);
    }

    function setDepositsEnabled(bool depositsEnabled_) external onlyOwner {
        depositsEnabled = depositsEnabled_;
        emit DepositsEnabled(depositsEnabled_);
    }

    function setWithdrawalsEnabled(bool withdrawalsEnabled_) external onlyOwner {
        withdrawalsEnabled = withdrawalsEnabled_;
        emit WithdrawalsEnabled(withdrawalsEnabled_);
    }
}

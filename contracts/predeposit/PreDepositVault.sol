// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC4626Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC4626Upgradeable.sol";

import {PreDepositPhase} from "../interfaces/IPhase.sol";
import {PreDepositPhaser} from "./PreDepositPhaser.sol";

abstract contract PreDepositVault is ERC4626Upgradeable, OwnableUpgradeable, PreDepositPhaser {

    /// @notice Minimum non-zero shares amount to prevent donation attack
    uint256 private constant MIN_SHARES = 0.1 ether;

    bool public depositsEnabled;
    bool public withdrawalsEnabled;

    IERC20 public USDe;
    IERC4626 public sUSDe;

    /**
     * @dev See https://docs.openzeppelin.com/upgrades-plugins/writing-upgradeable#storage-gaps
     */
    uint256[48] private __gap;

    error DepositsDisabled();
    error WithdrawalsDisabled();
    /// @notice Error emitted when a small non-zero share amount remains, which risks donations attack
    error MinSharesViolation();


    event DepositsStateChanged(bool enabled);
    event WithdrawalsStateChanged(bool enabled);


    function initialize(
        address owner_
        , string memory name
        , string memory symbol
        , IERC20 USDe_
        , IERC4626 sUSDe_
        , IERC20 stakedAsset
    ) public virtual initializer {
        __ERC20_init(name, symbol);
        __ERC4626_init(stakedAsset);
        __Ownable_init(owner_);

        USDe = USDe_;
        sUSDe = sUSDe_;
    }

    /** @dev Extends {IERC4626-maxDeposit} to handle the paused state */
    function maxDeposit(address owner) public view override returns (uint256) {
        if (depositsEnabled == false) {
            return 0;
        }
        return super.maxDeposit(owner);
    }
    /** @dev Extends {IERC4626-maxMint} to handle the paused state */
    function maxMint(address owner) public view override returns (uint256) {
        if (depositsEnabled == false) {
            return 0;
        }
        return super.maxMint(owner);
    }
    /** @dev Extends {IERC4626-maxWithdraw} to handle the paused state */
    function maxWithdraw(address owner) public view override returns (uint256) {
        if (withdrawalsEnabled == false) {
            return 0;
        }
        return super.maxWithdraw(owner);
    }
    /** @dev Extends {IERC4626-maxRedeem} to handle the paused state */
    function maxRedeem(address owner) public view override returns (uint256) {
        if (withdrawalsEnabled == false) {
            return 0;
        }
        return super.maxRedeem(owner);
    }

    function setDepositsEnabled(bool depositsEnabled_) external onlyOwner {
        depositsEnabled = depositsEnabled_;
        emit DepositsStateChanged(depositsEnabled_);
    }

    function setWithdrawalsEnabled(bool withdrawalsEnabled_) external onlyOwner {
        withdrawalsEnabled = withdrawalsEnabled_;
        emit WithdrawalsStateChanged(withdrawalsEnabled_);
    }

    function onAfterDepositChecks () internal view {
        if (!depositsEnabled) {
            revert DepositsDisabled();
        }
    }
    function onAfterWithdrawalChecks () internal view {
        if (!withdrawalsEnabled) {
            revert WithdrawalsDisabled();
        }
        if (totalSupply() < MIN_SHARES) {
            revert MinSharesViolation();
        }
    }
}

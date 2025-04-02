// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "hardhat/console.sol";

contract StrataPreDepositVault is ERC4626, Ownable {
    bool public depositsEnabled;
    bool public withdrawalsEnabled;
    IERC20 public sourceAsset;
    IERC4626 public stakedAsset;

    error DepositsDisabled();
    error WithdrawalsDisabled();

    event DepositsEnabled(bool enabled);
    event WithdrawalsEnabled(bool enabled);

    constructor(address initialOwner_, IERC20 sourceAsset_, IERC4626 stakedAsset_, string memory name_, string memory symbol_)
        ERC4626(stakedAsset_)
        ERC20(name_, symbol_)
        Ownable(initialOwner_)
    {
        sourceAsset = sourceAsset_;
        stakedAsset = stakedAsset_;
    }

    /** @dev See {IERC4626-deposit}. */
    function deposit(uint256 assets, address receiver) public override returns (uint256) {
        if (!depositsEnabled) {
            revert DepositsDisabled();
        }
        uint256 maxAssets = maxDeposit(receiver);
        if (assets > maxAssets) {
            revert ERC4626ExceededMaxDeposit(receiver, assets, maxAssets);
        }

        address sender = _msgSender();
        uint256 assetsStakedPreview = stakedAsset.previewDeposit(assets);
        uint256 shares = previewDeposit(assetsStakedPreview);

        uint256 assetsStaked = _stakeDeposited(sender, assets);
        require(assetsStaked == assetsStakedPreview, "Stake: assetsStaked");

        _mint(sender, shares);
        emit Deposit(sender, receiver, assets, shares);
        return shares;
    }

    function _stakeDeposited (address caller, uint256 sourceAssets) internal returns (uint256 assetsStaked){
        uint beforeAmount = stakedAsset.balanceOf(address(this));
        SafeERC20.safeTransferFrom(sourceAsset, caller, address(this), sourceAssets);

        sourceAsset.approve(address(stakedAsset), sourceAssets);
        stakedAsset.deposit(sourceAssets, address(this));

        uint afterAmount = stakedAsset.balanceOf(address(this));
        assetsStaked = afterAmount - beforeAmount;
        require(assetsStaked > 0, "Deposit underflow");
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

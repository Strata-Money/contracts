// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PreDepositVault} from "./PreDepositVault.sol";

import {IERC4626YieldVault} from "../interfaces/IERC4626Yield.sol";

contract yUSDeVault is PreDepositVault {
    using Math for uint256;

    IERC4626YieldVault public pUSDeVault;

    function initialize(
        address owner_
        , IERC20 USDe_
        , IERC4626 sUSDe_
        , IERC4626YieldVault pUSDeVault_
    ) external virtual initializer {
        super.initialize(
            owner_,
            "PreDeposit Strata Yield USDe",
            "yUSDe",
            USDe_,
            sUSDe_,
            pUSDeVault_
        );

        pUSDeVault = pUSDeVault_;
    }

    /**
     * @dev All share calculations for minting, depositing, redeeming, and withdrawing are based on the staked USDe amount + yield.
     * This allows us to retain the extra yield received from increasing sUSDe underlying holdings.
     */
    function totalAssets() public view override returns (uint256) {
        uint pUSDeAssets = super.totalAssets();
        uint USDeAssets = _convertAssetsToUSDe(pUSDeAssets);
        return USDeAssets;
    }

    function _convertAssetsToUSDe (uint pUSDeAssets) internal view returns (uint256) {
        uint sUSDeAssets = pUSDeVault.previewRedeem(address(this), pUSDeAssets);
        uint USDeAssets = sUSDe.previewRedeem(sUSDeAssets);
        return USDeAssets;
    }

    // returns shares based on USDeAssets
    function _convertToShares(uint256 pUSDeAssets, Math.Rounding rounding) internal view override returns (uint256) {
        uint USDeAssets = _convertAssetsToUSDe(pUSDeAssets);
        uint yUSDeShares = USDeAssets.mulDiv(totalSupply() + 10 ** _decimalsOffset(), totalAssets() + 1, rounding);
        return yUSDeShares;
    }

    // returns pUSDeAssets based on shares and USDe amount
    function _convertToAssets(uint256 yUSDeShares, Math.Rounding rounding) internal view override returns (uint256) {
        uint USDeAssets = yUSDeShares.mulDiv(totalAssets() + 1, totalSupply() + 10 ** _decimalsOffset(), rounding);
        uint pUSDeAssets = pUSDeVault.previewWithdraw(USDeAssets);
        return pUSDeAssets;
    }

    function _deposit(address caller, address receiver, uint256 pUSDeAssets, uint256 shares) internal override {
        if (!depositsEnabled) {
            revert DepositsDisabled();
        }
        return super._deposit(caller, receiver, pUSDeAssets, shares);
    }

    function _withdraw(address caller, address receiver, address owner, uint256 pUSDeAssets, uint256 shares)
        internal
        override
    {
        if (!withdrawalsEnabled) {
            revert WithdrawalsDisabled();
        }

        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        pUSDeVault.redeem(pUSDeAssets, receiver, address(this));
        emit Withdraw(caller, receiver, owner, pUSDeAssets, shares);
    }
}

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
import {PreDepositPhase, IPreDepositPhaser} from "../interfaces/IPhase.sol";

contract yUSDeVault is PreDepositVault {
    using Math for uint256;

    IERC4626YieldVault public pUSDeVault;

    function initialize(
        address owner_
        , IERC20 USDe_
        , IERC4626 sUSDe_
        , IERC4626YieldVault pUSDeVault_
    ) external virtual initializer {
        __init_Vault(
            owner_,
            "PreDeposit Strata Yield USDe",
            "yUSDe",
            USDe_,
            sUSDe_,
            pUSDeVault_
        );

        pUSDeVault = pUSDeVault_;
    }

    function totalAccruedUSDe() public view returns (uint256 USDeAssets) {
        uint256 pUSDeAssets = super.totalAssets();
        USDeAssets = _convertAssetsToUSDe(pUSDeAssets, true);
    }

    function _convertAssetsToUSDe (uint256 pUSDeAssets, bool withYield) internal view returns (uint256) {
        if (pUSDeAssets == 0) {
            return 0;
        }
        uint256 sUSDeAssets = pUSDeVault.previewRedeem(withYield ? address(this) : address(0), pUSDeAssets);
        uint256 USDeAssets = sUSDe.previewRedeem(sUSDeAssets);
        return USDeAssets;
    }

    /**
     * @dev Deposit calculation process:
     * 1. Convert pUSDe to underlying USDe° without yield.
     * 2. Calculate the equivalent amount of yUSDe shares, considering accrued yield.
     *    yUSDeShares = (pUSDeAssets → USDe°) * (∑yUSDe / ∑USDe)
     *
     * @param pUSDeAssets The amount of pUSDe assets to deposit
     * @return yUSDeShares The amount of yUSDe shares to be minted
     */
    function previewDeposit(uint256 pUSDeAssets) public view override returns (uint256 yUSDeShares) {
        uint256 underlyingUSDe = _convertAssetsToUSDe(pUSDeAssets, false);
        yUSDeShares = _valueMulDiv(underlyingUSDe, totalAssets(), totalAccruedUSDe(), Math.Rounding.Floor);
    }

    /**
     * @dev Mint calculation process:
     * 1. Calculate required USDe to mint X yUSDeShares:
     *    USDe = yUSDeShares * (totalAccruedUSDe / totalAssets)
     * 2. Convert USDe to pUSDe
     *
     * @param yUSDeShares The amount of yUSDeShares to mint
     * @return pUSDeAssets The amount of pUSDe assets required to mint the specified yUSDeShares
     */
    function previewMint(uint256 yUSDeShares) public view override returns (uint256 pUSDeAssets) {
        uint256 underlyingUSDe = _valueMulDiv(yUSDeShares, totalAccruedUSDe(), totalAssets(), Math.Rounding.Ceil);
        pUSDeAssets = pUSDeVault.previewDeposit(underlyingUSDe);
    }

    function currentPhase () public override view returns (PreDepositPhase) {
        return IPreDepositPhaser(address(pUSDeVault)).currentPhase();
    }

    function _deposit(address caller, address receiver, uint256 pUSDeAssets, uint256 shares) internal override {
        super._deposit(caller, receiver, pUSDeAssets, shares);
        _onAfterDepositChecks();
    }

    function _withdraw(address caller, address receiver, address owner, uint256 pUSDeAssets, uint256 shares) internal override {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        _burn(owner, shares);
        pUSDeVault.redeem(pUSDeAssets, receiver, address(this));
        emit Withdraw(caller, receiver, owner, pUSDeAssets, shares);
        _onAfterWithdrawalChecks();
    }


    function _valueMulDiv(uint256 value, uint256 mulValue, uint256 divValue, Math.Rounding rounding) internal view virtual returns (uint256) {
        return value.mulDiv(mulValue + 1, divValue + 1, rounding);
    }

}

// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {MetaVault} from "./MetaVault.sol";
import {IERC4626Yield} from "../interfaces/IERC4626Yield.sol";

import {PreDepositPhase} from "../interfaces/IPhase.sol";


/// @title pUSDeVault - A two-phase, multi-asset vault for USDe and sUSDe
/// @notice This contract implements a vault that operates in two phases and can handle multiple assets
/// @dev The vault has two main phases:
///      1. PointsPhase: Accepts and holds USDe and potentially other USDe-based assets (e.g., eUSDe)
///      2. YieldPhase: Accepts and holds sUSDe, while tracking the total deposited USDe for yield calculations
/// @custom:phase-behavior
///      - PointsPhase: Directly accepts and holds USDe and potentially other USDe-based assets
///      - YieldPhase: Accepts sUSDe, tracks deposited USDe, calculates and distributes yield
contract pUSDeVault is IERC4626Yield, MetaVault {

    /// @notice The vault used to receive and distribute sUSDe yield during the YieldPhase
    /// @dev This IERC4626 compliant vault is set by the owner and used only in YieldPhase
    /// @custom:phase YieldPhase
    IERC4626 public yUSDe;

    event YUSDeVaultUpdated(address yUSDeAddress);

    function initialize(
        address owner_
        , IERC20 USDe_
        , IERC4626 sUSDe_
    ) external virtual initializer {
        super.initialize(
            owner_,
            "PreDeposit Strata Points USDe",
            "pUSDe",
            USDe_,
            sUSDe_,
            USDe_
        );
    }


    /// @notice Returns the total assets in the vault, which varies based on the current phase
    /// @dev In PointsPhase, returns the total deposited USDe. In YieldPhase, converts the total deposited USDe to sUSDe.
    /// @return uint256 The total assets in the vault, in USDe for PointsPhase or sUSDe for YieldPhase
    function totalAssets() public view override returns (uint256) {
        if (PreDepositPhase.PointsPhase == currentPhase) {
            return depositedBase;
        }
        return sUSDe.previewWithdraw(depositedBase);
    }




    /// @notice Previews the yield for a given number of shares
    /// @dev Only returns a non-zero value in YieldPhase and if the caller is the yUSDe vault
    /// @param caller The address requesting the yield preview
    /// @param shares The number of shares to calculate yield for
    /// @return uint256 The previewed yield in sUSDe, or 0 if conditions are not met
    /// @custom:phase YieldPhase
    function previewYield(address caller, uint256 shares) public view virtual returns (uint256) {
        if (PreDepositPhase.YieldPhase == currentPhase && caller == address(yUSDe)) {
            uint total_sUSDe = sUSDe.balanceOf(address(this));
            // Math.min: Normally, total_USDe should exceed depositedUSDe due to yield.
            // However, in rare cases (e.g., negative APY), we adjust depositedUSDe to match total_USDe.
            uint total_yield_sUSDe = total_sUSDe - Math.min(total_sUSDe, totalAssets());

            uint y_pUSDeShares = balanceOf(caller);
            uint caller_yield_sUSDe = total_yield_sUSDe * shares / y_pUSDeShares;
            return caller_yield_sUSDe;
        }
        return 0;
    }

    /// @notice Previews the amount of assets that would be redeemed for a given number of shares, including any eligible rewards
    /// @dev Extends the standard {IERC4626-previewRedeem} method by adding potential yield for eligible callers
    /// @param caller The address requesting the redemption preview
    /// @param shares The number of shares to be redeemed
    /// @return uint256 The total amount of assets (including yield) that would be redeemed for the given shares
    /// @custom:phase Applicable in both PointsPhase and YieldPhase, but yield is only added in YieldPhase for eligible callers
    function previewRedeem(address caller, uint256 shares) public view virtual returns (uint256) {
        return previewRedeem(shares) + previewYield(caller, shares);
    }

    /// @notice Handles deposits and tracks the deposited USDe balance
    /// @dev Extends the generic {OpenZeppelin-_deposit} method to account for different base assets in different phases
    /// @param caller Address initiating the deposit
    /// @param receiver Address receiving the minted shares
    /// @param assets Amount of assets being deposited
    /// @param shares Amount of shares to mint
    /// @custom:phase-behavior
    ///     - PointsPhase: Assets are in USDe, directly added to depositedBase
    ///     - YieldPhase: Assets are in sUSDe, converted to USDe before adding to depositedBase
    function _deposit(address caller, address receiver, uint256 assets, uint256 shares) internal override {

        if (PreDepositPhase.YieldPhase == currentPhase) {
            uint amountUSDe = sUSDe.previewRedeem(assets);
            depositedBase += amountUSDe;
        } else {
            depositedBase += assets;
        }
        super._deposit(caller, receiver, assets, shares);
        onAfterDepositChecks();
    }

    /// @notice Handles withdrawals and updates the deposited USDe balance
    /// @dev Extends the {OpenZeppelin-_withdraw} method to handle different base assets in different phases
    /// @param caller Address initiating the withdrawal
    /// @param receiver Address receiving the withdrawn assets
    /// @param owner Address that owns the shares being burned
    /// @param assets Amount of assets to withdraw
    /// @param shares Amount of shares to burn
    /// @custom:phase-behavior
    ///     - PointsPhase: Assets are in USDe
    ///     - YieldPhase: Assets are in sUSDe, converted to USDe for depositedBase tracking
    /// @custom:yield In YieldPhase, includes any accrued yield for eligible callers
    function _withdraw(address caller, address receiver, address owner, uint256 assets, uint256 shares) internal override {

        if (PreDepositPhase.YieldPhase == currentPhase) {
            // sUSDeAssets = sUSDeAssets + user_yield_sUSDe
            assets += previewYield(caller, shares);

            uint256 USDeAssets = sUSDe.previewRedeem(assets);
            require(USDeAssets <= depositedBase, "INSUFFICIENT_ASSETS");
            depositedBase -= USDeAssets;
        } else {
            require(PreDepositPhase.PointsPhase == currentPhase, "INVALID_PHASE");
            require(assets <= depositedBase, "INSUFFICIENT_ASSETS");

            uint USDeBalance = USDe.balanceOf(address(this));
            if (assets > USDeBalance) {
                // Transfer-in from multi-vaults
                redeemRequiredBaseAssets(assets - USDeBalance);
            }
            depositedBase -= assets;
        }

        super._withdraw(caller, receiver, owner, assets, shares);
        onAfterWithdrawalChecks();
    }

    /// @notice Updates the yUSDe vault address for yield redistribution
    /// @dev In YieldPhase, this vault is used to redistribute yield among yUSDe depositors
    /// @param yUSDeAddress The address of the new yUSDe vault
    /// @custom:permissions Only callable by the contract owner
    /// @custom:phase YieldPhase
    function updateYUSDeVault(address yUSDeAddress) external onlyOwner {
        yUSDe = IERC4626(yUSDeAddress);
        emit YUSDeVaultUpdated(yUSDeAddress);
    }

    /// @notice Initiates the Yield Phase of the vault
    /// @dev This function performs the following steps:
    /// 1. Redeems all assets from meta vaults
    /// 2. Deposits all USDe into sUSDe
    /// 3. Keeps the deposited USDe balance unchanged for yield tracking
    /// 4. Sets sUSDe as the new base asset for the vault
    /// @custom:permissions Only callable by the contract owner
    /// @custom:phase-transition Transitions the vault from Points Phase to Yield Phase
    function startYieldPhase () external onlyOwner {

        setYieldPhaseInner();
        redeemMetaVaults();

        uint USDeBalance = USDe.balanceOf(address(this));
        USDe.approve(address(sUSDe), USDeBalance);
        sUSDe.deposit(USDeBalance, address(this));
        updateBaseAssetAddress(address(sUSDe));
    }
}

// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
import {vm} from "@chimera/Hevm.sol";

import {MockERC20} from "@recon/MockERC20.sol";

import {yUSDeVaultHarness} from "../harness/yUSDeVaultHarness.sol";
import {MockERC4626Harness, IERC20} from "../harness/MockERC4626Harness.sol";

// Target functions that are effectively inherited from the Actor and AssetManagers
// Once properly standardized, managers will expose these by default
// Keeping them out makes your project more custom
abstract contract ManagersTargets is BaseTargetFunctions, Properties {
    // == ACTOR HANDLERS == //

    function addActor(address actor) public {
        if (actor != address(0)) {
            _addActor(actor);
        }
    }

    /// @dev Start acting as another actor
    function switchActor(uint256 entropy) public {
        _switchActor(entropy);
    }

    // NOTE: We don't need any assets other than USDe underlying the vaults
    // /// @dev Starts using a new asset
    // function switch_asset(uint256 entropy) public {
    //     _switchAsset(entropy);
    // }

    // /// @dev Deploy a new token and add it to the list of assets, then set it as the current asset
    // function add_new_asset(uint8 decimals) public returns (address) {
    //     address newAsset = _newAsset(decimals);
    //     return newAsset;
    // }

    /// @dev Starts using a new vault
    function switch_vault(uint256 entropy) public {
        _switchVault(entropy);
    }

    /// @dev Deploy a new vault and add it to the list of vaults, then set it as the current vault
    function add_new_vault() public returns (address) {
        address newVault = _newVault(_getAsset());
        return newVault;
    }

    /// @dev Starts using a new yUSDe vault
    function switch_yUSDe_vault(uint256 entropy) public {
        _switchYUSDeVault(entropy);
        yUSDe = yUSDeVaultHarness(_getYUSDeVault());
    }

    /// @dev Deploy a new yUSDe vault and add it to the list of yUSDe vaults, then set it as the current yUSDe vault
    function add_new_yUSDe_vault() public returns (address) {
        address newVault = _newYUSDeVault(address(this), _getAsset(), address(sUSDe), address(pUSDe));
        return newVault;
    }

    /// === GHOST UPDATING HANDLERS ===///
    /// We `updateGhosts` cause you never know (e.g. donations)
    /// If you don't want to track donations, remove the `updateGhosts`

    /// @dev Approve to arbitrary address, uses Actor by default
    /// NOTE: You're almost always better off setting approvals in `Setup`
    function asset_approve(address to, uint128 amt) public updateGhosts asActor {
        MockERC20(_getAsset()).approve(to, amt);
    }

    /// @dev Mint to arbitrary address, uses owner by default, even though MockERC20 doesn't check
    function asset_mint(address to, uint128 amt) public updateGhosts asAdmin {
        MockERC20(_getAsset()).mint(to, amt);
    }

    function vault_approve(address to, uint128 amt) public updateGhosts asActor {
        MockERC4626Harness(_getVault()).approve(to, amt);
    }

    function vault_deposit(uint128 amt) public updateGhosts asActor {
        MockERC4626Harness(_getVault()).deposit(amt, msg.sender);
    }

    function vault_mint(address to, uint128 amt) public updateGhosts asAdmin {
        address vault = _getVault();
        address asset = MockERC4626Harness(vault).asset();

        MockERC20(asset).mint(address(this), amt);
        MockERC20(asset).approve(vault, amt);
        MockERC4626Harness(vault).deposit(amt, to);
    }

    function vault_recognizeProfit(uint128 amt) public updateGhosts asAdmin {
        MockERC4626Harness(_getVault()).recognizeProfit(amt);
    }

    function vault_recognizeLoss(uint128 amt) public updateGhosts asAdmin {
        address vault = _getVault();
        precondition(amt <= IERC20(MockERC4626Harness(vault).asset()).balanceOf(vault));
        MockERC4626Harness(vault).recognizeLoss(amt);
    }
}

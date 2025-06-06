// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

// Targets
// NOTE: Always import and apply them in alphabetical order, so much easier to debug!
import {AdminTargets} from "./targets/AdminTargets.sol";
import {DoomsdayTargets} from "./targets/DoomsdayTargets.sol";
import {ManagersTargets} from "./targets/ManagersTargets.sol";
import {PUSDeVaultTargets} from "./targets/PUSDeVaultTargets.sol";
import {YUSDeVaultTargets} from "./targets/YUSDeVaultTargets.sol";

abstract contract TargetFunctions is
    AdminTargets,
    DoomsdayTargets,
    ManagersTargets,
    PUSDeVaultTargets,
    YUSDeVaultTargets
{
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    function target_mint_USDe_actor(uint128 amount) public {
        asset_mint(_getActor(), amount);
    }

    function target_donate_USDe_pUSDe(uint128 amount) public {
        asset_mint(address(pUSDe), amount);
    }

    function target_donate_USDe_yUSDe(uint128 amount) public {
        asset_mint(address(yUSDe), amount);
    }

    function target_sUSDe_yield(uint128 amount) public {
        // mint USDe directly to the sUSDe contract to simulate yield
        // without having to consider the vesting period
        asset_mint(address(sUSDe), amount);
    }

    function target_donate_sUSDe_pUSDe(uint128 amount) public updateGhosts asAdmin {
        USDe.mint(address(this), amount);
        USDe.approve(address(sUSDe), amount);
        sUSDe.deposit(amount, address(pUSDe));
    }

    function target_donate_sUSDe_yUSDe(uint128 amount) public updateGhosts asAdmin {
        USDe.mint(address(this), amount);
        USDe.approve(address(sUSDe), amount);
        sUSDe.deposit(amount, address(yUSDe));
    }

    function target_approve_USDe_vault(uint128 amount) public {
        asset_approve(_getVault(), amount);
    }

    function target_deposit_USDe_vault(uint128 amount) public {
        vault_deposit(amount);
    }

    function target_mint_vault_actor(uint128 amount) public {
        vault_mint(_getActor(), amount);
    }

    function target_approve_vault_pUSDe(uint128 amount) public {
        vault_approve(address(pUSDe), amount);
    }

    function target_approve_pUSDe_yUSDe(uint128 amount) public updateGhosts asActor {
        pUSDe.approve(address(yUSDe), amount);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///
}

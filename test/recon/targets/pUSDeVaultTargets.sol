// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "contracts/predeposit/pUSDeVault.sol";
import {MockERC4626, IERC20} from "contracts/test/MockERC4626.sol";

abstract contract PUSDeVaultTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function pUSDeVault_approve(address spender, uint256 value) public asActor {
        currentOperation = OpType.GENERIC;

        __before();
        pUSDe.approve(spender, value);
        __after();

        eq(
            _before.pUSDe_depositedBase,
            _after.pUSDe_depositedBase,
            "pUSDe deposited base should not change on approve()"
        );
        eq(
            _before.pUSDe_pricePerShare,
            _after.pUSDe_pricePerShare,
            "pUSDe price per share should not change on approve()"
        );
    }

    function pUSDeVault_deposit_USDe_unspecified(uint128 assets /*, address receiver */ )
        public
        updateGhostsWithType(OpType.ADD)
        asActor
    {
        address receiver = _getActor();

        pUSDe.deposit(assets, receiver);
        pUSDe_totalDepositedUSDe[receiver] += assets;
    }

    function pUSDeVault_deposit_USDe_specified(uint128 tokenAssets /*, address receiver */ )
        public
        updateGhostsWithType(OpType.ADD)
        asActor
    {
        address receiver = _getActor();

        pUSDe.deposit(address(USDe), tokenAssets, receiver);
        pUSDe_totalDepositedUSDe[receiver] += tokenAssets;
    }

    function pUSDeVault_deposit_vault(uint128 vaultAssets /*, address receiver */ )
        public
        updateGhostsWithType(OpType.ADD)
        asActor
    {
        address receiver = _getActor();
        address vault = _getVault();

        // Convert vaultAssets -> "USDe equivalent" by calling previewRedeem() on the vault.
        uint256 usdeEquiv = MockERC4626(vault).previewRedeem(vaultAssets);

        pUSDe.deposit(vault, vaultAssets, receiver);
        pUSDe_totalDepositedUSDe[receiver] += usdeEquiv;
    }

    function pUSDeVault_mint_USDe_unspecified(uint128 shares /*, address receiver */ ) public updateGhostsWithType(OpType.ADD) asActor {
        address receiver = _getActor();

        uint256 deposited = pUSDe.mint(shares, receiver);
        pUSDe_totalDepositedUSDe[receiver] += deposited;
    }

    function pUSDeVault_mint_USDe_specified(uint128 tokenShares /*, address receiver */ )
        public
        updateGhostsWithType(OpType.ADD)
        asActor
    {
        address receiver = _getActor();

        uint256 deposited = pUSDe.mint(address(USDe), tokenShares, receiver);
        pUSDe_totalDepositedUSDe[receiver] += deposited;
    }

    function pUSDeVault_mint_vault(uint128 shares /*, address receiver */ )
        public
        updateGhostsWithType(OpType.ADD)
        asActor
    {
        address receiver = _getActor();
        address vault = _getVault();

        uint256 deposited = pUSDe.mint(vault, shares, receiver);

        // Convert deposited -> "USDe-equivalent" by calling previewRedeem() on the vault.
        uint256 usdeEquiv = MockERC4626(vault).previewRedeem(deposited);
        pUSDe_totalDepositedUSDe[receiver] += usdeEquiv;
    }

    function pUSDeVault_redeem(uint128 shares, address receiver, address owner)
        public
        updateGhostsWithType(OpType.REMOVE)
        asActor
    {
        uint256 usdeEquiv;
        if (pUSDe.currentPhase() == PreDepositPhase.PointsPhase) {
            // In the points phase, the redeemed assets is how many USDe will be sent to the receiver.
            usdeEquiv = pUSDe.redeem(shares, receiver, owner);
        } else {
            // In the yield phase, the vault will transfer sUSDe to the but quotes the redeemed assets in USDe.
            usdeEquiv = pUSDe.redeem(shares, receiver, owner);
        }

        pUSDe_totalWithdrawnUSDe[owner] += usdeEquiv;
    }

    function pUSDeVault_redeem_from_meta_vaults(uint128 shares, address receiver, address owner)
        public
        updateGhostsWithType(OpType.REMOVE)
        asActor
    {
        precondition(pUSDe.currentPhase() == PreDepositPhase.PointsPhase);

        uint256 usdeEquiv = pUSDe.previewRedeem(shares);

        // In the points phase, USDe can be redeemed from meta vaults to satisfy redemptions. Force this case.
        precondition(usdeEquiv > USDe.balanceOf(address(pUSDe)));
        precondition(shares <= pUSDe.balanceOf(owner));

        uint256 assets = pUSDe.redeem(shares, receiver, owner);
        t(assets == usdeEquiv, "Redeemed assets should equal to calculated USDe-equivalent");

        pUSDe_totalWithdrawnUSDe[owner] += usdeEquiv;
    }

    function pUSDeVault_redeem(address token, uint128 shares, address receiver, address owner)
        public
        updateGhostsWithType(OpType.REMOVE)
        asActor
    {
        uint256 usdeEquiv;

        if (token == address(USDe)) {
            usdeEquiv = pUSDe.redeem(token, shares, receiver, owner);
        } else {
            // In the points phase, the vault will transfer token to the receiver; to find "USDe-equivalent", we do a preview.
            // In the yield phase, the vault will transfer sUSDe to the receiver; to find "USDe-equivalent", we do a preview.
            uint256 tokenAssets = pUSDe.redeem(token, shares, receiver, owner);

            // Convert vault token balance diff -> "USDe-equivalent" by calling previewRedeem() on the sUSDe token.
            usdeEquiv = MockERC4626(token).previewRedeem(tokenAssets);
        }

        pUSDe_totalWithdrawnUSDe[owner] += usdeEquiv;
    }

    // NOTE: The following transfer functions are commented out because they affect the pUSDe_totalDepositedUSDe state.
    // It is not trivial to determine the "USDe-equivalent" of an existing pUSDe balance if the price per share changes
    // without introducing a new source of potential rounding errors which is certainly not desired.
    // To test share price inflation attacks, we instead expose a specific handler that mints and transfers atomically.

    // function pUSDeVault_transfer(address to, uint128 value) public asActor {
    //     currentOperation = OpType.GENERIC;

    //     __before();
    //     pUSDe.transfer(to, value);
    //     __after();

    //     eq(
    //         _before.pUSDe_depositedBase,
    //         _after.pUSDe_depositedBase,
    //         "pUSDe deposited base should not change on transfer()"
    //     );
    //     eq(
    //         _before.pUSDe_pricePerShare,
    //         _after.pUSDe_pricePerShare,
    //         "pUSDe price per share should not change on transfer()"
    //     );
    // }

    // function pUSDeVault_transferFrom(address from, address to, uint128 value) public asActor {
    //     currentOperation = OpType.GENERIC;

    //     __before();
    //     pUSDe.transferFrom(from, to, value);
    //     __after();

    //     eq(
    //         _before.pUSDe_depositedBase,
    //         _after.pUSDe_depositedBase,
    //         "pUSDe deposited base should not change on transferFrom()"
    //     );
    //     eq(
    //         _before.pUSDe_pricePerShare,
    //         _after.pUSDe_pricePerShare,
    //         "pUSDe price per share should not change on transferFrom()"
    //     );
    // }

    function pUSDeVault_withdraw(uint128 assets, address receiver, address owner)
        public
        updateGhostsWithType(OpType.REMOVE)
        asActor
    {
        // In the points phase, assets is how many USDe will be sent to the receiver.
        // In the yield phase, the vault will transfer sUSDe to the receiver; assets is how much USDe-equivalent will be sent.
        pUSDe.withdraw(assets, receiver, owner);

        pUSDe_totalWithdrawnUSDe[owner] += assets;
    }

    function pUSDeVault_withdraw_from_meta_vaults(uint128 assets, address receiver, address owner)
        public
        updateGhostsWithType(OpType.REMOVE)
        asActor
    {
        precondition(pUSDe.currentPhase() == PreDepositPhase.PointsPhase);

        // In the points phase, USDe can be withdrawn from meta vaults to satisfy withdrawals. Force this case.
        precondition(assets > USDe.balanceOf(address(pUSDe)));
        precondition(pUSDe.previewWithdraw(assets) <= pUSDe.balanceOf(owner));

        pUSDe.withdraw(assets, receiver, owner);
        pUSDe_totalWithdrawnUSDe[owner] += assets;
    }

    function pUSDeVault_withdraw(address token, uint128 tokenAssets, address receiver, address owner)
        public
        updateGhostsWithType(OpType.REMOVE)
        asActor
    {
        uint256 usdeEquiv;

        if (token == address(USDe)) {
            pUSDe.withdraw(token, tokenAssets, receiver, owner);
            usdeEquiv = tokenAssets;
        } else if (token == address(sUSDe)) {
            // In the points phase, the vault will transfer token to the receiver; to find "USDe-equivalent", we do a preview.
            // In the yield phase, the vault will transfer sUSDe to the receiver; to find "USDe-equivalent", we do a preview.
            uint256 tokenBalanceBefore = IERC20(token).balanceOf(receiver);
            pUSDe.withdraw(token, tokenAssets, receiver, owner);
            uint256 tokenBalanceAfter = IERC20(token).balanceOf(receiver);

            // In this case, the token transferred should be equal to tokenAssets
            eq(
                tokenBalanceAfter - tokenBalanceBefore,
                tokenAssets,
                "token balance diff from withdrawal should equal tokenAssets"
            );

            // Convert token balance diff -> "USDe-equivalent" by calling previewRedeem() on the token token.
            usdeEquiv = MockERC4626(token).previewRedeem(tokenAssets);
        }

        pUSDe_totalWithdrawnUSDe[owner] += usdeEquiv;
    }

    // preview functions must not account for vault specific/user/global limits

    function pUSDeVault_previewDeposit(uint128 amount) public asActor {
        try pUSDe.previewDeposit(amount) {}
        catch {
            t(false, "pUSDeVault should not revert on previewDeposit()");
        }
    }

    function pUSDeVault_previewMint(uint128 shares) public asActor {
        try pUSDe.previewMint(shares) {}
        catch {
            t(false, "pUSDeVault should not revert on previewMint()");
        }
    }

    function pUSDeVault_previewRedeem(uint128 shares) public asActor {
        try pUSDe.previewRedeem(shares) {}
        catch {
            t(false, "pUSDeVault should not revert on previewRedeem()");
        }
    }

    function pUSDeVault_previewRedeem(address caller, uint128 shares) public asActor {
        try pUSDe.previewRedeem(caller, shares) {}
        catch {
            t(false, "pUSDeVault should not revert on previewRedeem() with caller");
        }
    }

    function pUSDeVault_previewWithdraw(uint128 amount) public asActor {
        try pUSDe.previewWithdraw(amount) {}
        catch {
            t(false, "pUSDeVault should not revert on previewWithdraw()");
        }
    }
}

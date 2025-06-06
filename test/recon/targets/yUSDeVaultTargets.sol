// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import "contracts/predeposit/yUSDeVault.sol";

abstract contract YUSDeVaultTargets is BaseTargetFunctions, Properties {
    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function yUSDeVault_approve(address spender, uint128 value) public asActor {
        currentOperation = OpType.GENERIC;

        __before();
        yUSDe.approve(spender, value);
        __after();

        eq(
            _before.yUSDe_pricePerShare,
            _after.yUSDe_pricePerShare,
            "yUSDe price per share should not change on approve()"
        );
    }

    function yUSDeVault_deposit(uint128 assets /*, address receiver */ )
        public
        updateGhostsWithType(OpType.ADD)
        asActor
    {
        address receiver = _getActor();

        yUSDe.deposit(assets, receiver);

        // Compute how much "USDe‐equivalent" is backing the pUSDe assets deposited into yUSDe.
        // We use previewRedeem(address(0), assets) because pUSDe includes yield if caller is yUSDe.
        uint256 usdeEquiv = pUSDe.previewRedeem(address(0), assets);

        yUSDe_totalDepositedUSDe[receiver] += usdeEquiv;
    }

    function yUSDeVault_mint(uint128 shares /*, address receiver */ ) public updateGhostsWithType(OpType.ADD) asActor {
        address receiver = _getActor();

        uint256 assets = yUSDe.mint(shares, receiver);

        // Compute how much "USDe‐equivalent" is backing the pUSDe assets deposited into yUSDe.
        // We use previewRedeem(address(0), assets) because pUSDe includes yield if caller is yUSDe.
        uint256 usdeEquiv = pUSDe.previewRedeem(address(0), assets);

        yUSDe_totalDepositedUSDe[receiver] += usdeEquiv;
    }

    function yUSDeVault_redeem(uint128 shares, address receiver, address owner)
        public
        // updateGhostsWithType(OpType.REMOVE)
        asActor
    {
        currentOperation = OpType.REMOVE;

        __before();
        yUSDe.redeem(shares, receiver, owner);
        __after();

        // Compute how much "USDe‐equivalent" is backing the pUSDe assets withdrawn from yUSDe.
        // Note: We use previewRedeem() on the balance diff to avoid relying on the incorrect state update, since yield needs to be considered.
        // uint256 usdeEquiv = pUSDe.previewRedeem(address(yUSDe), assets);
        uint256 usdeEquiv = sUSDe.previewRedeem(_after.pUSDe_balanceOfSUSDe - _before.pUSDe_balanceOfSUSDe);

        yUSDe_totalWithdrawnUSDe[owner] += usdeEquiv;

        eq(
            _after.pUSDe_depositedBase - _before.pUSDe_depositedBase,
            usdeEquiv,
            "yUSDeVault redeem should decrement depositedBase by the USDe-equivalent of assets redeemed"
        );
    }

    // NOTE: The following transfer functions are commented out because they affect the yUSDe_totalDepositedUSDe state.
    // It is not trivial to determine the "USDe-equivalent" of an existing yUSDe balance if the price per share changes
    // without introducing a new source of potential rounding errors which is certainly not desired.
    // To test share price inflation attacks, we instead expose a specific handler that mints and transfers atomically.

    // function yUSDeVault_transfer(address to, uint128 value) public asActor {
    //     currentOperation = OpType.GENERIC;

    //     __before();
    //     yUSDe.transfer(to, value);
    //     __after();

    //     eq(
    //         _before.yUSDe_pricePerShare,
    //         _after.yUSDe_pricePerShare,
    //         "yUSDe price per share should not change on transfer()"
    //     );
    // }

    // function yUSDeVault_transferFrom(address from, address to, uint128 value) public asActor {
    //     currentOperation = OpType.GENERIC;

    //     __before();
    //     yUSDe.transferFrom(from, to, value);
    //     __after();

    //     eq(
    //         _before.yUSDe_pricePerShare,
    //         _after.yUSDe_pricePerShare,
    //         "yUSDe price per share should not change on transferFrom()"
    //     );
    // }

    function yUSDeVault_withdraw(uint128 assets, address receiver, address owner)
        public
        // updateGhostsWithType(OpType.REMOVE)
        asActor
    {
        currentOperation = OpType.REMOVE;

        __before();
        yUSDe.withdraw(assets, receiver, owner);
        __after();

        // Compute how much "USDe‐equivalent" is backing the pUSDe assets withdrawn from yUSDe.
        // Note: We use previewRedeem() on the balance diff to avoid relying on the incorrect state update, since yield needs to be considered.
        // uint256 usdeEquiv = pUSDe.previewRedeem(address(yUSDe), assets);
        uint256 usdeEquiv = sUSDe.previewRedeem(_after.pUSDe_balanceOfSUSDe - _before.pUSDe_balanceOfSUSDe);

        yUSDe_totalWithdrawnUSDe[owner] += usdeEquiv;

        eq(
            _after.pUSDe_depositedBase - _before.pUSDe_depositedBase,
            usdeEquiv,
            "yUSDeVault withdraw should decrement depositedBase by the USDe-equivalent of assets redeemed"
        );
    }

    // preview functions must not account for vault specific/user/global limits

    function yUSDeVault_previewDeposit(uint128 amount) public asActor {
        try yUSDe.previewDeposit(amount) {}
        catch {
            t(false, "yUSDeVault should not revert on previewDeposit()");
        }
    }

    function yUSDeVault_previewMint(uint128 shares) public asActor {
        try yUSDe.previewMint(shares) {}
        catch {
            t(false, "yUSDeVault should not revert on previewMint()");
        }
    }

    function yUSDeVault_previewRedeem(uint128 shares) public asActor {
        try yUSDe.previewRedeem(shares) {}
        catch {
            t(false, "yUSDeVault should not revert on previewRedeem()");
        }
    }

    function yUSDeVault_previewWithdraw(uint128 amount) public asActor {
        try yUSDe.previewWithdraw(amount) {}
        catch {
            t(false, "yUSDeVault should not revert on previewWithdraw()");
        }
    }
}

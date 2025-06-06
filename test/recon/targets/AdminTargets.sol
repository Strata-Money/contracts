// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

import {PreDepositPhase} from "contracts/interfaces/IPhase.sol";

abstract contract AdminTargets is BaseTargetFunctions, Properties {
    modifier alwaysRevert() {
        revert("alwaysRevert");
        _;
    }

    /// CUSTOM TARGET FUNCTIONS - Add your own target functions here ///

    function yUSDeVault_fundInitialBalance(uint128 initialBalance) public updateGhosts asAdmin {
        // a new yUSDe vault should be funded with initial balance only once
        precondition(pUSDe.balanceOf(address(yUSDe)) == 0);
        precondition(yUSDe.depositsEnabled());

        USDe.mint(address(this), initialBalance);
        USDe.approve(address(pUSDe), initialBalance);
        uint256 pUSDeAmount = pUSDe.deposit(initialBalance, address(this));
        pUSDe.approve(address(yUSDe), pUSDeAmount);
        yUSDe.deposit(pUSDeAmount, address(this));
    }

    // NOTE: this makes it more difficult to get coverage of redeemRequiredBaseAssets() and doesn't really add too much
    // function pUSDeVault_sharePriceInflation(uint128 deposit, uint128 direct) public asAdmin {
    //     USDe.mint(address(this), deposit);
    //     USDe.approve(address(pUSDe), deposit);
    //     pUSDe.deposit(deposit, address(this));

    //     USDe.mint(address(pUSDe), direct);
    // }

    function yUSDeVault_sharePriceInflation(uint128 deposit, uint128 direct) public asAdmin {
        // deposit USDe into pUSDe
        USDe.mint(address(this), deposit);
        USDe.approve(address(pUSDe), deposit);
        uint256 depositShares = pUSDe.deposit(deposit, address(this));

        // deposit pUSDe shares into yUSDe
        pUSDe.approve(address(yUSDe), depositShares);
        yUSDe.deposit(depositShares, address(this));

        // deposit pUSDe directly to yUSDe to inflate the share price
        USDe.mint(address(this), direct);
        USDe.approve(address(pUSDe), direct);
        pUSDe.deposit(direct, address(yUSDe));
    }

    function yUSDeVault_sharePriceInflation_sUSDe(uint128 deposit, uint128 direct) public asAdmin {
        // deposit USDe into pUSDe
        USDe.mint(address(this), deposit);
        USDe.approve(address(pUSDe), deposit);
        uint256 depositShares = pUSDe.deposit(deposit, address(this));

        // deposit pUSDe shares into yUSDe
        pUSDe.approve(address(yUSDe), depositShares);
        yUSDe.deposit(depositShares, address(this));

        // mint USDe directly to sUSDe to inflate the yield
        USDe.mint(address(sUSDe), direct);
    }

    /// AUTO GENERATED TARGET FUNCTIONS - WARNING: DO NOT DELETE OR MODIFY THIS LINE ///

    function pUSDeVault_addVault() public asAdmin {
        // only add vaults during the PointsPhase since sUSDe is the only asset supported during the YieldPhase
        precondition(pUSDe.currentPhase() == PreDepositPhase.PointsPhase);

        // cap the maximum number of vaults to 10
        precondition(pUSDe.getAssets().length < 10);

        address vault = _getVault();

        // avoid adding the same vault more than once – in this case it is known that there will be multiple pushes to the array
        precondition(!pUSDe.isAssetSupported(vault));

        currentOperation = OpType.GENERIC;

        __before(vault);
        pUSDe.addVault(vault);
        __after(vault);

        t(_before.pUSDe_assetSupported[vault] == false, "pUSDe asset should not be supported before addVault()");
        t(_after.pUSDe_assetSupported[vault] == true, "pUSDe asset should be supported after addVault()");
        eq(
            _after.pUSDe_assets.length,
            _before.pUSDe_assets.length + 1,
            "pUSDe assets length should increase by 1 after addVault()"
        );
    }

    // NOTE: deployed as an ERC1967Proxy, so apply the `alwaysRevert` modifier as there is no need to expose the initialize function
    // function pUSDeVault_initialize(address owner_, IERC20 USDe_, IERC4626 sUSDe_) public alwaysRevert asAdmin {
    //     pUSDe.initialize(owner_, USDe_, sUSDe_);
    // }

    function pUSDeVault_removeVault() public asAdmin {
        // only remove vaults during the PointsPhase since sUSDe is the only asset supported during the YieldPhase
        precondition(pUSDe.currentPhase() == PreDepositPhase.PointsPhase);

        address vault = _getVault();

        // avoid attempting to remove an unsupported vault as it will revert
        precondition(pUSDe.isAssetSupported(vault));

        __before(vault);
        pUSDe.removeVault(vault);
        __after(vault);

        t(_before.pUSDe_assetSupported[vault] == true, "pUSDe asset should be supported before removeVault()");
        t(_after.pUSDe_assetSupported[vault] == false, "pUSDe asset should not be supported after removeVault()");
        eq(
            _after.pUSDe_assets.length,
            _before.pUSDe_assets.length - 1,
            "pUSDe assets length should decrease by 1 after removeVault()"
        );

        // vault is fully redeemed, so its asset balance should be 0
        eq(_after.pUSDe_assetBalances[vault], 0, "pUSDe asset balance should be 0 after removeVault()");

        // pUSDe balance of USDe should increase equal to the vault's depositedBase contribution
        // but this is not the case if the vault's total assets decrease (e.g. due to a hack)
        // so since we expose recognizeProfit() and recognizeProfit() from the MockERC4626Harness, we simply check that the pUSDe balance of USDe does not decrease
        gte(
            _after.pUSDe_balanceOfUSDe,
            _before.pUSDe_balanceOfUSDe,
            "pUSDe balance of USDe should not decrease after removeVault()"
        );
    }

    function pUSDeVault_setDepositsEnabled(bool depositsEnabled_) public asAdmin {
        // avoid setting the same value as the current depositsEnabled
        precondition(pUSDe.depositsEnabled() != depositsEnabled_);

        currentOperation = OpType.GENERIC;

        __before();
        pUSDe.setDepositsEnabled(depositsEnabled_);
        __after();

        t(
            _after.pUSDe_depositsEnabled == depositsEnabled_,
            "pUSDe deposits should be set to depositsEnabled_ after setDepositsEnabled()"
        );
    }

    function pUSDeVault_setWithdrawalsEnabled(bool withdrawalsEnabled_) public asAdmin {
        // avoid setting the same value as the current withdrawalsEnabled
        precondition(pUSDe.withdrawalsEnabled() != withdrawalsEnabled_);

        currentOperation = OpType.GENERIC;

        __before();
        pUSDe.setWithdrawalsEnabled(withdrawalsEnabled_);
        __after();

        t(
            _after.pUSDe_withdrawalsEnabled == withdrawalsEnabled_,
            "pUSDe withdrawals should be set to withdrawalsEnabled_ after setWithdrawalsEnabled()"
        );
    }

    function pUSDeVault_startYieldPhase() public asAdmin {
        // pUSDe must have a non-zero USDe balance to start yield phase
        precondition(pUSDe.totalAssets() != 0);

        currentOperation = OpType.GENERIC;

        __before();
        pUSDe.startYieldPhase();
        __after();

        // add the sUSDe vault to the vault manager since it is the only supported asset during the YieldPhase
        _addVault(address(sUSDe));

        // current phase should change from PointsPhase to YieldPhase
        t(
            _before.pUSDe_currentPhase == PreDepositPhase.PointsPhase,
            "pUSDe yield phase should be PreDepositPhase before startYieldPhase()"
        );
        t(
            _after.pUSDe_currentPhase == PreDepositPhase.YieldPhase,
            "pUSDe yield phase should be YieldPhase after startYieldPhase()"
        );

        // yUSDe current phase state should reflect the pUSDe current phase state
        t(
            _before.yUSDe_currentPhase == PreDepositPhase.PointsPhase,
            "yUSDe yield phase should be PreDepositPhase before startYieldPhase()"
        );
        // NOTE: this property will break as the yUSDe state is not currently updated, so we comment it out for now.
        // t(_after.yUSDe_currentPhase == PreDepositPhase.YieldPhase, "yUSDe yield phase should be YieldPhase after startYieldPhase()");

        // pUSDe total assets and price per full share should not change
        eq(
            _before.pUSDe_depositedBase,
            _after.pUSDe_depositedBase,
            "pUSDe deposited base should not change on startYieldPhase()"
        );
        eq(
            _before.pUSDe_pricePerShare,
            _after.pUSDe_pricePerShare,
            "pUSDe price per share should not change on startYieldPhase()"
        );

        // yUSDe price per full share should not decrease (it can increase due to donations which are considered as sUSDe yield)
        lte(
            _before.yUSDe_pricePerShare,
            _after.yUSDe_pricePerShare,
            "yUSDe price per share should not decrease on startYieldPhase()"
        );

        // vaults are fully redeemed, so their asset balances should be 0
        for (uint256 i; i < _before.pUSDe_assets.length; i++) {
            address vault = _before.pUSDe_assets[i];
            __after(vault);
            eq(_after.pUSDe_assetBalances[vault], 0, "pUSDe asset balance should be 0 after startYieldPhase()");
        }

        // USDe is fully deposited into sUSDe, so pUSDe balance of USDe should be 0
        eq(_after.pUSDe_balanceOfUSDe, 0, "pUSDe balance of USDe should be 0 after startYieldPhase()");

        // sUSDe balance of pUSDe before is not guaranteed to be 0 due to donations, so we only check that it is greater after
        gt(
            _after.pUSDe_balanceOfSUSDe,
            _before.pUSDe_balanceOfSUSDe,
            "pUSDe balance of sUSDe should increase after startYieldPhase()"
        );
    }

    function pUSDeVault_updateYUSDeVault() public asAdmin {
        // avoid setting the same value as the current yUSDe vault
        precondition(address(pUSDe.yUSDe()) != _getYUSDeVault());

        currentOperation = OpType.GENERIC;

        __before();
        pUSDe.updateYUSDeVault(_getYUSDeVault());
        __after();

        t(
            _after.pUSDe_yUSDeVault == _getYUSDeVault(),
            "pUSDe yUSDe vault should be set to _getYUSDeVault() after updateYUSDeVault()"
        );
    }

    // NOTE: deployed as an ERC1967Proxy, so apply the `alwaysRevert` modifier as there is no need to expose the initialize function
    // function yUSDeVault_initialize(address owner_, IERC20 USDe_, IERC4626 sUSDe_, IERC4626YieldVault pUSDeVault_) public alwaysRevert asAdmin {
    //     yUSDe.initialize(owner_, USDe_, sUSDe_, pUSDeVault_);
    // }

    function yUSDeVault_setDepositsEnabled(bool depositsEnabled_) public asAdmin {
        // avoid setting the same value as the current depositsEnabled
        precondition(yUSDe.depositsEnabled() != depositsEnabled_);

        currentOperation = OpType.GENERIC;

        __before();
        yUSDe.setDepositsEnabled(depositsEnabled_);
        __after();

        t(
            _after.yUSDe_depositsEnabled == depositsEnabled_,
            "yUSDe deposits should be set to depositsEnabled_ after setDepositsEnabled()"
        );
    }

    function yUSDeVault_setWithdrawalsEnabled(bool withdrawalsEnabled_) public asAdmin {
        // avoid setting the same value as the current withdrawalsEnabled
        precondition(yUSDe.withdrawalsEnabled() != withdrawalsEnabled_);

        currentOperation = OpType.GENERIC;

        __before();
        yUSDe.setWithdrawalsEnabled(withdrawalsEnabled_);
        __after();

        t(
            _after.yUSDe_withdrawalsEnabled == withdrawalsEnabled_,
            "yUSDe withdrawals should be set to withdrawalsEnabled_ after setWithdrawalsEnabled()"
        );
    }
}

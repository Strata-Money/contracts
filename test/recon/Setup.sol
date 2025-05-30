// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

// Chimera deps
import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

// Managers
import {ActorManager} from "@recon/ActorManager.sol";
import {AssetManager} from "@recon/AssetManager.sol";

// Helpers
import {Utils} from "@recon/Utils.sol";

// Your deps
import {VaultManager} from "./VaultManager.sol";

import {pUSDeVault, pUSDeVaultHarness} from "./harness/pUSDeVaultHarness.sol";
import {yUSDeVault, yUSDeVaultHarness} from "./harness/yUSDeVaultHarness.sol";

import {MockUSDe} from "contracts/test/MockUSDe.sol";
import {MockStakedUSDe} from "contracts/test/MockStakedUSDe.sol";
import {MockERC4626Harness} from "./harness/MockERC4626Harness.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract Setup is BaseSetup, ActorManager, AssetManager, VaultManager, Utils {
    uint256 constant MIN_SHARES = 0.1 ether;

    MockUSDe USDe;
    MockStakedUSDe sUSDe;
    MockERC4626Harness eUSDe;
    MockERC4626Harness eUSDe2;
    pUSDeVaultHarness pUSDe;
    yUSDeVaultHarness yUSDe;

    /// === Setup === ///
    /// This contains all calls to be performed in the tester constructor, both for Echidna and Foundry
    function setup() internal virtual override {
        address owner = address(this);

        USDe = new MockUSDe();

        // add USDe to the asset manager and switch to it (since there are no other assets)
        _addAsset(address(USDe));
        _switchAsset(0);

        // don't add sUSDe to the vault manager, since it won't be used during the points phase
        sUSDe = new MockStakedUSDe(USDe, owner, owner);

        // deploy USDe vaults
        eUSDe = new MockERC4626Harness(USDe);
        eUSDe2 = new MockERC4626Harness(USDe);

        // add USDe vaults to the vault manager and switch to one of them (since there are no other vaults)
        _addVault(address(eUSDe));
        _addVault(address(eUSDe2));
        _switchVault(0);

        pUSDe = pUSDeVaultHarness(
            address(
                new ERC1967Proxy(
                    address(new pUSDeVaultHarness()),
                    abi.encodeWithSelector(pUSDeVault.initialize.selector, owner, USDe, sUSDe)
                )
            )
        );

        yUSDe = yUSDeVaultHarness(
            address(
                new ERC1967Proxy(
                    address(new yUSDeVaultHarness()),
                    abi.encodeWithSelector(yUSDeVault.initialize.selector, owner, USDe, sUSDe, pUSDe)
                )
            )
        );

        // add yUSDe to the vault manager and switch to it (since there are no other yUSDe vaults)
        _addYUSDeVault(address(yUSDe));
        _switchYUSDeVault(0);

        // setup initial state
        pUSDe.addVault(address(eUSDe));
        pUSDe.addVault(address(eUSDe2));
        pUSDe.setDepositsEnabled(true);
        pUSDe.setWithdrawalsEnabled(true);
        pUSDe.updateYUSDeVault(address(yUSDe));

        // assert tokens are setup correctly
        if (pUSDe.USDe() != USDe) revert("pUSDe USDe should be set to the USDe token");
        if (pUSDe.sUSDe() != sUSDe) revert("pUSDe sUSDe should be set to the sUSDe token");
        if (address(pUSDe.yUSDe()) != address(yUSDe)) revert("pUSDe yUSDe should be set to the yUSDe vault");
        if (address(yUSDe.pUSDeVault()) != address(pUSDe)) revert("yUSDe pUSDeVault should be set to the pUSDe vault");
        if (yUSDe.USDe() != USDe) revert("yUSDe USDe should be set to the USDe token");
        if (yUSDe.sUSDe() != sUSDe) revert("yUSDe sUSDe should be set to the sUSDe token");
    }

    /// === MODIFIERS === ///
    /// Prank admin and actor

    modifier asAdmin() {
        vm.prank(address(this));
        _;
    }

    modifier asActor() {
        vm.prank(address(_getActor()));
        _;
    }
}

// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";
import {CryticAsserts} from "@chimera/CryticAsserts.sol";
import {CryticERC4626PropertyTests} from "properties/ERC4626PropertyTests.sol";

import {pUSDeVault, pUSDeVaultHarness} from "./harness/pUSDeVaultHarness.sol";
import {yUSDeVault, yUSDeVaultHarness} from "./harness/yUSDeVaultHarness.sol";
import {MockERC4626Harness} from "./harness/MockERC4626Harness.sol";

import "contracts/test/MockUSDe.sol";
import "contracts/test/MockStakedUSDe.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract CryticERC4626Tester is BaseSetup, CryticERC4626PropertyTests {
    MockUSDe USDe;
    MockStakedUSDe sUSDe;
    MockERC4626Harness eUSDe;
    MockERC4626Harness eUSDe2;
    pUSDeVaultHarness pUSDe;
    yUSDeVaultHarness yUSDe;

    function setup() internal virtual override {
        address owner = address(this);

        USDe = new MockUSDe();
        sUSDe = new MockStakedUSDe(USDe, owner, owner);
        eUSDe = new MockERC4626Harness(USDe);
        eUSDe2 = new MockERC4626Harness(USDe);

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
}

// echidna . --contract CryticERC4626Tester_pUSDe --config echidna_pUSDe.yaml --format text --workers 16 --test-limit 1000000
// medusa fuzz --config medusa_pUSDe.json
contract CryticERC4626Tester_pUSDe is CryticERC4626Tester {
    constructor() payable {
        setup();
    }

    function setup() internal override {
        super.setup();
        initialize(address(pUSDe), address(USDe), true);

        uint256 minShares = 0.1 ether;
        uint256 initialDeposit = pUSDe.previewMint(minShares);
        USDe.mint(address(this), initialDeposit);
        USDe.approve(address(pUSDe), initialDeposit);
        pUSDe.mint(minShares, address(this));
    }
}

// echidna . --contract CryticERC4626Tester_yUSDe --config echidna_yUSDe.yaml --format text --workers 16 --test-limit 1000000
// medusa fuzz --config medusa_yUSDe.json
contract CryticERC4626Tester_yUSDe is CryticERC4626Tester {
    constructor() payable {
        setup();
    }

    function setup() internal override {
        super.setup();
        initialize(address(yUSDe), address(pUSDe), true);

        yUSDe.setDepositsEnabled(true);
        yUSDe.setWithdrawalsEnabled(true);

        uint256 initialDeposit = 0.1 ether;
        USDe.mint(address(this), initialDeposit);
        USDe.approve(address(pUSDe), initialDeposit);
        uint256 pUSDeAmount = pUSDe.deposit(initialDeposit, address(this));
        pUSDe.approve(address(yUSDe), pUSDeAmount);
        yUSDe.deposit(pUSDeAmount, address(this));
    }
}

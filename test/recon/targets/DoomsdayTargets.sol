// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseTargetFunctions} from "@chimera/BaseTargetFunctions.sol";
import {BeforeAfter} from "../BeforeAfter.sol";
import {Properties} from "../Properties.sol";
// Chimera deps
import {vm} from "@chimera/Hevm.sol";

// Helpers
import {Panic} from "@recon/Panic.sol";

abstract contract DoomsdayTargets is BaseTargetFunctions, Properties {
    /// Makes a handler have no side effects
    /// The fuzzer will call this anyway, and because it reverts it will be removed from shrinking
    /// Replace the "withGhosts" with "stateless" to make the code clean
    modifier stateless() {
        _;
        revert("stateless");
    }

    // NOTE: this is equivalent to checking totalAssets() as it is overridden to return depositedBase
    function doomsday_pUSDe_depositedBase_totalSupply() public {
        if (pUSDe.depositedBase() == 0) {
            eq(pUSDe.totalSupply(), 0, "pUSDe totalSupply should be 0 if depositedBase is 0");
        } else {
            gt(pUSDe.totalSupply(), 0, "pUSDe totalSupply should be > 0 if depositedBase is > 0");
        }
    }

    function doomsday_yUSDe_totalAssets_totalSupply() public {
        if (yUSDe.totalAssets() == 0) {
            eq(yUSDe.totalSupply(), 0, "yUSDe totalSupply should be 0 if totalAssets is 0");
        } else {
            // TODO: this actually depends on the intended initialization behaviour, i.e. does the protocol simply transfer pUSDe or does it mint yUSDe?
            // NOTE: though any other address can mint pUSDe directly to yUSDe, so this can still be broken and we comment it out for now.
            // gt(yUSDe.totalSupply(), 0, "yUSDe totalSupply should be > 0 if totalAssets is > 0");
        }
    }
}

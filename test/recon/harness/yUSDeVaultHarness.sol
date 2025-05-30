// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {CryticIERC4626Internal} from "properties/util/IERC4626Internal.sol";
import {MockERC20} from "setup-helpers/MockERC20.sol";

import {yUSDeVault} from "contracts/predeposit/yUSDeVault.sol";

contract yUSDeVaultHarness is yUSDeVault, CryticIERC4626Internal {
    // NOTE: this doesn't really make sense for the yUSDeVault unless tested in isolation, so we don't expose it in the AdminTargets
    function recognizeProfit(uint256 amount) public {
        MockERC20(asset()).mint(address(this), amount);
    }

    // NOTE: this doesn't really make sense for the yUSDeVault unless tested in isolation, so we don't expose it in the AdminTargets
    function recognizeLoss(uint256 amount) public {
        MockERC20(asset()).burn(address(this), amount);
    }
}

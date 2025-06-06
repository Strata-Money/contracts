// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {CryticIERC4626Internal} from "properties/util/IERC4626Internal.sol";
import {MockERC20} from "setup-helpers/MockERC20.sol";

import {pUSDeVault} from "contracts/predeposit/pUSDeVault.sol";

contract pUSDeVaultHarness is pUSDeVault, CryticIERC4626Internal {
    // NOTE: this doesn't really make sense for the pUSDeVault unless tested in isolation, so we don't expose it in the AdminTargets
    function recognizeProfit(uint256 amount) public {
        MockERC20(asset()).mint(address(this), amount);
    }

    // NOTE: this doesn't really make sense for the pUSDeVault unless tested in isolation, so we don't expose it in the AdminTargets
    function recognizeLoss(uint256 amount) public {
        MockERC20(asset()).burn(address(this), amount);
    }

    function getAssets() public view returns (address[] memory) {
        address[] memory assets = new address[](assetsArr.length);
        for (uint256 i; i < assetsArr.length; i++) {
            assets[i] = assetsArr[i].asset;
        }
        return assets;
    }
}

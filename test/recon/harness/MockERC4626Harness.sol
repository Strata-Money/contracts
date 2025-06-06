// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryticIERC4626Internal} from "properties/util/IERC4626Internal.sol";

import {MockERC4626, IERC20} from "contracts/test/MockERC4626.sol";
import {MockERC20} from "setup-helpers/MockERC20.sol";

contract MockERC4626Harness is MockERC4626, CryticIERC4626Internal {
    constructor(IERC20 token) MockERC4626(token) {}

    function recognizeProfit(uint256 amount) public {
        MockERC20(asset()).mint(address(this), amount);
    }

    function recognizeLoss(uint256 amount) public {
        MockERC20(asset()).burn(address(this), amount);
    }
}

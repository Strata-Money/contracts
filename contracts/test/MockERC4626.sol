// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MockERC4626 is ERC4626 {
    constructor(IERC20 token) ERC20("MockERC4626", "M4626") ERC4626(token)  {}


}

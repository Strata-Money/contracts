// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;


import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IMetaVault {
    enum EAssetType {
        ERC4626,
        ERC20
    }

    struct TAsset {
        address asset;
        EAssetType kind;
        bool paused;
    }

    function deposit(address token, uint256 tokenAssets, address receiver) external returns (uint256);
    function mint(address token, uint256 shares, address receiver) external returns (uint256);
    function withdraw(address token, uint256 tokenAssets, address receiver, address owner) external returns (uint256);
    function redeem(address token, uint256 shares, address receiver, address owner) external returns (uint256);

    function isAssetSupported(address token) external view returns (bool);

}

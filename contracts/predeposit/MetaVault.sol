// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PreDepositVault} from "./PreDepositVault.sol";
import {IMetaVault} from "../interfaces/IMetaVault.sol";
import {PreDepositPhase} from "../interfaces/IPhase.sol";

/// @notice Extends ERC4626 Vault to accept multiple additional underlying vaults
/// @dev The underlying vaults should be without cooldown periods and support immediate deposit/withdraw for the base ERC4626 asset
abstract contract MetaVault is IMetaVault, PreDepositVault {


    /** Storage */
    // Track the deposited balance
    uint256 public depositedBase;

    // The assets that are supported for direct deposits
    TAsset[] public assetsArr;

    // Track the assets in the mapping for easier access
    mapping(address => TAsset) public assetsMap;


    /** Errors */
    error UnsupportedAsset(address asset);
    error PausedAsset(address asset);


    /** Events */
    event OnVaultAdded(address indexed token);
    event OnVaultRemoved(address indexed token);
    event OnVaultPausedStateChanged(address indexed token, bool paused);
    event OnMetaDeposit(address indexed owner, address indexed token, uint256 tokenAssets, uint256 shares);
    event OnMetaWithdraw(address indexed owner, address indexed token, uint256 tokenAssets, uint256 shares);


    function isAssetSupported(address token) external view returns (bool) {
        return token == asset() || assetsMap[token].asset != address(0);
    }

    /// @notice Converts provided token amount to base amount and increases the total Deposited Base
    /// @param token The address of the token to deposit
    /// @param tokenAssets The amount of token assets to deposit
    /// @param receiver The address that will receive the minted shares
    /// @return The number of shares minted
    function deposit(address token, uint256 tokenAssets, address receiver) public virtual returns (uint256) {
        if (token == asset()) {
            return deposit(tokenAssets, receiver);
        }
        requireActiveVault(token);

        uint baseAssets = IERC4626(token).previewRedeem(tokenAssets);
        uint shares = previewDeposit(baseAssets);
        _deposit(token, _msgSender(), receiver, baseAssets, tokenAssets, shares);
        return shares;
    }

    /// @notice Mints shares by first calculating the required amount of base tokens, then converting to token amount
    /// @param token The address of the token to mint shares for
    /// @param shares The number of shares to mint
    /// @param receiver The address that will receive the minted shares
    /// @return The amount of token assets deposited
    function mint(address token, uint256 shares, address receiver) public virtual returns (uint256) {
        if (token == asset()) {
            return mint(shares, receiver);
        }
        requireActiveVault(token);

        uint baseAssets = previewMint(shares);
        uint tokenAssets = IERC4626(token).previewWithdraw(baseAssets);
        _deposit(token, _msgSender(), receiver, baseAssets, tokenAssets, shares);
        return tokenAssets;
    }

    /// @dev Generic deposit method for "deposit" and "mint" functions
    /// @notice Increases the deposited amount and transfers tokens to the contract
    /// @param token The address of the token being deposited
    /// @param caller The address initiating the deposit
    /// @param receiver The address that will receive the minted shares
    /// @param baseAssets The amount of base assets being deposited
    /// @param tokenAssets The amount of token assets being deposited
    /// @param shares The number of shares to mint
    function _deposit(address token, address caller, address receiver, uint256 baseAssets, uint256 tokenAssets, uint256 shares) internal virtual {

        depositedBase += baseAssets;

        SafeERC20.safeTransferFrom(IERC20(token), caller, address(this), tokenAssets);
        _mint(receiver, shares);
        onAfterDepositChecks();
        emit Deposit(caller, receiver, baseAssets, shares);
        emit OnMetaDeposit(receiver, token, tokenAssets, shares);
    }

    /// @notice Withdraws a specified amount of tokens from the vault
    /// @dev Converts the token amount to the base token amount and decreases the deposited balance
    /// @param token The address of the token to withdraw
    /// @param tokenAssets The amount of token assets to withdraw
    /// @param receiver The address that will receive the withdrawn assets
    /// @param owner The address that owns the shares being burned
    /// @return The number of shares burned
    function withdraw(address token, uint256 tokenAssets, address receiver, address owner) public virtual returns (uint256) {
        if (token == asset()) {
            return withdraw(tokenAssets, receiver, owner);
        }
        requireSupportedVault(token);

        uint256 baseAssets = IERC4626(token).previewRedeem(tokenAssets);
        uint256 maxAssets = maxWithdraw(owner);
        if (baseAssets > maxAssets) {
            revert ERC4626ExceededMaxWithdraw(owner, baseAssets, maxAssets);
        }

        uint256 shares = previewWithdraw(baseAssets);
        _withdraw(token, _msgSender(), receiver, owner, baseAssets, tokenAssets, shares);
        return shares;
    }

    /// @notice Redeems a specified amount of shares for tokens
    /// @dev Converts the shares to base token amount and decreases the deposited balance
    /// @param token The address of the token to receive in exchange for shares
    /// @param shares The number of shares to redeem
    /// @param receiver The address that will receive the redeemed tokens
    /// @param owner The address that owns the shares being redeemed
    /// @return The amount of token assets received
    function redeem(address token, uint256 shares, address receiver, address owner) public virtual returns (uint256) {
        if (token == asset()) {
            return redeem(shares, receiver, owner);
        }
        requireSupportedVault(token);

        uint256 maxShares = maxRedeem(owner);
        if (shares > maxShares) {
            revert ERC4626ExceededMaxRedeem(owner, shares, maxShares);
        }

        uint256 baseAssets = previewRedeem(shares);
        uint256 tokenAssets = IERC4626(token).previewWithdraw(baseAssets);
        _withdraw(token, _msgSender(), receiver, owner, baseAssets, tokenAssets, shares);
        return tokenAssets;
    }

    /// @dev Generic withdraw method for "withdraw" and "redeem" functions
    /// @notice Decreases the deposited amount and transfers the desired token to the receiver
    /// @param token The address of the token to withdraw
    /// @param caller The address initiating the withdrawal
    /// @param receiver The address that will receive the withdrawn assets
    /// @param owner The address that owns the shares being burned
    /// @param baseAssets The amount of base assets being withdrawn
    /// @param tokenAssets The amount of token assets being withdrawn
    /// @param shares The number of shares to burn
    function _withdraw(
        address token,
        address caller,
        address receiver,
        address owner,
        uint256 baseAssets,
        uint256 tokenAssets,
        uint256 shares
    ) internal virtual {
        if (caller != owner) {
            _spendAllowance(owner, caller, shares);
        }

        depositedBase -= baseAssets;

        _burn(owner, shares);
        SafeERC20.safeTransfer(IERC20(token), receiver, tokenAssets);
        onAfterWithdrawalChecks();

        emit Withdraw(caller, receiver, owner, baseAssets, shares);
        emit OnMetaWithdraw(receiver, token, tokenAssets, shares);
    }

    function requireSupportedVault(address token) internal view {
        address vaultAddress = assetsMap[token].asset;
        if (vaultAddress == address(0)) {
            revert UnsupportedAsset(token);
        }
    }
    function requireActiveVault(address token) internal view {
        requireSupportedVault(token);
        if (assetsMap[token].paused == true) {
            revert PausedAsset(token);
        }
    }


    /// @notice Adds an ERC4626 Vault to the list of supported vaults
    /// @dev Only the contract owner can call this function
    /// @param vaultAddress The address of the ERC4626 Vault to be added
    /// @custom:permissions onlyOwner
    function addVault(address vaultAddress) external onlyOwner {
        require(PreDepositPhase.PointsPhase == currentPhase, "POINTS_PHASE_ONLY");
        addVaultInner(vaultAddress);
    }

    function addVaultInner (address vaultAddress) internal {
        require(IERC20Metadata(vaultAddress).decimals() == IERC20Metadata(asset()).decimals(), "DECIMALS_MISMATCH");
        require(vaultAddress != asset(), "MAIN_ASSET");
        require(assetsMap[vaultAddress].asset == address(0), "DUPLICATE_ASSET");
        require(IERC4626(vaultAddress).asset() == asset(), "MAIN_ASSET_MISMATCH");

        TAsset memory vault = TAsset(vaultAddress, EAssetType.ERC4626, false);
        assetsMap[vaultAddress] = vault;
        assetsArr.push(vault);

        emit OnVaultAdded(vaultAddress);
    }

    /// @notice Removes an ERC4626 Vault from the list of supported vaults and redeems all balance
    /// @dev Only the contract owner can call this function. It redeems all balance from the vault for the underlying base asset before removal.
    /// @param vaultAddress The address of the ERC4626 Vault to be removed
    /// @custom:permissions onlyOwner
    function removeVault(address vaultAddress) external onlyOwner {
        require(PreDepositPhase.PointsPhase == currentPhase, "POINTS_PHASE_ONLY");
        requireSupportedVault(vaultAddress);
        removeVaultAndRedeemInner(vaultAddress);

        emit OnVaultRemoved(vaultAddress);
    }

    /// @notice Pauses or resumes a single vault during the points phase
    /// @dev This function allows the owner to temporarily disable or enable specific vaults
    ///      to mitigate potential issues with underlying vaults
    /// @param vaultAddress The address of the vault to pause or resume
    /// @param paused True to pause the vault, false to resume it
    /// @custom:permissions onlyOwner
    function setVaultPauseState(address vaultAddress, bool paused) external onlyOwner {
        require(PreDepositPhase.PointsPhase == currentPhase, "POINTS_PHASE_ONLY");
        requireSupportedVault(vaultAddress);
        assetsMap[vaultAddress].paused = paused;
        emit OnVaultPausedStateChanged(vaultAddress, paused);
    }

    function removeVaultAndRedeemInner (address vaultAddress) internal {
        // Redeem
        uint balance = IERC20(vaultAddress).balanceOf(address(this));
        if (balance > 0) {
            IERC4626(vaultAddress).redeem(balance, address(this), address(this));
        }

        // Clean
        TAsset memory emptyAsset;
        assetsMap[vaultAddress] = emptyAsset;
        uint length = assetsArr.length;
        for (uint i = 0; i < length; i++) {
            if (assetsArr[i].asset == vaultAddress) {
                assetsArr[i] = assetsArr[length - 1];
                assetsArr.pop();
                break;
            }
        }
    }

    /// @dev Internal method to redeem all assets from supported vaults
    /// @notice Iterates through all supported vaults and redeems their assets for the base token
    function redeemMetaVaults () internal {
        while (assetsArr.length > 0) {
            removeVaultAndRedeemInner(assetsArr[0].asset);
        }
    }

    /// @dev Internal method to redeem a specific amount of base tokens from supported vaults
    /// @notice Iterates through supported vaults and redeems assets until the required amount of base tokens is obtained.
    /// @param baseTokens The amount of base tokens to redeem
    function redeemRequiredBaseAssets (uint baseTokens) internal {
        uint baseTokensLeft = baseTokens;
        for (uint i = 0; i < assetsArr.length && baseTokensLeft > 0; i++) {
            IERC4626 vault = IERC4626(assetsArr[i].asset);
            uint totalBaseTokens = vault.maxWithdraw(address(this));
            if (totalBaseTokens == 0) {
                continue;
            }
            uint withdrawAmount = Math.min(baseTokensLeft, totalBaseTokens);
            // In at least one expected edge case: We ignore any withdrawal issues from the 3rd party vault and try the next one.
            try vault.withdraw(withdrawAmount, address(this), address(this)) {
                baseTokensLeft -= withdrawAmount;
            } catch {

            }
        }
    }
}

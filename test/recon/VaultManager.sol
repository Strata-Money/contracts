// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {BaseSetup} from "@chimera/BaseSetup.sol";
import {vm} from "@chimera/Hevm.sol";

import {EnumerableSet} from "setup-helpers/EnumerableSet.sol";
import {MockERC20} from "setup-helpers/MockERC20.sol";

import {MockUSDe} from "contracts/test/MockUSDe.sol";
import {MockStakedUSDe} from "contracts/test/MockStakedUSDe.sol";
import {MockERC4626Harness, IERC20} from "./harness/MockERC4626Harness.sol";

import {yUSDeVault, yUSDeVaultHarness} from "./harness/yUSDeVaultHarness.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

/// @dev Source of truth for the vaults being used in the test
/// @notice No vaults should be used in the suite without being added here first
abstract contract VaultManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    /// @notice The current vault target for this set of variables
    address private __vault;

    /// @notice The list of all vaults being used
    EnumerableSet.AddressSet private _vaults;

    /// @notice The current yUSDe vault target for this set of variables
    address private __yUSDeVault;

    /// @notice The list of all yUSDe vaults being used
    EnumerableSet.AddressSet private _yUSDeVaults;

    // If the current target is address(0) then it has not been setup yet and should revert
    error VaultNotSetup();
    // Do not allow duplicates
    error VaultExists();
    // Enable only added vaults
    error VaultNotAdded();

    /// @notice Returns the current active vault
    function _getVault() internal view returns (address) {
        if (__vault == address(0)) {
            revert VaultNotSetup();
        }

        return __vault;
    }

    /// @notice Returns all vaults being used
    function _getVaults() internal view returns (address[] memory) {
        return _vaults.values();
    }

    /// @notice Creates a new vault and adds it to the list of vaults
    /// @param asset The underlying asset of the vault
    /// @return The address of the new vault
    function _newVault(address asset) internal returns (address) {
        address vault_ = address(new MockERC4626Harness(IERC20(asset)));
        _addVault(vault_);
        __vault = vault_; // sets the vault as the current vault
        return vault_;
    }

    /// @notice Adds an vault to the list of vaults
    /// @param target The address of the vault to add
    function _addVault(address target) internal {
        if (_vaults.contains(target)) {
            revert VaultExists();
        }

        _vaults.add(target);
    }

    /// @notice Removes an vault from the list of vaults
    /// @param target The address of the vault to remove
    function _removeVault(address target) internal {
        if (!_vaults.contains(target)) {
            revert VaultNotAdded();
        }

        _vaults.remove(target);
    }

    /// @notice Switches the current vault based on the entropy
    /// @param entropy The entropy to choose a random vault in the array for switching
    function _switchVault(uint256 entropy) internal {
        address target = _vaults.at(entropy % _vaults.length());
        __vault = target;
    }

    /// @notice Returns the current active yUSDe vault
    function _getYUSDeVault() internal view returns (address) {
        if (__yUSDeVault == address(0)) {
            revert VaultNotSetup();
        }

        return __yUSDeVault;
    }

    /// @notice Returns all yUSDe vaults being used
    function _getYUSDeVaults() internal view returns (address[] memory) {
        return _yUSDeVaults.values();
    }

    /// @notice Creates a new yUSDe vault and adds it to the list of yUSDe vaults
    /// @return The address of the new yUSDe vault
    function _newYUSDeVault(address owner_, address USDe_, address sUSDe_, address pUSDe_) internal returns (address) {
        address yUSDeVault_ = address(
            new ERC1967Proxy(
                address(new yUSDeVaultHarness()),
                abi.encodeWithSelector(yUSDeVault.initialize.selector, owner_, USDe_, sUSDe_, pUSDe_)
            )
        );
        _addYUSDeVault(yUSDeVault_);
        __yUSDeVault = yUSDeVault_; // sets the yUSDe vault as the current yUSDe vault
        return yUSDeVault_;
    }

    /// @notice Adds a yUSDe vault to the list of yUSDe vaults
    /// @param target The address of the yUSDe vault to add
    function _addYUSDeVault(address target) internal {
        if (_yUSDeVaults.contains(target)) {
            revert VaultExists();
        }

        _yUSDeVaults.add(target);
    }

    /// @notice Removes a yUSDe vault from the list of yUSDe vaults
    /// @param target The address of the yUSDe vault to remove
    function _removeYUSDeVault(address target) internal {
        if (!_yUSDeVaults.contains(target)) {
            revert VaultNotAdded();
        }

        _yUSDeVaults.remove(target);
    }

    /// @notice Switches the current yUSDe vault based on the entropy
    /// @param entropy The entropy to choose a random yUSDe vault in the array for switching
    function _switchYUSDeVault(uint256 entropy) internal {
        address target = _yUSDeVaults.at(entropy % _yUSDeVaults.length());
        __yUSDeVault = target;
    }

    /// === Approve & Mint Vault === ///

    /// @notice Mint initial balance of underlying asset and approve allowances for the active vault
    /// @param actorsArray The array of actors to mint the vault asset to
    /// @param approvalArray The array of addresses to approve the vault asset to
    /// @param amount The amount of the vault asset to mint
    function _finalizeVaultDeployment(address[] memory actorsArray, address[] memory approvalArray, uint256 amount)
        internal
    {
        _mintVaultAssetToAllActors(actorsArray, amount);
        for (uint256 i; i < approvalArray.length; i++) {
            _approveVaultAssetToAddressForAllActors(actorsArray, approvalArray[i]);
        }
    }

    /// @notice Mint the vault asset to all actors
    /// @param actorsArray The array of actors to mint the vault asset to
    /// @param amount The amount of the vault to mint
    function _mintVaultAssetToAllActors(address[] memory actorsArray, uint256 amount) private {
        // mint all actors
        address vault = _getVault();
        for (uint256 i; i < actorsArray.length; i++) {
            vm.prank(actorsArray[i]);
            MockERC20(MockERC4626Harness(vault).asset()).mint(actorsArray[i], amount);
        }
    }

    /// @notice Approve the vault asset to all actors
    /// @param actorsArray The array of actors to approve the vault asset from
    /// @param addressToApprove The address to approve the vault asset to
    function _approveVaultAssetToAddressForAllActors(address[] memory actorsArray, address addressToApprove) private {
        // approve to all actors
        address vault = _getVault();
        for (uint256 i; i < actorsArray.length; i++) {
            vm.prank(actorsArray[i]);
            MockERC20(MockERC4626Harness(vault).asset()).approve(addressToApprove, type(uint256).max);
        }
    }
}

// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {Setup} from "./Setup.sol";
import {PreDepositPhase} from "contracts/interfaces/IPhase.sol";
import {IERC20} from "./harness/MockERC4626Harness.sol";

// ghost variables for tracking state variable values before and after function calls
abstract contract BeforeAfter is Setup {
    enum OpType {
        GENERIC,
        ADD,
        REMOVE
    }

    struct Vars {
        // pUSDe variables
        PreDepositPhase pUSDe_currentPhase;
        bool pUSDe_depositsEnabled;
        bool pUSDe_withdrawalsEnabled;
        address pUSDe_yUSDeVault;
        uint256 pUSDe_depositedBase;
        uint256 pUSDe_pricePerShare;
        uint256 pUSDe_totalSupply;
        uint256 pUSDe_totalSupplyGhost;
        uint256 pUSDe_balanceOfUSDe;
        uint256 pUSDe_balanceOfSUSDe;
        mapping(address => uint256) pUSDe_assetBalances;
        mapping(address => bool) pUSDe_assetSupported;
        address[] pUSDe_assets;
        // yUSDe variables
        PreDepositPhase yUSDe_currentPhase;
        bool yUSDe_depositsEnabled;
        bool yUSDe_withdrawalsEnabled;
        uint256 yUSDe_pricePerShare;
        uint256 yUSDe_totalSupply;
        uint256 yUSDe_totalSupplyGhost;
        uint256 yUSDe_balanceOfPUSDe;
    }

    Vars internal _before;
    Vars internal _after;

    OpType currentOperation;

    /// @dev For each actor, how many "USDe-equivalents" they have ever deposited into pUSDe (over the entire run).
    ///      Whenever an actor calls any OpType.ADD function on pUSDe, we will interpret the
    ///      “USDe-equivalent” via the ERC4626 preview functions and add it here.
    mapping(address => uint256) public pUSDe_totalDepositedUSDe;

    /// @dev For each actor, how many "USDe-equivalents" they have ever withdrawn from pUSDe.
    ///      Whenever an actor calls any OpType.REMOVE function on pUSDe in either phase, we compute the "USDe-equivalent” they end up receiving.
    ///      During the points phase that is USDe and during the yield phase that is sUSDe → USDe equivalent.
    mapping(address => uint256) public pUSDe_totalWithdrawnUSDe;

    /// @dev For each actor, how many "USDe-equivalents" they have ever contributed into yUSDe.
    ///      Whenever an actor calls any OpType.ADD function on yUSDe, we compute the "USDe-equivalent" via pUSDe.previewRedeem().
    mapping(address => uint256) public yUSDe_totalDepositedUSDe;

    /// @dev For each actor, how many "USDe-equivalents" they have ever redeemed from yUSDe.
    ///      Whenever an actor calls any OpType.REMOVE function on yUSDe, we compute the "USDe-equivalent" they end up receiving.
    ///      That is sUSDe → USDe equivalent.
    mapping(address => uint256) public yUSDe_totalWithdrawnUSDe;

    modifier updateGhostsWithType(OpType op) {
        currentOperation = op;
        __before();
        _;
        __after();
    }

    modifier updateGhosts() {
        currentOperation = OpType.GENERIC;
        __before();
        _;
        __after();
    }

    function __before() internal {
        // pUSDe variables
        _before.pUSDe_currentPhase = pUSDe.currentPhase();
        _before.pUSDe_depositsEnabled = pUSDe.depositsEnabled();
        _before.pUSDe_withdrawalsEnabled = pUSDe.withdrawalsEnabled();
        _before.pUSDe_yUSDeVault = address(pUSDe.yUSDe());
        _before.pUSDe_depositedBase = pUSDe.depositedBase();
        _before.pUSDe_pricePerShare = pUSDe.previewMint(10 ** pUSDe.decimals());
        _before.pUSDe_totalSupply = pUSDe.totalSupply();
        _before.pUSDe_balanceOfUSDe = USDe.balanceOf(address(pUSDe));
        _before.pUSDe_balanceOfSUSDe = sUSDe.balanceOf(address(pUSDe));
        _before.pUSDe_assets = pUSDe.getAssets();

        // shared total supply ghosts
        address[] memory actors = _getActors();
        uint256 pUSDe_totalSupplyGhostBefore;
        uint256 yUSDe_totalSupplyGhostBefore;

        for (uint256 i; i < actors.length; i++) {
            address actor = actors[i];
            pUSDe_totalSupplyGhostBefore += pUSDe.balanceOf(actor);
            yUSDe_totalSupplyGhostBefore += yUSDe.balanceOf(actor);
        }

        _before.pUSDe_totalSupplyGhost = pUSDe_totalSupplyGhostBefore;
        _before.yUSDe_totalSupplyGhost = yUSDe_totalSupplyGhostBefore;

        // yUSDe variables
        _before.yUSDe_currentPhase = yUSDe.currentPhase();
        _before.yUSDe_depositsEnabled = yUSDe.depositsEnabled();
        _before.yUSDe_withdrawalsEnabled = yUSDe.withdrawalsEnabled();
        // NOTE: This can revert, which is not desirable as it will cause all operations in the call sequence to be undone.
        // This can happen when either vault is fully redeemed and totalAssets() is zero, although this should not happen in practice.
        // To avoid this, we catch the revert and leave the price per share unchanged.
        try yUSDe.previewMint(10 ** yUSDe.decimals()) returns (uint256 price) {
            _before.yUSDe_pricePerShare = price;
        } catch {}
        _before.yUSDe_totalSupply = yUSDe.totalSupply();
        _before.yUSDe_balanceOfPUSDe = pUSDe.balanceOf(address(yUSDe));
    }

    function __after() internal {
        // pUSDe variables
        _after.pUSDe_currentPhase = pUSDe.currentPhase();
        _after.pUSDe_depositsEnabled = pUSDe.depositsEnabled();
        _after.pUSDe_withdrawalsEnabled = pUSDe.withdrawalsEnabled();
        _after.pUSDe_yUSDeVault = address(pUSDe.yUSDe());
        _after.pUSDe_depositedBase = pUSDe.depositedBase();
        _after.pUSDe_pricePerShare = pUSDe.previewMint(10 ** pUSDe.decimals());
        _after.pUSDe_totalSupply = pUSDe.totalSupply();
        _after.pUSDe_balanceOfUSDe = USDe.balanceOf(address(pUSDe));
        _after.pUSDe_balanceOfSUSDe = sUSDe.balanceOf(address(pUSDe));
        _after.pUSDe_assets = pUSDe.getAssets();

        // shared total supply ghosts
        address[] memory actors = _getActors();
        uint256 pUSDe_totalSupplyGhostAfter;
        uint256 yUSDe_totalSupplyGhostAfter;

        for (uint256 i; i < actors.length; i++) {
            address actor = actors[i];
            pUSDe_totalSupplyGhostAfter += pUSDe.balanceOf(actor);
            yUSDe_totalSupplyGhostAfter += yUSDe.balanceOf(actor);
        }

        _before.pUSDe_totalSupplyGhost = pUSDe_totalSupplyGhostAfter;
        _before.yUSDe_totalSupplyGhost = yUSDe_totalSupplyGhostAfter;

        // yUSDe variables
        _after.yUSDe_currentPhase = yUSDe.currentPhase();
        _after.yUSDe_depositsEnabled = yUSDe.depositsEnabled();
        _after.yUSDe_withdrawalsEnabled = yUSDe.withdrawalsEnabled();
        // NOTE: This can revert, which is not desirable as it will cause all operations in the call sequence to be undone.
        // This can happen when either vault is fully redeemed and totalAssets() is zero, although this should not happen in practice.
        // To avoid this, we catch the revert and leave the price per share unchanged.
        try yUSDe.previewMint(10 ** yUSDe.decimals()) returns (uint256 price) {
            _after.yUSDe_pricePerShare = price;
        } catch {
            _after.yUSDe_pricePerShare = _before.yUSDe_pricePerShare;
        }
        _after.yUSDe_totalSupply = yUSDe.totalSupply();
        _after.yUSDe_balanceOfPUSDe = pUSDe.balanceOf(address(yUSDe));
    }

    function __before(address vault) internal {
        _before.pUSDe_assetSupported[vault] = pUSDe.isAssetSupported(vault);
        _before.pUSDe_assetBalances[vault] = IERC20(vault).balanceOf(address(pUSDe));

        __before();
    }

    function __after(address vault) internal {
        _after.pUSDe_assetSupported[vault] = pUSDe.isAssetSupported(vault);
        _after.pUSDe_assetBalances[vault] = IERC20(vault).balanceOf(address(pUSDe));

        __after();
    }
}

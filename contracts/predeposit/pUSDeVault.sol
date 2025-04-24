// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {PreDepositVault} from "./PreDepositVault.sol";
import {IERC4626Yield} from "../interfaces/IERC4626Yield.sol";


import "hardhat/console.sol";

contract pUSDeVault is IERC4626Yield, PreDepositVault {

    uint256 public depositedUSDe;

    IERC4626 public yUSDe;


    event YUSDeVaultUpdated(address yUSDeAddress);

    function initialize(
        address owner_
        , IERC20 USDe_
        , IERC4626 sUSDe_
    ) external virtual initializer {
        super.initialize(
            owner_,
            "PreDeposit Strata Points USDe",
            "pUSDe",
            USDe_,
            sUSDe_,
            sUSDe_
        );
    }


    /**
     * @dev All share calculations for minting, depositing, redeeming, and withdrawing are based on the staked USDe amount.
     * This allows us to retain the extra yield received from increasing sUSDe underlying holdings.
     */
    function totalAssets() public view override returns (uint256) {
        return  sUSDe.previewWithdraw(depositedUSDe);
    }

    function totalUSDe() external view returns (uint256) {
        return totalUSDeInner();
    }

    function totalUSDeInner() internal view returns (uint256) {
        uint total_sUSDe = sUSDe.balanceOf(address(this));
        uint total_USDe = sUSDe.previewRedeem(total_sUSDe);

        return total_USDe;
    }

    function previewDeposit(uint256 sUSDeAssets) public view override  returns (uint256) {
        uint USDeAssets = sUSDe.previewRedeem(sUSDeAssets);
        return _convertToShares(USDeAssets, Math.Rounding.Floor);
    }

    // returns yield in sUSDe
    function previewYield(address caller, uint256 shares) public view virtual returns (uint256) {
        if (caller == address(yUSDe)) {
            uint total_sUSDe = sUSDe.balanceOf(address(this));
            // Math.min: Normally, total_USDe should exceed depositedUSDe due to yield.
            // However, in rare cases (e.g., negative APY), we adjust depositedUSDe to match total_USDe.
            uint total_yield_sUSDe = total_sUSDe - Math.min(total_sUSDe, totalAssets());

            uint y_pUSDeShares = balanceOf(caller);
            uint caller_yield_sUSDe = total_yield_sUSDe * shares / y_pUSDeShares;
            return caller_yield_sUSDe;
        }
        return 0;
    }

    // returns redeem in sUSDe
    function previewRedeem(address caller, uint256 shares) public view virtual returns (uint256) {
        return previewRedeem(shares) + previewYield(caller, shares);
    }

    function _deposit(address caller, address receiver, uint256 sUSDAssets, uint256 shares) internal override {
        if (!depositsEnabled) {
            revert DepositsDisabled();
        }

        uint amountUSDe = sUSDe.previewRedeem(sUSDAssets);
        depositedUSDe += amountUSDe;

        return super._deposit(caller, receiver, sUSDAssets, shares);
    }

    /**
     * @dev Internal function to handle withdrawals of sUSDe
     * @notice Shares and totalAssets are directly bound to USDe, so 'assets' represents the USDe amount
     * @param caller Address initiating the withdrawal
     * @param receiver Address receiving the withdrawn sUSDe
     * @param owner Address that owns the shares being burned
     * @param sUSDeAssets Amount of sUSDe to withdraw
     * @param shares Amount of shares to burn
     */
    function _withdraw(address caller, address receiver, address owner, uint256 sUSDeAssets, uint256 shares)
        internal
        override
    {
        if (!withdrawalsEnabled) {
            revert WithdrawalsDisabled();
        }

        // sUSDeAssets = sUSDeAssets + user_yield_sUSDe
        sUSDeAssets += previewYield(caller, shares);

        uint256 USDeAssets = sUSDe.previewRedeem(sUSDeAssets);

        require(USDeAssets <= depositedUSDe, "Withdrawal amount exceeds available assets");

        depositedUSDe -= USDeAssets;
        super._withdraw(caller, receiver, owner, sUSDeAssets, shares);
    }

    function updateYUSDeVault(address yUSDeAddress) external onlyOwner {
        yUSDe = IERC4626(yUSDeAddress);
        emit YUSDeVaultUpdated(yUSDeAddress);
    }
}

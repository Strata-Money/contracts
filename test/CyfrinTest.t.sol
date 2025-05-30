pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {MockUSDe} from "../contracts/test/MockUSDe.sol";
import {MockStakedUSDe} from "../contracts/test/MockStakedUSDe.sol";
import {MockERC4626} from "../contracts/test/MockERC4626.sol";
import {pUSDeVault} from "../contracts/predeposit/pUSDeVault.sol";
import {pUSDeDepositor as pUSDeDepositorHelper} from "../contracts/predeposit/pUSDeDepositor.sol";

import {console2} from "forge-std/console2.sol";

contract CyfrinTest is Test {

    // USDe = Ethena Synthetic USD Token https://etherscan.io/address/0x4c9EDD5852cd905f086C759E8383e09bff1E68B3#code
    MockUSDe public USDe; 

    // sUSDe = yield-bearing equivalent of USDe, staked into an ERC-4626 vault https://etherscan.io/token/0x9d39a5de30e57443bff2a8307a4256c8797a3497#code
    MockStakedUSDe public sUSDe;

    // an additionally supported ERC4626 asset for the MetaVault
    MockERC4626 public eUSDe;

    // pUSDe = Vault share tokens minted to depositors of USDe or other supported vault tokens to the points MetaVault
    pUSDeVault public pUSDe;

    // pUSDeDepositor = helper contract for depositing into `pUSDe`
    pUSDeDepositorHelper public pUSDeDepositor;

    // users used in tests
    address user1 = makeAddr("user1");
    address user2 = makeAddr("user2");

    function setUp() public {
        // Prepare Ethena and Ethreal contracts
        USDe = new MockUSDe();
        sUSDe = new MockStakedUSDe(USDe, address(this), address(this));
        eUSDe = new MockERC4626(USDe);

        // Prepare pUSDe and Depositor contracts
        pUSDe = pUSDeVault(address(new ERC1967Proxy(address(new pUSDeVault()), abi.encodeWithSelector(
            pUSDeVault.initialize.selector,
            address(this),
            USDe,
            sUSDe
        ))));
        // USDe is the underlying asset of pUSDe ERC4626 vault
        assertEq(pUSDe.asset(), address(USDe));

        pUSDeDepositor = pUSDeDepositorHelper(address(new ERC1967Proxy(address(new pUSDeDepositorHelper()), abi.encodeWithSelector(
            pUSDeDepositorHelper.initialize.selector,
            address(this),
            USDe,
            sUSDe,
            pUSDe
        ))));

        pUSDe.setDepositsEnabled(true);
        pUSDe.setWithdrawalsEnabled(true);

        // adds an additional supported ERC4626 asset for the MetaVault
        pUSDe.addVault(address(eUSDe));
    }

    // *** START - tests & functions created by Cyfrin *** //
    function test_firstDepositExploit_AttackerNotProfitable(
        uint128 userDeposit, uint128 attackerDeposit, uint128 attackerDirectTransfer
    ) external {
        userDeposit = uint128(bound(userDeposit, 1e18, type(uint128).max));
        attackerDeposit = uint128(bound(attackerDeposit, 1e18, type(uint128).max));
        attackerDirectTransfer = uint128(bound(attackerDirectTransfer, 1e18, type(uint128).max));

        uint256 attackerTotalCost = uint256(attackerDeposit)+attackerDirectTransfer;
        address innocentUser = makeAddr("innocentUser");
        address attacker = makeAddr("attacker");

        // fund users
        USDe.mint(innocentUser, userDeposit);
        USDe.mint(attacker, attackerDeposit);
        
        // attacker front-runs first deposit by innocent user to:
        // 1) make an initial deposit
        vm.startPrank(attacker);
        USDe.approve(address(pUSDeDepositor), attackerDeposit);
        pUSDeDepositor.deposit(USDe, attackerDeposit, attacker);
        // 2) transfer a large amount of asset tokens directly into the vault
        USDe.mint(attacker, attackerDirectTransfer);
        USDe.transfer(address(pUSDe), attackerDirectTransfer);
        vm.stopPrank();

        // 3) innocent user's deposit then goes through
        vm.startPrank(innocentUser);
        USDe.approve(address(pUSDeDepositor), userDeposit);
        pUSDeDepositor.deposit(USDe, userDeposit, innocentUser);
        vm.stopPrank();
        uint128 innocentVaultShares = uint128(pUSDe.balanceOf(innocentUser));
        assertNotEq(innocentVaultShares, 0, "Innocent users received shares > 0 for deposit");

        // 4) attacker redeems their shares
        vm.startPrank(attacker);
        uint128 attackerVaultShares = uint128(pUSDe.balanceOf(attacker));
        pUSDe.redeem(attackerVaultShares, attacker, attacker);
        assertEq(pUSDe.balanceOf(attacker), 0, "Attacker redeemed all vault shares");
        assertGt(USDe.balanceOf(attacker), 0, "Attacker received some tokens after redeeming");
        vm.stopPrank();

        // verify attacker did not make a profit
        assertGt(attackerTotalCost,
                 USDe.balanceOf(attacker),
                 "Attacker did not make a profit");

        // 5) innocent user tries to redeem; can't redeem due to MinSharesViolation
        // can revert with PreDepositVault.MinSharesViolation.selector, comment out
        // the try/catch to see this
        vm.startPrank(innocentUser);
        try pUSDe.redeem(innocentVaultShares, innocentUser, innocentUser) {
            assertEq(pUSDe.balanceOf(innocentUser), 0, "Innocent user redeemed all vault shares");
            assertGt(USDe.balanceOf(innocentUser), 0, "Innocent user received some tokens after redeeming");

            // verify attacker lost more than the innocent user
            uint256 attackerLoss = attackerTotalCost - USDe.balanceOf(attacker);
            uint256 innocentUserLoss = userDeposit - USDe.balanceOf(innocentUser);
            assertGt(attackerLoss, innocentUserLoss, "Attacker lost more than innocent user");
        }
        catch {
            // if it reverted, do the same verification but using what the expected redemption would provide
            uint256 attackerLoss = attackerTotalCost - USDe.balanceOf(attacker);
            uint256 innocentUserLoss = userDeposit - pUSDe.previewRedeem(innocentVaultShares);
            assertGt(attackerLoss, innocentUserLoss, "Attacker lost more than innocent user");
        }
        vm.stopPrank();
    }

    function test_yieldPhase_supportedVaults_userCantWithdrawVaultAssets() external {
        // user1 deposits $1000 USDe into the main vault
        uint256 user1AmountInMainVault = 1000e18;
        USDe.mint(user1, user1AmountInMainVault);

        vm.startPrank(user1);
        USDe.approve(address(pUSDe), user1AmountInMainVault);
        uint256 user1MainVaultShares = pUSDe.deposit(user1AmountInMainVault, user1);
        vm.stopPrank();

        assertEq(pUSDe.totalAssets(), user1AmountInMainVault);
        assertEq(pUSDe.balanceOf(user1), user1MainVaultShares);

        // admin triggers yield phase on main vault which stakes all vault's USDe
        pUSDe.startYieldPhase();
        // totalAssets() still returns same amount as it is overridden in pUSDeVault
        assertEq(pUSDe.totalAssets(), user1AmountInMainVault);
        // balanceOf shows pUSDeVault has deposited its USDe in sUSDe
        assertEq(USDe.balanceOf(address(pUSDe)), 0);
        assertEq(USDe.balanceOf(address(sUSDe)), user1AmountInMainVault);

        // create an additional supported ERC4626 vault
        MockERC4626 newSupportedVault = new MockERC4626(USDe);
        pUSDe.addVault(address(newSupportedVault));
        // add eUSDe again since `startYieldPhase` removes it
        pUSDe.addVault(address(eUSDe));

        // verify two additional vaults now suppported
        assertTrue(pUSDe.isAssetSupported(address(eUSDe)));
        assertTrue(pUSDe.isAssetSupported(address(newSupportedVault)));
        
        // user2 deposits $600 into each vault
        uint256 user2AmountInEachSubVault = 600e18;
        USDe.mint(user2, user2AmountInEachSubVault*2);
        
        vm.startPrank(user2);
        USDe.approve(address(eUSDe), user2AmountInEachSubVault);
        uint256 user2SubVaultSharesInEach = eUSDe.deposit(user2AmountInEachSubVault, user2);
        USDe.approve(address(newSupportedVault), user2AmountInEachSubVault);
        newSupportedVault.deposit(user2AmountInEachSubVault, user2);
        vm.stopPrank();

        // verify balances correct
        assertEq(eUSDe.totalAssets(), user2AmountInEachSubVault);
        assertEq(newSupportedVault.totalAssets(), user2AmountInEachSubVault);

        // user2 deposits using their shares via MetaVault::deposit
        vm.startPrank(user2);
        eUSDe.approve(address(pUSDe), user2SubVaultSharesInEach);
        pUSDe.deposit(address(eUSDe), user2SubVaultSharesInEach, user2);
        newSupportedVault.approve(address(pUSDe), user2SubVaultSharesInEach);
        pUSDe.deposit(address(newSupportedVault), user2SubVaultSharesInEach, user2);
        vm.stopPrank();

        // verify main vault total assets includes everything
        assertEq(pUSDe.totalAssets(), user1AmountInMainVault + user2AmountInEachSubVault*2);
        // main vault not carrying any USDe balance
        assertEq(USDe.balanceOf(address(pUSDe)), 0);
        // user2 lost their subvault shares
        assertEq(eUSDe.balanceOf(user2), 0);
        assertEq(newSupportedVault.balanceOf(user2), 0);
        // main vault gained the subvault shares
        assertEq(eUSDe.balanceOf(address(pUSDe)), user2SubVaultSharesInEach);
        assertEq(newSupportedVault.balanceOf(address(pUSDe)), user2SubVaultSharesInEach);

        // verify user2 entitled to withdraw their total token amount
        assertEq(pUSDe.maxWithdraw(user2), user2AmountInEachSubVault*2);

        // try and do it, reverts due to insufficient balance
        vm.startPrank(user2);
        vm.expectRevert(); // ERC20InsufficientBalance
        pUSDe.withdraw(user2AmountInEachSubVault*2, user2, user2);

        // try 1 wei more than largest deposit from user 1, fails for same reason
        vm.expectRevert(); // ERC20InsufficientBalance
        pUSDe.withdraw(user1AmountInMainVault+1, user2, user2);

        // can withdraw up to max deposit amount $1000
        pUSDe.withdraw(user1AmountInMainVault, user2, user2);

        // user2 still has $200 left to withdraw
        assertEq(pUSDe.maxWithdraw(user2), 200e18);

        // trying to withdraw it reverts
        vm.expectRevert(); // ERC20InsufficientBalance
        pUSDe.withdraw(200e18, user2, user2);

        // can't withdraw anymore, even trying 1 wei will revert
        vm.expectRevert();
        pUSDe.withdraw(1e18, user2, user2);
    }

    function test_deposit_SUSDe_inYieldPhase() external {
        // user1 deposits $1000 USDe into the main vault
        uint256 user1AmountInMainVault = 1000e18;
        USDe.mint(user1, user1AmountInMainVault);

        vm.startPrank(user1);
        USDe.approve(address(pUSDe), user1AmountInMainVault);
        uint256 user1MainVaultShares = pUSDe.deposit(user1AmountInMainVault, user1);
        vm.stopPrank();

        // admin triggers yield phase on main vault
        pUSDe.startYieldPhase();
        // totalAssets() still returns same amount as it is overridden in pUSDeVault
        assertEq(pUSDe.totalAssets(), user1AmountInMainVault);
        // balanceOf shows pUSDeVault has deposited its USDe in sUSDe
        assertEq(USDe.balanceOf(address(pUSDe)), 0);
        assertEq(USDe.balanceOf(address(sUSDe)), user1AmountInMainVault);
        // vault has shares in sUSDe; these shares are the same
        // as user1's deposit since that deposit is the total vault's tokens
        uint256 vaultsUSDeShares = sUSDe.balanceOf(address(pUSDe));
        assertEq(vaultsUSDeShares, user1MainVaultShares);

        // user2 deposits $500 USDe into sUSDe
        uint256 user2AmountInsUSDe = 500e18;
        USDe.mint(user2, user2AmountInsUSDe);

        vm.startPrank(user2);
        USDe.approve(address(sUSDe), user2AmountInsUSDe);
        uint256 user2sUSDeVaultShares = sUSDe.deposit(user2AmountInsUSDe, user2);
        assertGt(user2sUSDeVaultShares, 0);
        vm.stopPrank();

        // main vault stats remain unchanged
        assertEq(pUSDe.totalAssets(), user1AmountInMainVault);
        assertEq(sUSDe.balanceOf(address(pUSDe)), vaultsUSDeShares);

        // sUSDe underlying tokens increased by user2 deposit
        assertEq(USDe.balanceOf(address(sUSDe)), user1AmountInMainVault + user2AmountInsUSDe);

        // now user2 deposits their sUSDe shares into pUSDe main vault
        vm.startPrank(user2);
        sUSDe.approve(address(pUSDe), user2sUSDeVaultShares);
        pUSDe.deposit(address(sUSDe), user2sUSDeVaultShares, user2);
        vm.stopPrank();

        // main vault total assets increased by user2's deposit into sUSDe
        assertEq(pUSDe.totalAssets(), user1AmountInMainVault + user2AmountInsUSDe);
        // sUSDe underlying tokens remains the same
        assertEq(USDe.balanceOf(address(sUSDe)), user1AmountInMainVault + user2AmountInsUSDe);

        // main vault sUSDe shares increased by user2 shares
        assertEq(sUSDe.balanceOf(address(pUSDe)), vaultsUSDeShares + user2sUSDeVaultShares);
        // user2 lost sUSDe shares
        assertEq(sUSDe.balanceOf(user2), 0);

        // user1 withdraws
        vm.prank(user1);
        pUSDe.withdraw(user1MainVaultShares, user1, user1);

        // only user2's token remain as vault assets
        assertEq(pUSDe.totalAssets(), user2AmountInsUSDe);

        // during withdraw phase, withdrawing users get sUSDe shares not tokens
        assertEq(USDe.balanceOf(user1), 0);
        assertEq(sUSDe.balanceOf(user1), user1MainVaultShares);

        // user1 then attempts to get their tokens via `cooldownShares`
        vm.prank(user1);
        sUSDe.cooldownShares(user1MainVaultShares);

        // user1 didn't receive any tokens, but this reset their shares
        assertEq(USDe.balanceOf(user1), 0);
        assertEq(sUSDe.balanceOf(user1), 0);

        // now wait cooldown duration then get tokens via `unstake`
        vm.warp(block.timestamp + 7 days);
        vm.prank(user1);
        sUSDe.unstake(user1);

        assertEq(USDe.balanceOf(user1), user1AmountInMainVault);
    }

    function test_yieldRedemption() public {
        // user1 deposits $1000 USDe into the main vault
        uint256 user1AmountInMainVault = 1000e18;
        USDe.mint(user1, user1AmountInMainVault);

        vm.startPrank(user1);
        USDe.approve(address(pUSDe), user1AmountInMainVault);
        uint256 user1MainVaultShares = pUSDe.deposit(user1AmountInMainVault, user1);
        // user shares will equal deposited amount
        assertEq(user1MainVaultShares, user1AmountInMainVault);
        vm.stopPrank();
        
        // admin triggers yield phase on main vault
        pUSDe.startYieldPhase();
        // totalAssets() still returns same amount as it is overridden in pUSDeVault
        assertEq(pUSDe.totalAssets(), user1AmountInMainVault);
        // balanceOf shows pUSDeVault has deposited its USDe in sUSDe
        assertEq(USDe.balanceOf(address(pUSDe)), 0);
        assertEq(USDe.balanceOf(address(sUSDe)), user1AmountInMainVault);
        // vault has shares in sUSDe; these shares are the same
        // as user1's deposit since that deposit is the total vault's tokens
        uint256 vaultsUSDeShares = sUSDe.balanceOf(address(pUSDe));
        assertEq(vaultsUSDeShares, user1MainVaultShares);
        // verify user1 still has their main vault shares
        assertEq(pUSDe.balanceOf(user1), user1MainVaultShares);


        // simulate sUSDe yield transfer
        USDe.mint(address(this), 1 ether);
        USDe.approve(address(sUSDe), 1 ether);
        sUSDe.transferInRewards(1 ether);
        skip(8 hours);

        uint256 maxRedeem = pUSDe.maxRedeem(user1);        
        uint256 snap = vm.snapshot();

        // max redeem (less min shares) of pUSDe by account to sUSDe is successful
        vm.startPrank(user1);
        pUSDe.redeem(address(sUSDe), maxRedeem - 0.1 ether, user1, user1);
        vm.stopPrank();
        assertEq(pUSDe.balanceOf(user1), 0.1 ether, "pUSDe balance of account after redeem should be min shares");
        
        vm.revertTo(snap);
        
        vm.startPrank(user1);
        pUSDe.redeem(address(USDe), maxRedeem - 0.1 ether, user1, user1);
        assertEq(pUSDe.balanceOf(user1), 0.1 ether, "pUSDe balance of account after redeem should be min shares");
    }


    function test_mint_viaSupportingVault(uint256 amount) external {
        amount = bound(amount, 1, type(uint128).max);

        // user1 deposits into supporting vault
        USDe.mint(user1, amount);
        
        vm.startPrank(user1);
        USDe.approve(address(eUSDe), amount);
        uint256 user1SubVaultShares = eUSDe.deposit(amount, user1);
        vm.stopPrank();

        // verify balances correct
        assertEq(eUSDe.totalAssets(), amount);
        assertEq(eUSDe.balanceOf(user1), user1SubVaultShares);

        // user1 now uses `MetaVault::mint` for the supported vault
        vm.startPrank(user1);
        eUSDe.approve(address(pUSDe), user1SubVaultShares);
        pUSDe.mint(address(eUSDe), user1SubVaultShares, user1);
        vm.stopPrank();

        // verify balances correct
        assertEq(eUSDe.totalAssets(), amount);
        assertEq(eUSDe.balanceOf(user1), 0);
        assertEq(eUSDe.balanceOf(address(pUSDe)), user1SubVaultShares);
        assertEq(pUSDe.totalAssets(), user1SubVaultShares);
    }


    function test_maxWithdraw_WhenWithdrawalsPaused() external {
        // user1 deposits $1000 USDe into the main vault
        uint256 user1AmountInMainVault = 1000e18;
        USDe.mint(user1, user1AmountInMainVault);

        vm.startPrank(user1);
        USDe.approve(address(pUSDe), user1AmountInMainVault);
        uint256 user1MainVaultShares = pUSDe.deposit(user1AmountInMainVault, user1);
        vm.stopPrank();

        // admin pauses withdrawals
        pUSDe.setWithdrawalsEnabled(false);

        // reverts as maxWithdraw returns user1AmountInMainVault even though
        // attempting to withdraw would revert
        assertEq(pUSDe.maxWithdraw(user1), 0);

        // https://eips.ethereum.org/EIPS/eip-4626 maxWithdraw says:
        // MUST factor in both global and user-specific limits,
        // like if withdrawals are entirely disabled (even temporarily) it MUST return 0
    }

    function test_maxRedeem_WhenWithdrawalsPaused() external {
        // user1 deposits $1000 USDe into the main vault
        uint256 user1AmountInMainVault = 1000e18;
        USDe.mint(user1, user1AmountInMainVault);

        vm.startPrank(user1);
        USDe.approve(address(pUSDe), user1AmountInMainVault);
        uint256 user1MainVaultShares = pUSDe.deposit(user1AmountInMainVault, user1);
        vm.stopPrank();

        // admin pauses withdrawals
        pUSDe.setWithdrawalsEnabled(false);

        // doesn't revert but it should since `MetaVault::redeem` uses `_withdraw`
        // and withdraws are paused, so `maxRedeem` should return 0
        assertEq(pUSDe.maxRedeem(user1), user1AmountInMainVault);

        // reverts with WithdrawalsDisabled
        vm.prank(user1);
        pUSDe.redeem(user1MainVaultShares, user1, user1);

        // https://eips.ethereum.org/EIPS/eip-4626 maxRedeem says:
        // MUST factor in both global and user-specific limits,
        // like if redemption are entirely disabled (even temporarily) it MUST return 0
    }

    function test_maxDeposit_WhenDepositsPaused() external {
        // admin pauses deposists
        pUSDe.setDepositsEnabled(false);

        // reverts as maxDeposit returns uint256.max even though
        // attempting to deposit would revert
        assertEq(pUSDe.maxDeposit(user1), 0);

        // https://eips.ethereum.org/EIPS/eip-4626 maxDeposit says:
        // MUST factor in both global and user-specific limits,
        // like if deposits are entirely disabled (even temporarily) it MUST return 0.
    }

    function test_maxMint_WhenDepositsPaused() external {
        // admin pauses deposists
        pUSDe.setDepositsEnabled(false);

        // should revert here as maxMint should return 0
        // since deposits are paused and `MetaVault::mint` uses `_deposit`
        assertEq(pUSDe.maxMint(user1), type(uint256).max);

        // attempt to mint to show the error
        uint256 user1AmountInMainVault = 1000e18;
        USDe.mint(user1, user1AmountInMainVault);

        vm.startPrank(user1);
        USDe.approve(address(pUSDe), user1AmountInMainVault);
        // reverts with DepositsDisabled since `MetaVault::mint` uses `_deposit`
        uint256 user1MainVaultShares = pUSDe.mint(user1AmountInMainVault, user1);
        vm.stopPrank();

        // https://eips.ethereum.org/EIPS/eip-4626 maxMint says:
        // MUST factor in both global and user-specific limits,
        // like if mints are entirely disabled (even temporarily) it MUST return 0.
    }

    function test_supportedVaultsRemovedWhenYieldPhaseEnabled() external {
        // supported vault prior to yield phase
        assertTrue(pUSDe.isAssetSupported(address(eUSDe)));

        // user1 deposits $1000 USDe into the main vault
        uint256 user1AmountInMainVault = 1000e18;
        USDe.mint(user1, user1AmountInMainVault);

        vm.startPrank(user1);
        USDe.approve(address(pUSDe), user1AmountInMainVault);
        uint256 user1MainVaultShares = pUSDe.deposit(user1AmountInMainVault, user1);
        vm.stopPrank();

        // admin triggers yield phase on main vault
        pUSDe.startYieldPhase();

        // supported vault was removed when initiating yield phase
        assertFalse(pUSDe.isAssetSupported(address(eUSDe)));

        // but can be added back in?
        pUSDe.addVault(address(eUSDe));
        assertTrue(pUSDe.isAssetSupported(address(eUSDe)));

        // what was the point of removing it if it can be re-added
        // and used again during the yield phase?
    }

    function test_vaultSupportedWithDifferentUnderlyingAsset() external {
        // create ERC4626 vault with different underlying ERC20 asset
        MockUSDe differentERC20 = new MockUSDe(); 
        MockERC4626 newSupportedVault = new MockERC4626(differentERC20);

        // verify pUSDe doesn't have same underlying asset as new vault
        assertNotEq(pUSDe.asset(), newSupportedVault.asset());

        // but still allows it to be added
        pUSDe.addVault(address(newSupportedVault));

        // this breaks `MetaVault::redeemRequiredBaseAssets` since
        // the newly supported vault doesn't have the same base asset
    }

    // *** END - tests & functions created by Cyfrin *** //

}

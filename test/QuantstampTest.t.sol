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

contract QuantstampTest is Test {

    MockUSDe public USDe;
    MockERC4626 public eUSDe;
    MockStakedUSDe public sUSDe;
    pUSDeVault public pUSDe;

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

        pUSDe.setDepositsEnabled(true);
        pUSDe.setWithdrawalsEnabled(true);

        // adds an additional supported ERC4626 asset for the MetaVault
        pUSDe.addVault(address(eUSDe));
    }

    function test_failOnDepositPausedMetaVault() external {
        address user = makeAddr("user");

        uint128 userDeposit = 10 ether;
        USDe.mint(user, userDeposit);


        vm.startPrank(user);
        USDe.approve(address(pUSDe), type(uint128).max);
        USDe.approve(address(eUSDe), type(uint128).max);
        eUSDe.approve(address(pUSDe), type(uint128).max);

        eUSDe.deposit(userDeposit, user);
        pUSDe.deposit(address(eUSDe), 5 ether, user);

        eUSDe.setEnabled(false);

        vm.expectRevert();
        pUSDe.deposit(address(eUSDe), 5 ether, user);

        eUSDe.setEnabled(true);
        pUSDe.deposit(address(eUSDe), 5 ether, user);
        assertEq(eUSDe.balanceOf(address(pUSDe)), 10 ether);

        vm.stopPrank();
    }

}

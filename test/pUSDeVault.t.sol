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


contract pUSDeVaultTest is Test {

    MockUSDe public USDe;
    MockStakedUSDe public sUSDe;
    MockERC4626 public eUSDe;
    pUSDeVault public pUSDe;
    pUSDeDepositorHelper public pUSDeDepositor;

    address account;


    function setUp() public {
        address owner = msg.sender;

        // Prepare Ethena and Ethreal contracts
        USDe = new MockUSDe();
        sUSDe = new MockStakedUSDe(USDe, owner, owner);
        eUSDe = new MockERC4626(USDe);

        // Prepare pUSDe and Depositor contracts
        pUSDe = pUSDeVault(address(new ERC1967Proxy(address(new pUSDeVault()), abi.encodeWithSelector(
            pUSDeVault.initialize.selector,
            owner,
            USDe,
            sUSDe
        ))));

        pUSDeDepositor = pUSDeDepositorHelper(address(new ERC1967Proxy(address(new pUSDeDepositorHelper()), abi.encodeWithSelector(
            pUSDeDepositorHelper.initialize.selector,
            owner,
            USDe,
            sUSDe,
            pUSDe
        ))));



        vm.startPrank(owner);
        pUSDe.setDepositsEnabled(true);
        pUSDe.setWithdrawalsEnabled(true);
        pUSDe.addVault(address(eUSDe));
    }

    function test_Flow() public {
        assert(address(USDe) != address(0));

        account = msg.sender;

        USDe.mint(account, 10 ether);
        deposit(USDe, 10 ether);
        assertBalance(pUSDe, account, 10 ether, "Initial deposit");

        pUSDe.withdraw(5 ether, account, account);
        assertBalance(USDe, account, 5 ether, "Withdraw half");


        pUSDe.startYieldPhase();
        deposit(USDe, 5 ether);
        assertBalance(sUSDe, address(pUSDe), 10 ether, "Yield Phase deposits all underlying into sUSDe");
    }


    function depositGeneric (IERC4626 vault, uint amount) internal {
        IERC20 asset = IERC20(vault.asset());
        asset.approve(address(vault), amount);
        vault.deposit(amount, account);
    }

    function deposit (IERC20 asset, uint amount) internal {
        asset.approve(address(pUSDeDepositor), amount);
        pUSDeDepositor.deposit(asset, amount, account);
    }

    function assertBalance (IERC20 token, address owner, uint amount, string memory message) internal {
        uint balance = token.balanceOf(owner);
        assertEq(balance, amount, message);

    }
}

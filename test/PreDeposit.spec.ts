import {
    time,
    loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import pUSDePreDepositModule from '../ignition/modules/pUSDePreDepositModule';
import yUSDePreDepositModule from '../ignition/modules/yUSDePreDepositModule';
import { IERC20, IERC4626 } from '../typechain-types';


describe("PreDeposit", function () {

    const ONE = ethers.parseUnits("1", "ether");

    async function deployPreDepositFixture() {


        // Contracts are deployed using the first signer/account by default
        const [owner] = await hre.ethers.getSigners();


        const MockUSDe = await hre.ethers.getContractFactory("MockUSDe");
        const mockUSDe = await MockUSDe.deploy();

        const MockStakedUSDe = await hre.ethers.getContractFactory("MockStakedUSDe");
        const mockStakedUSDe = await MockStakedUSDe.deploy(await mockUSDe.getAddress(), owner.address, owner.address);

        const {
            pUSDeVault,
            pUSDeDepositor,

            yUSDeVault,
            yUSDeDepositor,
        } = await hre.ignition.deploy(yUSDePreDepositModule, {
            parameters: {
                pUSDePreDepositModule: {
                    USDe: await mockUSDe.getAddress(),
                    sUSDe: await mockStakedUSDe.getAddress(),
                },
                yUSDePreDepositModule: {
                    USDe: await mockUSDe.getAddress(),
                    sUSDe: await mockStakedUSDe.getAddress(),
                }
            }
        });

        await mockUSDe.mint(owner.address, ONE);
        await pUSDeVault.setDepositsEnabled(true);
        await pUSDeVault.setWithdrawalsEnabled(true);
        await yUSDeVault.setDepositsEnabled(true);
        await yUSDeVault.setWithdrawalsEnabled(true);

        return {
            pUSDeVault,
            pUSDeDepositor,

            yUSDeVault,
            yUSDeDepositor,


            USDe: mockUSDe,
            sUSDe: mockStakedUSDe,
            owner,
        };
    }

    describe("Deployment", function () {
        it("Should deploy pUSDe/yUSDe modules", async function () {

            const { pUSDeVault, pUSDeDepositor, yUSDeVault, yUSDeDepositor, USDe, sUSDe, owner } = await loadFixture(deployPreDepositFixture);

            console.log(`Ensure addresses are correct.`)
            expect(await USDe.getAddress())
                .to.equal(await pUSDeVault.USDe())
                .to.equal(await pUSDeDepositor.USDe())
                .to.equal(await yUSDeVault.USDe(), `invalid USDe in yUSDeVault`);

            expect(await sUSDe.getAddress())
                .to.equal(await pUSDeVault.sUSDe())
                .to.equal(await pUSDeDepositor.sUSDe());

            expect(await yUSDeVault.getAddress())
                .to.equal(await yUSDeDepositor.yUSDe(), `invalid yUSDe Address in yUSDeDepositor`);

            expect(await pUSDeVault.getAddress())
                .to.equal(await yUSDeDepositor.pUSDe(), `invalid pUSDe Address in yUSDeDepositor`);


            await $x.deposit(pUSDeDepositor, USDe, ONE, owner);


            await $x.expectBalance(pUSDeVault, owner, ONE, `User should hold 1 pUSDe`);
            await $x.expectBalance(USDe, sUSDe, ONE, `sUSDe Vault should hold 1 USDe`);
            await $x.expectBalance(sUSDe, pUSDeVault, ONE, `pUSDe Vault should hold 1 sUSDe`);
            expect(await pUSDeVault.totalAssets())
                .to.equal(ONE, `invalid totalAssets after deposit`);

            // withdraw as sUSDe
            await pUSDeVault.withdraw(ONE / 2n, owner.address, owner.address);

            await $x.expectBalance(sUSDe, owner, ONE / 2n, `pUSDe Vault should hold 0.5 sUSDe after 0.5 USDe withdrawal`)



            await USDe.mint(owner.address, 10n * ONE);
            await USDe.approve(sUSDe, 10n * ONE);
            await sUSDe.transferInRewards(10n * ONE);

            const in8Hours = Date.now() + 8 * 61 * 60 * 1000;
            await time.increaseTo(in8Hours / 1000 | 0);

            const unvestedAmount = await sUSDe.getUnvestedAmount();
            expect(unvestedAmount).to.equal(0n, `pUSDe Vault should hold 0 unvested USDe after 8 hours`);

            const fullRedeemUSDe = await pUSDeVault.previewRedeem(await pUSDeVault.totalSupply());
            expect(fullRedeemUSDe).to.equal(10n * ONE + ONE / 2n, `pUSDe Vault should hold 0 unvested USDe after 8 hours`);

            const sUSDeTotalSupply = await sUSDe.totalSupply();
            expect(sUSDeTotalSupply).to.equal(ONE, ` sUSDe Vault should have minted 1 sUSDe: 0.5 in pUSDe, 0.5 in withdrawn Account`);

            const sUSDeAssets = await USDe.balanceOf(sUSDe);
            expect(sUSDeAssets).to.equal(10n * ONE + ONE, ` sUSDe Vault should hold 11 USDe`);

            const pUSDeAssets = await sUSDe.balanceOf(pUSDeVault);
            expect(pUSDeAssets).to.equal(ONE / 2n, `pUSDe Vault should hold 0.5 sUSDe`);

            const USDeBalance = await pUSDeVault.totalUSDe();
            expect(USDeBalance).to.equal(5499999999999999995n, `pUSDe Vault should hold 5.4999 USDe after 8 hours (based on rounding)`);


            await $x.deposit(yUSDeDepositor, pUSDeVault, ONE / 2n, owner);
            await $x.expectBalance(yUSDeVault, owner, ONE / 2n, `owner should have 0.5 yUSDe`);

            let pUSDeAmount = await yUSDeVault.previewRedeem(ONE / 4n);
            let sUSDeAmount = await pUSDeVault.previewRedeem(pUSDeAmount);
            let USDeAmount = await sUSDe.previewRedeem(sUSDeAmount);


            // withdraw as yUSDe
            let balanceBefore = await sUSDe.balanceOf(owner.address);
            await yUSDeVault.redeem(ONE / 4n, owner.address, owner.address);
            let balanceAfter = await sUSDe.balanceOf(owner.address);
            expect(balanceAfter - balanceBefore).to.equal(ONE / 4n, `pUSDe Vault should hold 0.25 sUSDe after 0.25 yUSDe redemption`);
        });

    });

});


namespace $x {

    type TAccount = string | { getAddress(): Promise<string> } | { address: string }
    type TSigner = string | { address: string }

    export async function approve (token: IERC20, spender: TAccount, amount: any) {
        const spenderAddress = await getAddress(spender);
        await (await token.approve(spenderAddress, amount)).wait();
    }

    export async function deposit (vault: IERC4626 | any, asset: TAccount, amount: any, receiver: TSigner) {
        await $x.approve(asset as IERC20, vault, amount);

        const assetAddress = await getAddress(asset);
        const receiverAddress: any = await getAddress(receiver);
        await (await vault.deposit(assetAddress, amount, receiverAddress)).wait();
    }
    export async function expectBalance (token: IERC20 | any, owner: TAccount, amount: any, message?: string) {
        const ownerAddress: any = await getAddress(owner);
        expect(await token.balanceOf(ownerAddress)).to.equal(amount, message);
    }

    export async function getAddress (acc: TAccount): Promise<string> {
        if (typeof acc === 'string') {
            return acc;
        }
        if ('address' in acc) {
            return acc.address;
        }
        return await acc.getAddress();
    }
}

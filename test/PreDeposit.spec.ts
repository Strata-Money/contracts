import {
    time,
    loadFixture,
    mine,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { expect } from "chai";
import hre, { ethers } from "hardhat";
import pUSDePreDepositModule from '../ignition/modules/pUSDePreDepositModule';
import yUSDePreDepositModule from '../ignition/modules/yUSDePreDepositModule';
import { IERC20, IERC4626, MockStakedUSDe, MockUSDe, PUSDeVault, StakedUSDe, YUSDeVault } from '../typechain-types';


describe("PreDeposit", function () {

    const ONE = ethers.parseUnits("1", "ether");

    async function deployPreDepositFixture() {


        // Contracts are deployed using the first signer/account by default
        const [owner] = await hre.ethers.getSigners();


        const MockUSDe = await hre.ethers.getContractFactory("MockUSDe");
        const mockUSDe = await MockUSDe.deploy();

        const MockStakedUSDe = await hre.ethers.getContractFactory("MockStakedUSDe");
        const mockStakedUSDe = await MockStakedUSDe.deploy(await mockUSDe.getAddress(), owner.address, owner.address);

        const EUSDe = await hre.ethers.getContractFactory("MockERC4626");
        const eUSDe = await EUSDe.deploy(await mockUSDe.getAddress());

        const xUSDe = await EUSDe.deploy(await mockUSDe.getAddress());

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
        await pUSDeVault.addVault(await eUSDe.getAddress());
        await pUSDeVault.addVault(await xUSDe.getAddress());

        $x.ctx.account = owner;
        $x.ctx.USDe = mockUSDe;
        $x.ctx.pUSDe = pUSDeVault as any as PUSDeVault;
        $x.ctx.yUSDe = yUSDeVault as any as YUSDeVault;
        $x.ctx.sUSDe = mockStakedUSDe;
        $x.ctx.pUSDeDepositor = pUSDeDepositor;
        $x.ctx.yUSDeDepositor = yUSDeDepositor;
        $x.ctx.eUSDe = eUSDe;
        $x.ctx.xUSDe = xUSDe;

        return {
            pUSDeVault,
            pUSDeDepositor,

            yUSDeVault,
            yUSDeDepositor,

            USDe: mockUSDe,
            sUSDe: mockStakedUSDe,
            owner,

            eUSDe: eUSDe,
        };
    }

    describe("Deployment", function () {
        it("Should deploy pUSDe/yUSDe modules", async function () {

            const { pUSDeVault, pUSDeDepositor, yUSDeVault, yUSDeDepositor, USDe, sUSDe, eUSDe, owner } = await loadFixture(deployPreDepositFixture);

            console.log(`pUSDe`, await $x.ctx.pUSDe.getAddress());

            console.log(`Ensure addresses are correct`)
            expect(await USDe.getAddress())
                .to.equal(await pUSDeVault.USDe())
                .to.equal(await pUSDeVault.asset())
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
            await $x.expectBalance(USDe, pUSDeVault, ONE, `pUSDe Vault should hold 1 USDe`);
            await $x.expectBalance(sUSDe, pUSDeVault, 0, `pUSDe Vault shouldn't have sUSDe staked`);
            expect(await pUSDeVault.totalAssets())
                .to.equal(ONE, `invalid totalAssets after deposit`);

            // withdraw as USDe
            await pUSDeVault.withdraw(ONE / 2n, owner.address, owner.address);

            await $x.expectBalance(USDe, owner, ONE / 2n, `pUSDe Vault should hold 0.5 sUSDe after 0.5 USDe withdrawal`);

            await $x.check(`
                User1: deposit 10 USDe
                User2: deposit 5 USDe
                User3: deposit 15 USDe
                balance: pUSDe 30.5 USDe
                User2: withdraw 3 USDe
                balance: pUSDe 27.5 USDe
                balance: User2 3 USDe

                User1: deposit 5 USDe into sUSDe
                error: User1: deposit 1 sUSDe into pUSDe | INVALID_PHASE

                User1: deposit 5 USDe
                balance: User1 0 USDe
                User1: withdraw 100% USDe
                balance: User1 15 USDe
            `);

            await $x.check(`
                User2: mint 5 USDe
                User2: deposit 5 USDe into eUSDe
                balance: User2 5 eUSDe
                User2: deposit 5 eUSDe
                User2: withdraw 3 eUSDe from pUSDe
                balance: User2 3 eUSDe
            `);

            console.log(`Upgrade PHASE`);
            await pUSDeVault.startYieldPhase();

            expect(Array.from(await pUSDeVault.assetsArr(0)))
                .to.have.same.members([await sUSDe.getAddress(), 0n, false]);

            expect(Array.from(await pUSDeVault.assetsMap(await eUSDe.getAddress())))
                .to.have.same.members(['0x0000000000000000000000000000000000000000', 0n, false]);


            await $x.check(`

                balance: pUSDe 0 USDe
                balance: pUSDe 19.5 sUSDe
                User3: withdraw 100% USDe
                balance: User3 15 sUSDe

                balance: User1 5 sUSDe
                User1: deposit 2 sUSDe into pUSDe
                balance: User1 3 sUSDe
                User1: withdraw 100% USDe
                balance: User1 5 sUSDe

                User3: deposit 4 USDe

                balance: User1 0 pUSDe
                balance: User2 4 pUSDe
                balance: User3 4 pUSDe
                balance: pUSDe 8.5 sUSDe

                error: User2: withdraw 5 sUSDe | ERC4626ExceededMaxWithdraw
            `);
            return;


            await USDe.mint(owner.address, 10n * ONE);
            await USDe.approve(sUSDe, 10n * ONE);
            await sUSDe.transferInRewards(10n * ONE);

            const in8Hours = Date.now() + 8 * 61 * 60 * 1000;
            await time.increaseTo(in8Hours / 1000 | 0);

            const unvestedAmount = await sUSDe.getUnvestedAmount();
            expect(unvestedAmount).to.equal(0n, `pUSDe Vault should hold 0 unvested USDe after 8 hours`);

            await $x.check(`
                balance: User2 0 sUSDe
                balance: User2 3 USDe
                User2: withdraw 100% USDe from pUSDe
                User2: cooldown 100% sUSDe
                wait: 8 days
                User2: unstake from sUSDe
                balance: User2 5 USDe
            `);

        });

        it("Should withdraw from multiple sources", async function () {

            await loadFixture(deployPreDepositFixture);

            await $x.check(`
                User1: deposit 10 USDe
                User2: deposit 5 USDe into eUSDe
                User2: deposit 5 eUSDe
                User3: deposit 10 USDe into xUSDe
                User3: deposit 10 xUSDe

                // User1 and User2 withdraw all USDe
                User2: withdraw 5 USDe
                User3: withdraw 5 USDe
                balance: pUSDe 0 USDe
                User1: withdraw 100% USDe
                balance: User1 10 USDe

                // By withdrawing USDe by User1, 5 eUSDe and 5 xUSDe should be withdrawn
                balance: pUSDe 0 eUSDe
                balance: pUSDe 5 xUSDe
            `);

        });

    });

});


namespace $x {

    export const ctx =  {
        account: null as any as TAccount,
        USDe: null as any as IERC20,
        pUSDe: null as any as PUSDeVault,
        eUSDe: null as any,
        xUSDe: null as any,
        sUSDe: null as any as StakedUSDe,
        yUSDe: null as any as YUSDeVault,
        pUSDeDepositor: null as any,
        yUSDeDepositor: null as any,
    }

    type TAccount = string | { getAddress(): Promise<string> } | { address: string }
    type TSigner = string | { address: string }

    export async function approve (token: IERC20, spender: TAccount, amount: any) {
        const spenderAddress = await getAddress(spender);
        await (await token.connect(ctx.account as any).approve(spenderAddress, amount)).wait();
    }

    export async function deposit (vault: IERC4626 | any, asset: TAccount, amount: any, receiver?: TSigner | TAccount) {

        if (typeof amount !== 'bigint') {
            amount = await getBigInt(amount);
        }

        const assetAddress = await getAddress(asset);
        const receiverAddress: any = await getAddress(receiver ?? ctx.account);
        if (assetAddress === await ctx.USDe.getAddress()) {
            let signer = await getAddress(ctx.account);
            let balance = await ctx.USDe.balanceOf(signer);
            if (balance < amount) {
                let toMint = amount - balance;
                console.log(`Minting ${toMint} USDe to ${signer}...`);
                await (ctx.USDe as MockUSDe).mint(signer, toMint);
            }
        }

        await $x.approve(asset as IERC20, vault, amount);

        if (vault === ctx.pUSDeDepositor || vault === ctx.yUSDeDepositor) {
            await (await vault.connect(ctx.account as any).deposit(assetAddress, amount, receiverAddress)).wait();
        } else {
            await (await vault.connect(ctx.account as any).deposit(amount, receiverAddress)).wait();
        }
    }
    export async function withdraw (vault: IERC4626 | any, amount: any, asset?: IERC20) {
        const receiverAddress: any = await getAddress(ctx.account);
        const contract = await vault.connect(ctx.account as any) as IERC4626;
        if (asset != null && await contract.asset() !== await asset.getAddress()) {
            await (contract as any)['withdraw(address,uint256,address,address)'](await asset.getAddress(), amount, receiverAddress, receiverAddress);
            return;
        }

        await contract.withdraw(amount, receiverAddress, receiverAddress);
    }
    export async function redeem (vault: IERC4626 | any, amount: any) {
        const receiverAddress: any = await getAddress(ctx.account);
        await (await vault.connect(ctx.account as any).redeem(amount, receiverAddress, receiverAddress)).wait();
    }
    export async function expectBalance (token: IERC20 | any, owner: TAccount, amount: any, message?: string) {
        const ownerAddress: any = await getAddress(owner);
        const balance = await token.balanceOf(ownerAddress);
        const diff = (balance - BigInt(amount)) as any as bigint;
        expect(diff < 0n ? (diff * -1n) : diff).to.lessThan(2, message);
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

    /**
        UserN: deposit N SYMBOL (into SYMBOL)?
        SYMBOL: totalSupply N
        balance: HOLDER N SYMBOL
     */
    export async function check (testCase: string) {
        let lines = testCase
            .split('\n')
            .map(x => x.trim())
            .filter(Boolean)
            .filter(x => /^(#|\/\/)/.test(x) === false);

        for (let line of lines) {
            await processLine(line)
        }
        async function processLine(line: string) {
            console.log(`Processing: ${line}`);

            let errorRgx = /^error: (?<errorLine>.+)/;
            let errorMatch = errorRgx.exec(line.trim());
            if (errorMatch!= null) {
                let { errorLine } = errorMatch.groups as any;
                let [ lineStr, errorMsg ] = errorLine.split('|');
                try {
                    await processLine(lineStr);
                    throw new Error(`Unreachable`);
                } catch (error) {
                    expect((error as any).message).to.include(errorMsg.trim());
                }
                return;
            }

            let waitRgx = /^wait: (?<amount>\d+) (?<units>(days|hours))/;
            let waitMatch = waitRgx.exec(line.trim());
            if (waitMatch!= null) {
                let { amount, units } = waitMatch.groups as any;
                let ms = 0;
                switch (units) {
                    case 'days':
                        ms = Number(amount) * 24 * 60 * 60 * 1000;
                        break;
                    case 'hours':
                        ms = Number(amount) * 60 * 60 * 1000;
                        break;
                }

                const unixTimestamp = (Date.now() + ms) / 1000 | 0;
                await time.increaseTo(unixTimestamp);
                await mine();
                return;
            }

            let depositRgx = /User(?<userIdxStr>\d+): deposit (?<amountStr>[\d.]+) (?<tokenSymbol>\w+)( into (?<vaultSymbol>\w+))?/;
            let depositMatch = depositRgx.exec(line.trim());
            if (depositMatch != null) {
                let { userIdxStr, amountStr, tokenSymbol, vaultSymbol } = depositMatch.groups as any;
                await setSigner(Number(userIdxStr));

                let asset: IERC20 = (ctx as any)[tokenSymbol];
                let amount = await getBigInt(amountStr);
                let vault: IERC4626 = !vaultSymbol
                    ? ctx.pUSDeDepositor
                    : ((ctx as any)[vaultSymbol + 'Depositor'] ?? (ctx as any)[vaultSymbol]);
                await deposit(vault, asset, amount, ctx.account)
                return;
            }

            let withdrawRgx = /User(?<userIdxStr>\d+): withdraw (?<amountStr>[\d.]+%?) (?<tokenSymbol>\w+)( from (?<vaultSymbol>\w+))?/;
            let withdrawMatch = withdrawRgx.exec(line.trim());
            if (withdrawMatch != null) {
                let { userIdxStr, amountStr, tokenSymbol, vaultSymbol } = withdrawMatch.groups as any;
                let account = await setSigner(Number(userIdxStr));

                let asset: IERC20 = (ctx as any)[tokenSymbol];
                let vault: IERC4626 = (ctx as any)[vaultSymbol] ?? ctx.pUSDe;
                if (amountStr.endsWith('%')) {
                    let address = await getAddress(account);
                    let totalShares = await vault.balanceOf(address);
                    let shares = totalShares * BigInt(Number(amountStr.replace('%', ''))) / 100n;
                    await redeem(vault, shares);
                    return;
                }
                let amount = await getBigInt(amountStr);
                await withdraw(vault, amount, asset);
                return;
            }

            let mintRgx = /User(?<userIdxStr>\d+): mint (?<amountStr>[\d.]+%?) (?<tokenSymbol>\w+)/;
            let mintMatch = mintRgx.exec(line.trim());
            if (mintMatch != null) {
                let { userIdxStr, amountStr, tokenSymbol } = mintMatch.groups as any;
                let account = await setSigner(Number(userIdxStr));

                let asset: IERC20 = (ctx as any)[tokenSymbol];
                let amount = await getBigInt(amountStr);
                let owner = await getAddress(ctx.account);

                await (asset.connect(ctx.account as any) as any).mint(owner, amount);
                return;
            }

            let cooldownRgx = /User(?<userIdxStr>\d+): cooldown (?<sharesStr>[\d.]+%?) (?<vaultSymbol>\w+)/;
            let cooldownMatch = cooldownRgx.exec(line.trim());
            if (cooldownMatch != null) {
                let { userIdxStr, sharesStr, vaultSymbol } = cooldownMatch.groups as any;
                let account = await setSigner(Number(userIdxStr));

                let vault: MockStakedUSDe = (ctx as any)[vaultSymbol] ?? ctx.sUSDe;
                let assets = null;
                if (sharesStr.endsWith('%')) {
                    let address = await getAddress(account);
                    let totalShares = await vault.balanceOf(address);
                    let shares = totalShares * BigInt(Number(sharesStr.replace('%', ''))) / 100n;
                    assets = await vault.previewRedeem(shares);
                } else {
                    assets = await getBigInt(sharesStr)
                }
                await (await vault.connect(ctx.account as any).cooldownAssets(assets)).wait();
                return;
            }

            let unstakeRgx = /User(?<userIdxStr>\d+): unstake from (?<vaultSymbol>\w+)/;
            let unstakeMatch = unstakeRgx.exec(line.trim());
            if (unstakeMatch != null) {
                let { userIdxStr, vaultSymbol } = unstakeMatch.groups as any;
                let account = await setSigner(Number(userIdxStr));

                let vault: MockStakedUSDe = (ctx as any)[vaultSymbol] ?? ctx.sUSDe;
                let receiver = await getAddress(account);

                await (await vault.connect(ctx.account as any).unstake(receiver)).wait();
                return;
            }

            let balanceRgx = /balance: ((User(?<userIdxStr>\d+))|(?<contract>\w+)) (?<amountStr>[\d.]+) (?<tokenSymbol>\w+)/;
            let balanceMatch = balanceRgx.exec(line.trim());
            if (balanceMatch != null) {
                let { userIdxStr, contract, amountStr, tokenSymbol } = balanceMatch.groups as any;
                let holder = userIdxStr
                    ? await setSigner(userIdxStr)
                    : (ctx as any)[contract];

                let token: IERC20 = (ctx as any)[tokenSymbol];
                let amount = await getBigInt(amountStr);
                await expectBalance(token, holder, amount)
                return;
            }

            let totalSupplyRgx = /totalSupply: (?<amountStr>[\d.]+) (?<tokenSymbol>\w+)/;
            let totalSupplyMatch = totalSupplyRgx.exec(line.trim());
            if (totalSupplyMatch != null) {
                let { amountStr, tokenSymbol } = totalSupplyMatch.groups as any;

                let token: IERC20 = (ctx as any)[tokenSymbol];
                let amount = await getBigInt(amountStr);
                let totalSupply = await token.totalSupply();
                expect(totalSupply).to.equal(amount, `Line ${line}`);
                return;
            }
            throw new Error(`Invalid line: ${line}`);
        }
    }

    export async function setSigner (i: number | string) {
        const signers = await ethers.getSigners();
        ctx.account = signers[Number(i)];
        return ctx.account;
    };

    export async function getBigInt(amount: string | number | bigint, decimals: number = 18): Promise<bigint> {
        if (typeof amount === 'bigint') {
            return amount;
        }
        if (typeof amount === 'string') {
            let x = Number(amount);
            if (isNaN(x)) {
                throw new Error(`Invalid amount number: ${amount}`);
            }
            amount = x;
        }
        return BigInt(amount * 10**decimals);
    }
}

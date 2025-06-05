import { task } from "hardhat/config";
import { Addresses } from '../src/constants';
import { PUSDeVault } from '../typechain-types';
import { txWait } from '../src/utils';


task("preDeposit", "Activate preDeposit vaults")
  .addParam("action", "Action")
  .setAction(async ({ action }, hre) => {

    const { default: pUSDePreDepositModule } = await import('../ignition/modules/pUSDePreDepositModule');

    const pUSDeModule = await hre.ignition.deploy(pUSDePreDepositModule);
    const pUSDeVault = pUSDeModule.pUSDeVault as any as PUSDeVault;
    const [deployer] = await hre.ethers.getSigners();

    const USDe = await hre.ethers.getContractAt("MockUSDe", Addresses[hre.network.name].USDe);

    switch (action) {
      case 'enable':
        await txWait(pUSDeVault.setDepositsEnabled(true));
        await txWait(pUSDeVault.setWithdrawalsEnabled(true));
        break;
      case 'deposit':
        const balance = await USDe.balanceOf(deployer.address);
        if (balance > 0) {
          await txWait(USDe.approve(await pUSDeVault.getAddress(), balance));
          await txWait(pUSDeVault['deposit(uint256,address)'](balance, deployer.address));
        }
        console.log("TotalSupply", await pUSDeVault.totalSupply());
        break;
      default:
        throw new Error(`Invalid action: ${action}`);
    }

  });



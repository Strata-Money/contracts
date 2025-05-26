import hre from "hardhat";
import pUSDePreDepositModule from "../modules/pUSDePreDepositModule";
import { vars } from 'hardhat/config';
import { Addresses } from '../../src/constants';

async function main() {

    const { pUSDeVault } = await hre.ignition.deploy(pUSDePreDepositModule);
    const [deployer] = await hre.ethers.getSigners();

    console.log("🔍 Verifying ...");

    const argOwner = vars.get("OWNER", '') || deployer.address;
    const argUSDe = Addresses[hre.network.name]?.USDe;
    const argsUSDe = Addresses[hre.network.name]?.sUSDe;
    const argName = "Strata Pre-deposit Vault";
    const argSymbol = "sUSDe";


    await hre.run("verify:verify", {
        address: await pUSDeVault.getAddress(),
        constructorArguments: [
            argOwner,
            argUSDe,
            argsUSDe,
            argName,
            argSymbol
        ]
    });

    console.log("✅ Verified successfully!");
}

main().catch((error) => {
    console.error("❌ Error in deployment or verification:", error);
    process.exit(1);
});

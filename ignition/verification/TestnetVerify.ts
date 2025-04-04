import hre from "hardhat";
import TestnetModule from "../modules/Testnet";

async function main() {

    const { mockUSDe, stakedMockUSDe } = await hre.ignition.deploy(TestnetModule);
    const [deployer] = await hre.ethers.getSigners();

    console.log("🔍 Verifying ...");


    await hre.run("verify:verify", {
        address: await mockUSDe.getAddress(),
    });

    await hre.run("verify:verify", {
        address: await stakedMockUSDe.getAddress(),
        constructorArguments: [
            await mockUSDe.getAddress(),
            deployer.address,
            deployer.address,
        ]
    });

    console.log("✅ Verified successfully!");
}

main().catch((error) => {
    console.error("❌ Error in deployment or verification:", error);
    process.exit(1);
});

// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const TestnetModule = buildModule("TestnetModule", (m) => {
    const deployer = m.getAccount(0);

    const mockUSDe = m.contract("MockUSDe", [], {});
    const stakedMockUSDe = m.contract("MockStakedUSDe", [
        mockUSDe, deployer, deployer
    ], {});

    return { mockUSDe, stakedMockUSDe  };
});

export default TestnetModule;

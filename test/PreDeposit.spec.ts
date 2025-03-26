import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { anyValue } from "@nomicfoundation/hardhat-chai-matchers/withArgs";
import { expect } from "chai";
import hre, { ethers } from "hardhat";


describe("PreDeposit", function () {

  const ONE = ethers.parseUnits("1", "ether");

  async function deployPreDepositFixture() {


    // Contracts are deployed using the first signer/account by default
    const [ owner ] = await hre.ethers.getSigners();

    const MockUSDe = await hre.ethers.getContractFactory("MockUSDe");
    const mockUSDe = await MockUSDe.deploy();

    const PreDeposit = await hre.ethers.getContractFactory("StrataPreDepositVault");
    const preDeposit = await PreDeposit.deploy(owner.address, await mockUSDe.getAddress(), "PreDeposit", "PreTest");



    await mockUSDe.mint(owner.address, ONE);
    await preDeposit.setDepositsEnabled(true);

    return { preDeposit, mockUSDe, owner };
  }

  describe("Deployment", function () {
    it("Should deploy contract", async function () {

      const { preDeposit, mockUSDe, owner } = await loadFixture(deployPreDepositFixture);

      (await mockUSDe.approve(await preDeposit.getAddress(), ONE)).wait();
      (await preDeposit.deposit(ONE, owner.address)).wait();

      expect(await preDeposit.balanceOf(owner.address)).to.equal(ONE);
    });

  });

});

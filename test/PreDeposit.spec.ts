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

    const MockStakedUSDe = await hre.ethers.getContractFactory("MockStakedUSDe");
    const mockStakedUSDe = await MockStakedUSDe.deploy(await mockUSDe.getAddress(), owner.address, owner.address);

    const PreDeposit = await hre.ethers.getContractFactory("StrataPreDepositVault");
    const preDeposit = await PreDeposit.deploy(
      owner.address,
      await mockUSDe.getAddress(),
      await mockStakedUSDe.getAddress(),
      "PreDeposit",
      "PreTest"
    );

    await mockUSDe.mint(owner.address, ONE);
    await preDeposit.setDepositsEnabled(true);
    await preDeposit.setWithdrawalsEnabled(true);

    return { preDeposit, mockUSDe, mockStakedUSDe, owner };
  }

  describe("Deployment", function () {
    it("Should deploy contract", async function () {

      const { preDeposit, mockUSDe, mockStakedUSDe, owner } = await loadFixture(deployPreDepositFixture);

      await (await mockUSDe.approve(await preDeposit.getAddress(), ONE)).wait();
      await (await preDeposit.deposit(ONE, owner.address)).wait();


      expect(await preDeposit.balanceOf(owner.address)).to.equal(ONE);
      expect(await mockUSDe.balanceOf(await mockStakedUSDe.getAddress())).to.equal(ONE);
      expect(await mockStakedUSDe.balanceOf(await preDeposit.getAddress())).to.equal(ONE);

      // withdraw staked assets
      await (await preDeposit.withdraw(ONE / 2n, owner.address, owner.address)).wait();
      expect(await mockStakedUSDe.balanceOf(owner.address)).to.equal(ONE / 2n);

    });

  });

});

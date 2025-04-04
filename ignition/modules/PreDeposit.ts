// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Addresses } from '../../src/constants';
import { vars } from 'hardhat/config';
import hre from 'hardhat'

const PreDepositModule = buildModule("PreDepositModule", (m) => {
  const initialOwner_ = vars.get("OWNER", '') || m.getAccount(0);
  const USDe_ = m.getParameter("USDe", Addresses[hre.network.name]?.USDe);
  const sUSDe_ = m.getParameter("sUSDe", Addresses[hre.network.name]?.sUSDe);
  const name_ = m.getParameter("name", "Strata Pre-deposit Vault");
  const symbol_ = m.getParameter("symbol", "sUSDe");

  const preDeposit = m.contract("StrataPreDepositVault", [initialOwner_, USDe_, sUSDe_, name_, symbol_], {

  });

  return { preDeposit };
});

export default PreDepositModule;

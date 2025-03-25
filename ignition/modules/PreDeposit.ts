// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { USDE } from '../../src/constants';
import { vars } from 'hardhat/config';

const PreDepositModule = buildModule("PreDepositModule", (m) => {
  const initialOwner_ = vars.get("OWNER");
  const asset_ = m.getParameter("asset", USDE);
  const name_ = m.getParameter("name", "Strata Pre-deposit Vault");
  const symbol_ = m.getParameter("symbol", "sUSDe");

  const preDeposit = m.contract("StrataPreDepositVault", [initialOwner_, asset_, name_, symbol_], {

  });

  return { preDeposit };
});

export default PreDepositModule;

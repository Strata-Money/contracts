// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Addresses } from '../../src/constants';
import { vars } from 'hardhat/config';
import hre from 'hardhat'
import pUSDePreDepositModule from './pUSDePreDepositModule';

const yUSDePreDepositModule = buildModule("yUSDePreDepositModule", (m) => {
    const initialOwner_ = vars.get("OWNER", '') || m.getAccount(0);
    const USDe_ = m.getParameter("USDe", Addresses[hre.network.name]?.USDe);
    const sUSDe_ = m.getParameter("sUSDe", Addresses[hre.network.name]?.sUSDe);
    const pUSDeModule = m.useModule(pUSDePreDepositModule);

    const yUSDeVaultLogic = m.contract("yUSDeVault", [], {
        id: "yUSDeVaultLogic"
    });

    const yUSDeVaultInitialize = m.encodeFunctionCall(yUSDeVaultLogic, "initialize", [
        initialOwner_,
        USDe_,
        sUSDe_,
        pUSDeModule.pUSDeVault
    ]);
    const yUSDeVaultProxy = m.contract("TransparentUpgradeableProxy", [
        yUSDeVaultLogic,
        initialOwner_,
        yUSDeVaultInitialize,
    ], {
        id: "yUSDeVaultProxy"
    });

    const yUSDeVaultAdminAddress = m.readEventArgument(
        yUSDeVaultProxy,
        "AdminChanged",
        "newAdmin", {
            id: 'yUSDeVaultAdminAddress'
        }
    );
    const yUSDeVaultAdmin = m.contractAt("ProxyAdmin", yUSDeVaultAdminAddress, {
        id: 'yUSDeVaultAdmin'
    });

    const yUSDeDepositorLogic = m.contract("yUSDeDepositor", [], {
        id: "yUSDeDepositorLogic"
    });

    const yUSDeDepositorInitialize = m.encodeFunctionCall(yUSDeDepositorLogic, "initialize", [
        initialOwner_,
        yUSDeVaultProxy,
        pUSDeModule.pUSDeVault,
        pUSDeModule.pUSDeDepositor,
    ]);
    const yUSDeDepositorProxy = m.contract("TransparentUpgradeableProxy", [
        yUSDeDepositorLogic,
        initialOwner_,
        yUSDeDepositorInitialize,
    ], {
        id: "yUSDeDepositorProxy"
    });

    const yUSDeDepositorAdminAddress = m.readEventArgument(
        yUSDeDepositorProxy,
        "AdminChanged",
        "newAdmin", {
            id: 'yUSDeDepositorAdminAddress'
        }
    );
    const yUSDeDepositorAdmin = m.contractAt("ProxyAdmin", yUSDeDepositorAdminAddress, {
        id: 'yUSDeDepositorAdmin'
    });

    const yUSDeVault = m.contractAt("yUSDeVault", yUSDeVaultProxy, {
        id: 'yUSDeVault'
    });
    const yUSDeDepositor = m.contractAt("yUSDeDepositor", yUSDeDepositorProxy, {
        id: 'yUSDeDepositor'
    });


    return {
        pUSDeVault: pUSDeModule.pUSDeVault,
        pUSDeDepositor: pUSDeModule.pUSDeDepositor,

        yUSDeVault,
        yUSDeVaultLogic,
        yUSDeVaultAdmin,

        yUSDeDepositor,
        yUSDeDepositorLogic,
        yUSDeDepositorAdmin,
     };
});

export default yUSDePreDepositModule;

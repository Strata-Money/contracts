// This setup uses Hardhat Ignition to manage smart contract deployments.
// Learn more about it at https://hardhat.org/ignition

import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { Addresses } from '../../src/constants';
import { vars } from 'hardhat/config';
import hre from 'hardhat'

const pUSDePreDepositModule = buildModule("pUSDePreDepositModule", (m) => {
    const initialOwner_ = vars.get("OWNER", '') || m.getAccount(0);
    const USDe_ = m.getParameter("USDe", Addresses[hre.network.name]?.USDe);
    const sUSDe_ = m.getParameter("sUSDe", Addresses[hre.network.name]?.sUSDe);

    const pUSDeVaultLogic = m.contract("pUSDeVault", [], {
        id: "pUSDeVaultLogic"
    });


    const pUSDeVaultInitialize = m.encodeFunctionCall(pUSDeVaultLogic, "initialize(address,address,address)", [
        initialOwner_,
        USDe_,
        sUSDe_,
    ]);
    const pUSDeVaultProxy = m.contract("TransparentUpgradeableProxy", [
        pUSDeVaultLogic,
        initialOwner_,
        pUSDeVaultInitialize,
    ], {
        id: "pUSDeVaultProxy"
    });

    const pUSDeVaultAdminAddress = m.readEventArgument(
        pUSDeVaultProxy,
        "AdminChanged",
        "newAdmin", {
            id: 'pUSDeVaultAdminAddress'
        }
    );
    const pUSDeVaultAdmin = m.contractAt("ProxyAdmin", pUSDeVaultAdminAddress, {
        id: 'pUSDeVaultAdmin'
    });

    const pUSDeDepositorLogic = m.contract("pUSDeDepositor", [], {
        id: "pUSDeDepositorLogic"
    });
    const pUSDeDepositorInitialize = m.encodeFunctionCall(pUSDeDepositorLogic, "initialize", [
        initialOwner_,
        USDe_,
        sUSDe_,
        pUSDeVaultProxy,
    ]);
    const pUSDeDepositorProxy = m.contract("TransparentUpgradeableProxy", [
        pUSDeDepositorLogic,
        initialOwner_,
        pUSDeDepositorInitialize,
    ], {
        id: "pUSDeDepositorProxy"
    });

    const pUSDeDepositorAdminAddress = m.readEventArgument(
        pUSDeDepositorProxy,
        "AdminChanged",
        "newAdmin", {
            id: 'pUSDeDepositorAdminAddress'
        }
    );
    const pUSDeDepositorAdmin = m.contractAt("ProxyAdmin", pUSDeDepositorAdminAddress, {
        id: 'pUSDeDepositorAdmin'
    });

    const pUSDeVault = m.contractAt("pUSDeVault", pUSDeVaultProxy, {
        id: 'pUSDeVault'
    });
    const pUSDeDepositor = m.contractAt("pUSDeDepositor", pUSDeDepositorProxy, {
        id: 'pUSDeDepositor'
    });



    return {
        pUSDeVault,
        pUSDeVaultLogic,
        pUSDeVaultAdmin,

        pUSDeDepositor,
        pUSDeDepositorLogic,
        pUSDeDepositorAdmin,
     };
});

export default pUSDePreDepositModule;

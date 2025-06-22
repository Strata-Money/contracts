import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import env from "dotenv";
import "./tasks/preDeposit"

env.config();

const config: HardhatUserConfig = {
  solidity: {
      version: "0.8.28",
      settings: {
          optimizer: {
              enabled: true,
              runs: 200
          }
      }
  },
  networks: {
    eth: {
      url: "https://ethereum-rpc.publicnode.com",
      accounts: [ process.env.ETH_DEPLOYER! ],
      gasMultiplier: 1.3,
    },
    hoodi: {
      url: "https://ethereum-hoodi-rpc.publicnode.com",
      accounts: [ process.env.DEPLOYER! ],
    },
  },
  etherscan: {
    apiKey: {
      eth: process.env.ETHERSCAN_API_KEY!,
      hoodi: process.env.ETHERSCAN_API_KEY!,
    },
    customChains: [
      {
        network: "hoodi",
        chainId: 560048,
        urls: {
          apiURL: "https://api-hoodi.etherscan.io/api",
          browserURL: "https://hoodi.etherscan.io"
        }
      },
      {
        network: "eth",
        chainId: 1,
        urls: {
          apiURL: "https://api.etherscan.io/api",
          browserURL: "https://etherscan.io"
        }
      }
    ]
  }

};

export default config;

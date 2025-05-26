import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@nomicfoundation/hardhat-foundry";
import env from "dotenv";

env.config();

const config: HardhatUserConfig = {
  solidity: "0.8.28",
  networks: {
    hoodi: {
      url: "https://ethereum-hoodi-rpc.publicnode.com",
      accounts: [ process.env.DEPLOYER! ],
    },
  },
  etherscan: {
    apiKey: {
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
      }
    ]
  }

};

export default config;

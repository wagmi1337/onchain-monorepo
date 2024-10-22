import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

const config: HardhatUserConfig = {
  networks: {
    base: {
      url: "https://mainnet.base.org",
      chainId: 8453,
      accounts: process.env.DEPLOYER ? [process.env.DEPLOYER!] : []
    },
    baseSepolia: {
      url: "https://sepolia.base.org",
      chainId: 84532,
      accounts: process.env.DEPLOYER ? [process.env.DEPLOYER!] : []
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 99999,
          },
        },
      },
    ]
  },
  sourcify: {
    enabled: true
  },
  etherscan: {
    apiKey: {
      base: process.env.BASESCAN_API_KEY!
    }
  },
  mocha: {
    timeout: 100 * 10000000
  },
};

export default config;
import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "dotenv/config";

const deployerKey = process.env.DEPLOYER_KEY;
if (!deployerKey) {
  console.warn(
    "DEPLOYER_KEY not found in .env file. Running with default config"
  );
}
const etherscanApiKey = process.env.ETHERSCAN_API_KEY ?? "";
if (!etherscanApiKey) {
  console.warn(
    "ETHERSCAN_API_KEY not found in .env file. Will skip Etherscan verification"
  );
}
const polygonApiKey = process.env.POLYSCAN_API_KEY ?? "";
if (!polygonApiKey) {
  console.warn(
    "POLYSCAN_API_KEY not found in .env file. Will skip Etherscan verification"
  );
}
const bscApiKey = process.env.BSCSCAN_API_KEY ?? "";
if (!bscApiKey) {
  console.warn(
    "BSCSCAN_API_KEY not found in .env file. Will skip Etherscan verification"
  );
}

const config: HardhatUserConfig = {
  solidity: "0.8.19",
  networks: {
    sepolia: {
      chainId: 11155111,
      url: "https://eth-sepolia.public.blastapi.io",
      accounts: [deployerKey as string],
    },
    mumbai: {
      chainId: 80001,
      url: "https://rpc-mumbai.maticvigil.com/",
      accounts: [deployerKey as string],
    },
    bscTestnet: {
      chainId: 97,
      url: "https://data-seed-prebsc-2-s2.bnbchain.org:8545",
      accounts: [deployerKey as string],
    }
  },
  etherscan: {
    apiKey: {
      sepolia: etherscanApiKey,
      polygonMumbai: polygonApiKey,
      bscTestnet: bscApiKey,
    },
  },
};

export default config;

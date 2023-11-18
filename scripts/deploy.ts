import { ethers } from "hardhat";

async function main() {
  // https://docs.chain.link/ccip/supported-networks/testnet#polygon-mumbai
  const ccipRouterAddr = "0xd0daae2231e9cb96b94c8512223533293c3693bf";

  // deploy Pool on sepolia
  const mockPool = await ethers.deployContract("MockPool");

  // deploy agent on sepolia and mumbai
  const crossChainAaveAgent = await ethers.deployContract("CrossChainAaveAgent", [await mockPool.getAddress(), ccipRouterAddr]);

  console.log(await mockPool.getAddress())
  console.log(await crossChainAaveAgent.getAddress())
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

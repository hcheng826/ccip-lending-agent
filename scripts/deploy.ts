import { ethers } from "hardhat";
import { data } from "./data";
import hre from "hardhat";

async function main() {
  // https://docs.chain.link/ccip/supported-networks/testnet

  // @ts-ignore
  const ccipRouterAddr = data[hre.network.name].ccipRouter;

  const mockPool = await ethers.deployContract("MockPool");

  const crossChainAaveAgent = await ethers.deployContract(
    "CrossChainAaveAgent",
    [await mockPool.getAddress(), ccipRouterAddr]
  );

  console.log("MockPool address: ", await mockPool.getAddress());
  console.log(
    "CrossChainAaveAgent address: ",
    await crossChainAaveAgent.getAddress()
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

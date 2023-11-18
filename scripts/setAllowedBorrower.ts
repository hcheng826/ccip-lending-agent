import { ethers } from "hardhat";
import { data } from "./data";

async function main() {
  const ccaaAddr = data.sepolia.CrossChainAaveAgent;

  const crossChainAaveAgent = await ethers.getContractAt(
    "CrossChainAaveAgent",
    ccaaAddr
  );

  const tx = await crossChainAaveAgent.setAllowedBorrower(
    [data.bscTestnet.chainSelector],
    [[data.bscTestnet.CrossChainAaveAgent]],
    [[true]]
  );
  await tx.wait();

  console.log("setAllowedBorrower complete, tx hash: ", tx?.hash);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

import { data } from "./data";
import { ethers } from "hardhat";

async function main() {
  const crossChainAaveAgent = await ethers.getContractAt(
    "CrossChainAaveAgent",
    data.bscTestnet.CrossChainAaveAgent
  );

  const ccipBnM = await ethers.getContractAt("IERC20", data.sepolia.CCIP_BnM);

  const tx = await crossChainAaveAgent.borrowFromChain(
    {
      asset: data.sepolia.CCIP_BnM,
      amount: ethers.parseEther("0.00003"),
      onBehalfOf: ethers.ZeroAddress,
      interestRateMode: 0,
      referralCode: 0,
    },
    data.sepolia.CrossChainAaveAgent,
    data.sepolia.chainSelector
  );
  const rc = await tx.wait();

  console.log(
    "borrowFromChain 0.00003 CCIP BnM from sepolia to bscTestnet, tx hash: ",
    tx?.hash
  );
  console.log(
    "CCIP message ID (for CCIP explorer lookup): ",
    rc?.logs.filter(
      (log) =>
        log.topics[0] ===
        "0x54791b38f3859327992a1ca0590ad3c0f08feba98d1a4f56ab0dca74d203392a" // MessageSent event
    )[0].data
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

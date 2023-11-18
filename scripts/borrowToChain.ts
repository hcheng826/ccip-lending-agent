import { data } from "./data";
import { ethers } from "hardhat";

async function main() {
  const ccaaAddr = data.sepolia.CrossChainAaveAgent;
  const crossChainAaveAgent = await ethers.getContractAt(
    "CrossChainAaveAgent",
    data.sepolia.CrossChainAaveAgent
  );
  const mockPool = await ethers.getContractAt(
    "MockPool",
    data.sepolia.MockPool
  );

  const ccipBnM = await ethers.getContractAt("IERC20", data.sepolia.CCIP_BnM);

  const initMockPoolBalance = await ccipBnM.balanceOf(
    await mockPool.getAddress()
  );
  const tx = await crossChainAaveAgent.borrowToChain(
    {
      asset: data.sepolia.CCIP_BnM,
      amount: ethers.parseEther("0.001"),
      onBehalfOf: ethers.ZeroAddress,
      interestRateMode: 0,
      referralCode: 0,
    },
    data.bscTestnet.chainSelector,
    data.bscTestnet.CrossChainAaveAgent
  );
  const rc = await tx.wait();
  const endMockPoolBalance = await ccipBnM.balanceOf(
    await mockPool.getAddress()
  );

  console.log(
    "borrowToChain 0.001 CCIP BnM from sepolia to bscTestnet, tx hash: ",
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
  console.log(
    "mockPool BnM balance diff: ",
    endMockPoolBalance - initMockPoolBalance
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

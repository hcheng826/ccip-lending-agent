import { data } from "./data";
import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners();
  const crossChainAaveAgent = await ethers.getContractAt(
    "CrossChainAaveAgent",
    data.bscTestnet.CrossChainAaveAgent
  );

  const ccipBnM = await ethers.getContractAt("IERC20", data.bscTestnet.CCIP_BnM);

  const initBalance = await ccipBnM.balanceOf(signer.address);

  if (
    (await ccipBnM.allowance(signer.address, data.bscTestnet.CrossChainAaveAgent)) <
    ethers.parseEther("0.0004")
  ) {
    const approveTx = await ccipBnM.approve(
      data.bscTestnet.CrossChainAaveAgent,
      ethers.MaxUint256
    );
    await approveTx.wait();
  }

  const tx = await crossChainAaveAgent.repayToChain(
    {
      asset: data.sepolia.CCIP_BnM,
      amount: ethers.parseEther("0.0004"),
      onBehalfOf: ethers.ZeroAddress,
      interestRateMode: 0,
      referralCode: 0,
    },
    data.sepolia.CrossChainAaveAgent,
    data.sepolia.chainSelector,
    data.bscTestnet.CCIP_BnM,
    {gasLimit: 1e7}
  );
  const rc = await tx.wait();
  const endBalance = await ccipBnM.balanceOf(signer.address);

  console.log(
    "repayToChain 0.0004 CCIP BnM from bscTestnet to sepolia, tx hash: ",
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
  console.log("BnM balance diff: ", endBalance - initBalance);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

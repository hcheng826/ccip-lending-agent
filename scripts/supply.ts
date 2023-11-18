import { data } from "./data";
import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners();
  const ccaaAddr = data.sepolia.CrossChainAaveAgent;
  const crossChainAaveAgent = await ethers.getContractAt(
    "CrossChainAaveAgent",
    ccaaAddr
  );
  const mockPool = await ethers.getContractAt(
    "MockPool",
    data.sepolia.MockPool
  );

  const ccipBnM = await ethers.getContractAt("IERC20", data.sepolia.CCIP_BnM);

  if (
    (await ccipBnM.allowance(signer.address, ccaaAddr)) <
    ethers.parseEther("0.01")
  ) {
    const approveTx = await ccipBnM.approve(ccaaAddr, ethers.MaxUint256);
    await approveTx.wait();
  }

  const initSupply = await mockPool.deposits(ccaaAddr, data.sepolia.CCIP_BnM);
  const tx = await crossChainAaveAgent.supply({
    asset: data.sepolia.CCIP_BnM,
    amount: ethers.parseEther("0.01"),
    onBehalfOf: ethers.ZeroAddress,
    interestRateMode: 0,
    referralCode: 0,
  });
  await tx.wait();
  const endSupply = await mockPool.deposits(ccaaAddr, data.sepolia.CCIP_BnM);

  console.log("supplied 0.01 CCIP BnM token on sepolia, tx hash: ", tx?.hash);
  console.log("mockPool.deposits[ccaa][BnM] diff: ", endSupply - initSupply);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

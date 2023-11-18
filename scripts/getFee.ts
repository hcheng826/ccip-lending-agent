import { data } from "./data";
import { ethers } from "hardhat";

async function main() {
  const router = await ethers.getContractAt(
    "IRouterClient",
    // data.bscTestnet.ccipRouter
    "0x9527e2d01a3064ef6b50c1da1c0cc523803bcff2"
  );
  const m = {
    data: "0x0000000000000000000000000000000000000000000000000000000000000001000000000000000000000000f1e3a5842eeef51f2967b3f05d45dd4f4205ff4000000000000000000000000000000000000000000000000000016bcc41e90000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
    extraArgs: "0x",
    feeToken: ethers.ZeroAddress,
    // feeToken: data.mumbai.LINK,
    // feeToken: "0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846",
    receiver:
      "0x000000000000000000000000b24047f4f3ace8b565a3bb424941dba7837a9a3b",
    tokenAmounts: [
      {
        amount: "400000000000000",
        token: "0xf1e3a5842eeef51f2967b3f05d45dd4f4205ff40",
      },
    ],
  };
  const fee = await router.getFee(data.sepolia.chainSelector, m);

  console.log("router", ethers.formatEther(fee));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

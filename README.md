# CCIP-Lending-Agent

## Introduction
In the DeFi space, liquidity is often fragmented across multiple chains, leading to inefficiencies. This project is a Proof of Concept (PoC) for a cross-chain operation of asset supply and borrowing on lending protocol like Aave, utilizing Chainlink's Cross-Chain Interoperability Protocol (CCIP). The primary goal is to bridge the liquidity gaps between chains, aiming for a future where users can engage in chain-agnostic supply and borrowing activities. The project envisions aggregating collateral and borrowing positions across various chains, allowing users to secure optimal rates through an underlying aggregator that facilitates transactions across multiple chains.

## Assumption and Limitation
CCIP only supports special token (CCIP BnM) on the Testnet, which isn't supported on Aave's Testnet contracts. Thus, a `MockPool` was developed to mimic Aave's Pool, where CCIP BnM tokens can be supplied. The project currently focuses only on the standard supply, borrow, and repay workflows, omitting interest rate calculations and liquidation processes.

This PoC currently lacks comprehensive local unit testing. Instead, the functionalities were directly validated on the testnet. Further research and development are required to establish best practices for unit testing in a CCIP environment.

## Smart Contracts
Two key contracts were developed:

- `MockPool`: This contract simulates the Aave v3 Pool, providing basic functionalities like supply, borrow, repay, and withdraw. While the function interfaces match Aave v3 Pool, the implementation is simplified to basic token transfers, excluding components like interest rates and liquidation.

- `CrossChainAaveAgent`: This contract acts as an intermediary for interacting with the Pool and CCIP. It functions as a smart contract wallet that holds user positions, enabling supply and borrowing of assets. The agent can send and receive cross-chain messages to other chains. Key functions include:
  - `supply`, `borrow`, `repay`, `withdraw`: Simply replay the operation to `MockPool` on same chain
  - `borrowToChain`: Initiates cross-chain borrowing, leveraging CCIP for asset transfer to a different chain.
  - `repayToChain`: Facilitates cross-chain repayment of loans using assets from a different chain.
  - `setAllowedBorrower`: Administrative function to manage cross-chain borrowing permissions.
  - Internal functions like `_borrowFromThisChain`, `_repayToThisChain`, and `_ccipReceive` handle cross-chain requests and message processing.

## Actual Operation Flow

Follow these steps for setting up and interacting with the contracts:

1. Setup: prepare wallet with Sepolia test ETH, Bsc Testnet BNB, and CCIP BnM (burn and mint) token on both testnets.
   - resource for getting CCIP BnM token: https://docs.chain.link/ccip/test-tokens/

2. Deployment: deploy the contracts to Sepolia and Bsc Testnet:
   ```
   npx hardhat run scripts/deploy.ts --network sepolia
   npx hardhat run scripts/deploy.ts --network bscTestnet
   ```
   update the deployed address in `scripts/data.ts`.

   sample deployment:
   - Sepolia
     - https://sepolia.etherscan.io/address/0x0EFEDB298eA02F9c096144dD187B35e0E15d37E2#code
     - https://sepolia.etherscan.io/address/0x43b7e7d9a59421d4871F9F1DA65bb940EE0c4A5f#code
   - Bsc Testnet
     - https://testnet.bscscan.com/address/0x795A7AADAEc49051a3C4524c6559fbbf450fd2A3#code
     - https://testnet.bscscan.com/address/0x5E0A13B8D8ce713FD3D6F5f2ad510e3778865209#code

3. Whitelist Borrowers: on Sepolia chain, set up the whitelist of borrower address of Bsc Testnet (the script takes address from `scripts/data.ts`).
   ```
   npx hardhat run scripts/setAllowedBorrower.ts --network sepolia
   ```
   sameple tx: https://sepolia.etherscan.io/tx/0x68c319e589246cc2aa30b0c2341ceab9eb6e72affba6d3f624c65fd8df4831c3

4. Supply Tokens: supply CCIP test token (CCIP-BnM, burn and mint) on Sepolia (other relatively trivial tests include borrow, repay, withdraw on same chain).
   ```
   npx hardhat run scripts/supply.ts --network sepolia
   ```
   This script will supply CCIP test token to `MockPool`, which will be borrowed later.

   Sample tx: https://sepolia.etherscan.io/tx/0xe34fe3919bdc7ea4af6f322454bb8a9fcaab37147344851233782ed9d91eb6d9

5. CCIP Funding: send some ETH to `CrossChainAaveAgent` contract on sepolia to pay for CCIP. (User can also send the ETH while calling the function below, via the `value` in the tx).

6. Initiate Borrow to Chain: call `borrowToChain` on Sepolia agent.
   ```
   npx hardhat run scripts/borrowToChain.ts --network sepolia
   ```
   This operation will borrow the asset on Sepolia, and bridge the asset over to Bsc Testnet. The script will output CCIP messag ID, which can be used to look up the status in CCIP Explorer: https://ccip.chain.link/. It shows the tx on src chain and dst chain.

   Sample message: https://ccip.chain.link/msg/0xd9cdeb9c2f3394321d497f6ec4efb7be1e1c967c3112a36657c108d0a91c2d43

   ![ccip-lending borrow to chain](https://github.com/hcheng826/ccip-lending-agent/assets/23033847/4b894ac7-cb54-43b1-8ff4-d8c6f629e446)

8. CCIP Funding: send some BNB to `CrossChainAaveAgent` contract on bscTestnet to pay for CCIP. (User can also send the BNB while calling the function below, via the `value` in the tx).

9. Repay to Chain: call `repayToChain` on Bsc Testnet to repay debt on Sepolia `MockPool`.
   ```
   npx hardhat run scripts/repayToChain.ts --network bscTestnet
   ```
   This operation will send the asset from Bsc Testnet to Sepolia, picked up by the Agent, and the Agent will repay the debit with the amount.

   Sample message: https://ccip.chain.link/msg/0x68a6c7efbab4cd4d9f318dbc581a2117b698676ae6244105babac8f1107b9415

   ![ccip-lending repay to chain](https://github.com/hcheng826/ccip-lending-agent/assets/23033847/2cdf1e93-6902-45da-a76d-b6db532ccafc)

11.  Borrow from Chain: call `borrowFromChain` on bscTestnet to borrow from Sepolia.
      ```
      npx hardhat run scripts/borrowFromChain.ts --network bscTestnet
      ```

      This operation involves 2 cross-chain message bridging. The borrowing request starts from Bsc Testnet. Agent on Sepolia receives the cross-chain message, verify the sender is whitelisted, and send the borrowing amount back to Bsc Testnet.

      Sample message:
      - Bsc Testnet to Sepolia: https://ccip.chain.link/msg/0x68e25edb3e28dc6d22ba4543dba488e74166b95861b929a01cfbd34fbc84c022
      - Sepoliat to Bsc Testnet: https://ccip.chain.link/msg/0xabed2cf43e007f25716c1c98bd117ebcd18d2117c0733284eef3b1cd53a2e8ff
   
     ![ccip-lending borrow from chain](https://github.com/hcheng826/ccip-lending-agent/assets/23033847/588c6aca-b169-481d-91c2-55effe4b2cc7)


## Future Exploration
- Liquidation and Interest Earning: Apply liquidation management and interest-earning functionalities for supplied assets, improving risk mitigation and user incentives.

- Multi-Chain Borrowing Capability: Enabling borrowing from various blockchains in one transaction, optimizing users' financial strategies by leveraging the best rates across networks.

- Comprehensive Unit Testing: Developing unit tests, especially for CCIP functionalities, to ensure system reliability and security.

- Cross-Chain Collateral Management: Allowing users to utilize their assets on different blockchains as collateral, increasing borrowing power and capital efficiency.

- Governance and Decentralization Mechanisms: Introducing community-driven governance features for protocol decisions and upgrades, embracing the DeFi ethos of decentralization.

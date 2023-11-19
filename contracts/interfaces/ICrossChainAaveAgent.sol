// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IPool} from "./IPool.sol";
import {IERC20} from "./IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

interface ICrossChainAaveAgent {
    enum AaveOp {
        BORROW,
        REPAY
    }

    struct AaveOpParams {
        address asset;
        uint256 amount;
        uint256 interestRateMode;
        address onBehalfOf;
        uint16 referralCode;
    }

    struct AaveOpData {
        AaveOp op;
        AaveOpParams params;
    }

    event MessageSent(bytes32 messageId);
    event MessageReceived(bytes32 messageId);

    error CallerNotOwner();
    error InvalidAaveOp(AaveOp op);
    error CrossChainBorrowerNotAllowed(uint64 chainSelector, address sender);
    error InputArrayLengthMismatch();

    /// @notice Change to new owner
    /// @param newOwner the address of new owner
    /// @dev Only the owner can call this function.
    function setOwner(address newOwner) external;

    /// @notice Sets allowed borrowers for cross-chain operations.
    /// @param chainSelectors An array of chain selectors.
    /// @param senders An array of arrays, each containing addresses of senders on corresponding chains.
    /// @param values An array of arrays of booleans, indicating if a sender is allowed on the corresponding chain.
    /// @dev Only the owner can call this function.
    /// @dev Reverts if the lengths of the input arrays do not match.
    function setAllowedBorrower(
        uint64[] calldata chainSelectors,
        address[][] calldata senders,
        bool[][] calldata values
    ) external;

    /// @notice Borrows an asset from the Aave pool.
    /// @param opParam Parameters for the borrow operation.
    /// @dev Only the owner can call this function.
    function borrow(AaveOpParams calldata opParam) external;

    /// @notice Supplies an asset to the Aave pool.
    /// @param opParam Parameters for the supply operation
    function supply(AaveOpParams calldata opParam) external;

    /// @notice Repays a borrowed asset to the Aave pool.
    /// @param opParam Parameters for the repayment operation.
    function repay(AaveOpParams calldata opParam) external;

    /// @notice Withdraws an asset from the Aave pool.
    /// @param asset The address of the asset to withdraw.
    /// @param amount The amount of the asset to withdraw.
    /// @param to The address to which the asset will be sent.
    /// @dev Only the owner can call this function.
    function withdraw(address asset, uint256 amount, address to) external;

    /// @notice Withdraws an asset from the agent contract.
    /// @param asset The address of the asset to withdraw (use address(0) for ETH).
    /// @param amount The amount of the asset to withdraw.
    /// @param to The address to which the asset will be sent.
    /// @dev Only the owner can call this function.
    function withdrawFromAgent(
        address asset,
        uint256 amount,
        address to
    ) external;

    /// @notice Initiates a cross-chain borrow operation.
    /// @param opParam Parameters for the borrow operation.
    /// @param dstChainSelector The selector of the destination chain.
    /// @param dstChainReceiver The address of the receiver on the destination chain.
    /// @dev Only the owner can call this function.
    function borrowToChain(
        AaveOpParams calldata opParam,
        uint64 dstChainSelector,
        address dstChainReceiver
    ) external payable;

    /// @notice Initiates a cross-chain borrow request to another chain.
    /// @param opParam Parameters for the borrow operation.
    /// @param dstChainAgent The agent on the destination chain to handle the request.
    /// @param dstChainSelector The selector of the destination chain.
    /// @dev Only the owner can call this function.
    function borrowFromChain(
        AaveOpParams calldata opParam,
        address dstChainAgent,
        uint64 dstChainSelector
    ) external payable;

    /// @notice Initiates a cross-chain repay operation.
    /// @param opParam Parameters for the repayment operation.
    /// @param dstChainAgent The agent on the destination chain to handle the repay.
    /// @param dstChainSelector The selector of the destination chain.
    /// @param srcChainAsset The asset on the source chain used for repayment.
    function repayToChain(
        AaveOpParams calldata opParam, // dst chain token address
        address dstChainAgent,
        uint64 dstChainSelector,
        address srcChainAsset
    ) external payable;

    receive() external payable;
}

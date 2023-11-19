// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IPool} from "./interfaces/IPool.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {ICrossChainAaveAgent} from "./interfaces/ICrossChainAaveAgent.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract CrossChainAaveAgent is ICrossChainAaveAgent, CCIPReceiver {
    IPool immutable pool;
    address public owner;
    mapping(uint64 => mapping(address => bool))
        public crossChainBorrowerAllowList;

    constructor(IPool _pool, address _ccipRouter) CCIPReceiver(_ccipRouter) {
        pool = _pool;
        owner = msg.sender;
    }

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert CallerNotOwner();
        }
        _;
    }

    /// @notice Change to new owner
    /// @param newOwner the address of new owner
    /// @dev Only the owner can call this function.
    function setOwner(address newOwner) external onlyOwner {
        owner = newOwner;
    }

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
    ) external onlyOwner {
        if (
            chainSelectors.length != senders.length ||
            senders.length != values.length
        ) {
            revert InputArrayLengthMismatch();
        }

        for (uint256 i; i < chainSelectors.length; ) {
            if (senders[i].length != values[i].length) {
                revert InputArrayLengthMismatch();
            }
            for (uint256 j; j < senders[i].length; ) {
                crossChainBorrowerAllowList[chainSelectors[i]][
                    senders[i][j]
                ] = values[i][j];
                unchecked {
                    ++j;
                }
            }
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Borrows an asset from the Aave pool.
    /// @param opParam Parameters for the borrow operation.
    /// @dev Only the owner can call this function.
    function borrow(AaveOpParams calldata opParam) external onlyOwner {
        address asset = opParam.asset;
        uint256 amount = opParam.amount;
        pool.borrow(
            asset,
            amount,
            opParam.interestRateMode,
            opParam.referralCode,
            opParam.onBehalfOf
        );
        IERC20(asset).transfer(msg.sender, amount);
    }

    /// @notice Supplies an asset to the Aave pool.
    /// @param opParam Parameters for the supply operation
    function supply(AaveOpParams calldata opParam) external {
        address asset = opParam.asset;
        uint256 amount = opParam.amount;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(pool), amount);
        pool.supply(asset, amount, opParam.onBehalfOf, opParam.referralCode);
    }

    /// @notice Repays a borrowed asset to the Aave pool.
    /// @param opParam Parameters for the repayment operation.
    function repay(AaveOpParams calldata opParam) external {
        address asset = opParam.asset;
        uint256 amount = opParam.amount;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(pool), amount);
        pool.repay(asset, amount, opParam.interestRateMode, opParam.onBehalfOf);
    }

    /// @notice Withdraws an asset from the Aave pool.
    /// @param asset The address of the asset to withdraw.
    /// @param amount The amount of the asset to withdraw.
    /// @param to The address to which the asset will be sent.
    /// @dev Only the owner can call this function.
    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external onlyOwner {
        pool.withdraw(asset, amount, to);
    }

    /// @notice Withdraws an asset from the agent contract.
    /// @param asset The address of the asset to withdraw (use address(0) for ETH).
    /// @param amount The amount of the asset to withdraw.
    /// @param to The address to which the asset will be sent.
    /// @dev Only the owner can call this function.
    function withdrawFromAgent(
        address asset,
        uint256 amount,
        address to
    ) external onlyOwner {
        if (asset == address(0)) {
            (bool success, ) = payable(to).call{value: amount}("");
            if (!success) {
                revert();
            }
        }
        IERC20(asset).transfer(to, amount);
    }

    /// @notice Initiates a cross-chain borrow operation.
    /// @param opParam Parameters for the borrow operation.
    /// @param dstChainSelector The selector of the destination chain.
    /// @param dstChainReceiver The address of the receiver on the destination chain.
    /// @dev Only the owner can call this function.
    function borrowToChain(
        AaveOpParams calldata opParam,
        uint64 dstChainSelector,
        address dstChainReceiver
    ) external payable onlyOwner {
        _borrowToChain(opParam, dstChainSelector, dstChainReceiver);
    }

    /// @notice Initiates a cross-chain borrow request to another chain.
    /// @param opParam Parameters for the borrow operation.
    /// @param dstChainAgent The agent on the destination chain to handle the request.
    /// @param dstChainSelector The selector of the destination chain.
    /// @dev Only the owner can call this function.
    function borrowFromChain(
        AaveOpParams calldata opParam,
        address dstChainAgent,
        uint64 dstChainSelector
    ) external payable onlyOwner {
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(dstChainAgent),
            data: abi.encode(AaveOp.BORROW, opParam),
            tokenAmounts: new Client.EVMTokenAmount[](0),
            extraArgs: Client._argsToBytes(
                Client.EVMExtraArgsV1({gasLimit: 500_000, strict: false})
            ),
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(dstChainSelector, message);

        bytes32 messageId = IRouterClient(i_router).ccipSend{value: fee}(
            dstChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

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
    ) external payable {
        uint256 amount = opParam.amount;
        IERC20(srcChainAsset).transferFrom(msg.sender, address(this), amount);
        IERC20(srcChainAsset).approve(i_router, amount);

        Client.EVMTokenAmount[]
            memory tokenAmount = new Client.EVMTokenAmount[](1);
        tokenAmount[0] = Client.EVMTokenAmount({
            token: srcChainAsset,
            amount: amount
        });

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(dstChainAgent),
            data: abi.encode(AaveOp.REPAY, opParam),
            tokenAmounts: tokenAmount,
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(dstChainSelector, message);

        bytes32 messageId = IRouterClient(i_router).ccipSend{value: fee}(
            dstChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    /// @notice Internal function to initiate cross-chain borrow operation.
    /// @param opParam Parameters for the borrow operation.
    /// @param dstChainSelector The selector of the destination chain.
    /// @param dstChainReceiver The address of the receiver on the destination chain.
    function _borrowToChain(
        AaveOpParams memory opParam,
        uint64 dstChainSelector,
        address dstChainReceiver
    ) internal {
        // borrow from Aave pool
        address asset = opParam.asset;
        uint256 amount = opParam.amount;
        pool.borrow(
            asset,
            amount,
            opParam.interestRateMode,
            opParam.referralCode,
            opParam.onBehalfOf
        );

        // bridge to dst chain via ccip router
        IERC20(asset).approve(i_router, amount);
        Client.EVMTokenAmount[]
            memory tokenAmount = new Client.EVMTokenAmount[](1);
        tokenAmount[0] = Client.EVMTokenAmount({token: asset, amount: amount});

        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(dstChainReceiver),
            data: "",
            tokenAmounts: tokenAmount,
            extraArgs: "",
            feeToken: address(0)
        });

        uint256 fee = IRouterClient(i_router).getFee(dstChainSelector, message);

        bytes32 messageId = IRouterClient(i_router).ccipSend{value: fee}(
            dstChainSelector,
            message
        );

        emit MessageSent(messageId);
    }

    /// @notice Internal function to handle borrow requests from other chains.
    /// @param params Borrow operation parameters.
    /// @param sender The address initiating the borrow on the source chain.
    /// @param chainSelector The selector of the chain from which the request originated.
    /// @dev Checks if the sender is allowed to borrow and initiates cross-chain borrow if so.
    function _borrowFromThisChain(
        AaveOpParams memory params,
        address sender,
        uint64 chainSelector
    ) internal {
        if (!crossChainBorrowerAllowList[chainSelector][sender]) {
            revert CrossChainBorrowerNotAllowed(chainSelector, sender);
        }
        _borrowToChain(params, chainSelector, sender);
    }

    /// @notice Internal function to handle repay requests from other chains.
    /// @param params Repay operation parameters.
    /// @dev Assumes the asset for repayment has been transferred via CCIP.
    function _repayToThisChain(AaveOpParams memory params) internal {
        address asset = params.asset;
        uint256 amount = params.amount;
        IERC20(asset).approve(address(pool), amount);
        pool.repay(asset, amount, params.interestRateMode, params.onBehalfOf);
    }

    /// @notice Override of CCIPReceiver's _ccipReceive function to handle incoming cross-chain messages.
    /// @param message The incoming message from another chain.
    /// @dev Decodes and processes the message based on the Aave operation type.
    function _ccipReceive(
        Client.Any2EVMMessage memory message
    ) internal override {
        address sender = abi.decode(message.sender, (address));
        if (keccak256(message.data) != keccak256(bytes(""))) {
            AaveOpData memory opData = abi.decode(message.data, (AaveOpData));

            if (opData.op == AaveOp.BORROW) {
                _borrowFromThisChain(
                    opData.params,
                    sender,
                    message.sourceChainSelector
                );
            } else if (opData.op == AaveOp.REPAY) {
                _repayToThisChain(opData.params);
            } else {
                revert InvalidAaveOp(opData.op);
            }
        }

        emit MessageReceived(message.messageId);
    }

    receive() external payable {}
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IPool} from "./interfaces/IPool.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";

contract CrossChainAaveAgent is CCIPReceiver {
    IPool immutable pool;
    address immutable owner;
    mapping(uint64 => mapping(address => bool))
        public crossChainBorrowerAllowList;

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

    constructor(IPool _pool, address _ccipRouter) CCIPReceiver(_ccipRouter) {
        pool = _pool;
        owner = msg.sender;
    }

    event MessageSent(bytes32 messageId);
    event MessageReceived(bytes32 messageId);

    error CallerNotOwner();
    error InvalidAaveOp(AaveOp op);
    error CrossChainBorrowerNotAllowed(uint64 chainSelector, address sender);
    error InputArrayLengthMismatch();

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert CallerNotOwner();
        }
        _;
    }

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

    function supply(AaveOpParams calldata opParam) external {
        address asset = opParam.asset;
        uint256 amount = opParam.amount;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(pool), amount);
        pool.supply(asset, amount, opParam.onBehalfOf, opParam.referralCode);
    }

    function repay(AaveOpParams calldata opParam) external {
        address asset = opParam.asset;
        uint256 amount = opParam.amount;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        IERC20(asset).approve(address(pool), amount);
        pool.repay(asset, amount, opParam.interestRateMode, opParam.onBehalfOf);
    }

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external onlyOwner {
        pool.withdraw(asset, amount, to);
    }

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

    function borrowToChain(
        AaveOpParams calldata opParam,
        uint64 dstChainSelector,
        address dstChainReceiver
    ) external payable onlyOwner {
        _borrowToChain(opParam, dstChainSelector, dstChainReceiver);
    }

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

    // called by ccip
    function _repayToThisChain(AaveOpParams memory params) internal {
        // assume the asset has been trasferred by CCIP
        address asset = params.asset;
        uint256 amount = params.amount;
        IERC20(asset).approve(address(pool), amount);
        pool.repay(asset, amount, params.interestRateMode, params.onBehalfOf);
    }

    // called by ccip
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IERC20} from "./interfaces/IERC20.sol";

// ignore health factor, liquidation, reentrancy, etc
contract MockPool {
    mapping(address => mapping(address => uint256)) deposits;
    mapping(address => mapping(address => uint256)) debts;

    function borrow(
        address asset,
        uint256 amount,
        uint256,
        uint16,
        address
    ) external {
        debts[msg.sender][asset] += amount;
        IERC20(asset).transfer(msg.sender, amount);
    }

    function supply(
        address asset,
        uint256 amount,
        address,
        uint16
    ) external {
        deposits[msg.sender][asset] += amount;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(address asset, uint256 amount, address to) external returns (uint256) {
        if (amount > deposits[msg.sender][asset]) {
            amount = deposits[msg.sender][asset];
        }
        deposits[msg.sender][asset] -= amount;
        IERC20(asset).transfer(to, amount);
        return amount;
    }

    function repay(
        address asset,
        uint256 amount,
        uint256,
        address
    ) external returns (uint256) {
        if (amount > debts[msg.sender][asset]) {
            amount = debts[msg.sender][asset];
        }
        debts[msg.sender][asset] -= amount;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        return amount;
    }
}

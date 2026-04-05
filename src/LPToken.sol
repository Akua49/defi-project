// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract LPToken {

    string public name = "LP Token";
    string public symbol = "LPT";
    uint8 public decimals = 18;

    uint public totalSupply;

    mapping(address => uint) public balanceOf;

    function mint(address to, uint amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function burn(address from, uint amount) external {
        require(balanceOf[from] >= amount, "Not enough LP");

        balanceOf[from] -= amount;
        totalSupply -= amount;
    }
}
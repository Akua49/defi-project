// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transferFrom(address from, address to, uint amount) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
}

contract LendingPool {

    IERC20 public token;

    mapping(address => uint) public collateral;
    mapping(address => uint) public debt;

    uint public constant LTV = 75; // 75%

    constructor(address _token) {
        token = IERC20(_token);
    }


    function deposit(uint amount) public {
        require(amount > 0, "Zero amount");

        token.transferFrom(msg.sender, address(this), amount);
        collateral[msg.sender] += amount;
    }


    function borrow(uint amount) public {
        accrueInterest(msg.sender);
        require(amount > 0, "Zero amount");

        uint maxBorrow = (collateral[msg.sender] * LTV) / 100;

        require(debt[msg.sender] + amount <= maxBorrow, "Exceeds LTV");

        debt[msg.sender] += amount;
        token.transfer(msg.sender, amount);
    }


    function repay(uint amount) public {
        accrueInterest(msg.sender);
        require(amount > 0, "Zero amount");

        token.transferFrom(msg.sender, address(this), amount);
        debt[msg.sender] -= amount;
    }


    function withdraw(uint amount) public {
        accrueInterest(msg.sender);
        require(amount > 0, "Zero amount");
        require(collateral[msg.sender] >= amount, "Not enough collateral");

        uint remainingCollateral = collateral[msg.sender] - amount;
        uint maxBorrow = (remainingCollateral * LTV) / 100;

        require(debt[msg.sender] <= maxBorrow, "Would break health");

        collateral[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
    }

    // health factor = collateral / debt
    
    function getHealthFactor(address user) public view returns (uint) {
        if (debt[user] == 0) return type(uint).max;
        
        return (collateral[user] * 100) / debt[user];
    }


    function liquidate(address user) public {
        require(getHealthFactor(user) < 100, "Position is safe");
        
        uint userDebt = debt[user];
        uint userCollateral = collateral[user];
        
        token.transferFrom(msg.sender, address(this), userDebt);
        token.transfer(msg.sender, userCollateral);
        
        debt[user] = 0;
        collateral[user] = 0;
    }

    mapping(address => uint) public lastUpdate;
    uint public interestRate = 5; // 5% годовых


    function accrueInterest(address user) internal {
        uint timePassed = block.timestamp - lastUpdate[user];
        
        if (timePassed > 0 && debt[user] > 0) {
            uint interest = (debt[user] * interestRate * timePassed) / (365 days * 100);
            debt[user] += interest;
        }
        
        lastUpdate[user] = block.timestamp;
    }
}
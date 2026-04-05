// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LendingPool.sol";

// ===== MOCK TOKEN =====
contract MockToken {
    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    function mint(address to, uint amount) public {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint amount) public {
        allowance[msg.sender][spender] = amount;
    }

    function transfer(address to, uint amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "no balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint amount) public returns (bool) {
        require(balanceOf[from] >= amount, "no balance");
        require(allowance[from][msg.sender] >= amount, "no allowance");

        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// ===== TEST CONTRACT =====
contract LendingTest is Test {

    LendingPool pool;
    MockToken token;

    address user = address(1);
    address liquidator = address(2);

    function setUp() public {
        token = new MockToken();
        pool = new LendingPool(address(token));

        token.mint(user, 1000 ether);
        token.mint(liquidator, 1000 ether);

        vm.startPrank(user);
        token.approve(address(pool), type(uint).max);
        vm.stopPrank();

        vm.startPrank(liquidator);
        token.approve(address(pool), type(uint).max);
        vm.stopPrank();
    }

    // ===== DEPOSIT =====
    function testDeposit() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        vm.stopPrank();

        assertEq(pool.collateral(user), 100 ether);
    }

    // ===== BORROW =====
    function testBorrowWithinLTV() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        vm.stopPrank();

        assertEq(pool.debt(user), 50 ether);
    }

    function testBorrowExceedsLTV() public {
        vm.startPrank(user);
        pool.deposit(100 ether);

        vm.expectRevert();
        pool.borrow(80 ether);
        vm.stopPrank();
    }

    // ===== REPAY =====
    function testRepayFull() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(50 ether);
        vm.stopPrank();

        assertEq(pool.debt(user), 0);
    }

    function testRepayPartial() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(20 ether);
        vm.stopPrank();

        assertEq(pool.debt(user), 30 ether);
    }

    // ===== WITHDRAW =====
    function testWithdraw() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.withdraw(50 ether);
        vm.stopPrank();

        assertEq(pool.collateral(user), 50 ether);
    }

    function testWithdrawWithDebtShouldFail() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(75 ether);

        vm.expectRevert();
        pool.withdraw(50 ether);
        vm.stopPrank();
    }

    // ===== LIQUIDATION =====
    function testLiquidation() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(70 ether);
        vm.stopPrank();
        
        vm.startPrank(liquidator);
        
        vm.expectRevert("Position is safe");
        pool.liquidate(user);
        
        vm.stopPrank();
    }

    // ===== INTEREST =====
    function testInterestAccrual() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);

        vm.warp(block.timestamp + 365 days);

        pool.repay(1 ether);// trigger interest update
        vm.stopPrank();

        assertTrue(pool.debt(user) > 50 ether);
    }

    // ===== EDGE CASES =====
    function testBorrowWithoutCollateral() public {
        vm.startPrank(user);

        vm.expectRevert();
        pool.borrow(10 ether);
        vm.stopPrank();
    }

    function testWithdrawAllAfterRepay() public {
        vm.startPrank(user);
        pool.deposit(100 ether);
        pool.borrow(50 ether);
        pool.repay(50 ether);
        pool.withdraw(100 ether);
        vm.stopPrank();

        assertEq(pool.collateral(user), 0);
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;

    function setUp() public {
        token = new MyToken();
    }

    function testMint() public {
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);
    }

    function testTransfer() public {
        token.mint(address(this), 100);
        token.transfer(address(1), 50);
        assertEq(token.balanceOf(address(1)), 50);
    }

    function testApprove() public {
        token.approve(address(1), 100);
        assertEq(token.allowance(address(this), address(1)), 100);
    }

    function testTransferFrom() public {
        token.mint(address(this), 100);
        token.approve(address(this), 50);
        token.transferFrom(address(this), address(2), 50);

        assertEq(token.balanceOf(address(2)), 50);
    }

    function testRevertTransferNotEnoughBalance() public {
        vm.expectRevert();
        token.transfer(address(1), 100);
    }

    function testRevertTransferFromWithoutApproval() public {
        token.mint(address(this), 100);

        vm.expectRevert();
        token.transferFrom(address(this), address(1), 50);
    }

    function testFuzzTransfer(uint amount) public {
        vm.assume(amount > 0 && amount < 1e18);

        token.mint(address(this), amount);
        token.transfer(address(1), amount);

        assertEq(token.balanceOf(address(1)), amount);
    }

    function testBalanceAfterMint() public {
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);
    }
    
    function testBalanceAfterMint2() public {
        token.mint(address(this), 100);
        assertEq(token.balanceOf(address(this)), 100);
    }

    function testApproveAndAllowance() public {
        token.approve(address(1), 200);
        assertEq(token.allowance(address(this), address(1)), 200);
    }
    
    function testTransferReducesSenderBalance() public {
        token.mint(address(this), 100);
        token.transfer(address(1), 40);
        assertEq(token.balanceOf(address(this)), 60);
    }
}
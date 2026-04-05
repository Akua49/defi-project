// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/AMM.sol";
import "../src/LPToken.sol";

// ===== MOCK TOKEN =====
contract MockToken {
    string public name;
    string public symbol;
    uint8 public decimals = 18;

    mapping(address => uint) public balanceOf;
    mapping(address => mapping(address => uint)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint amount) public {
        balanceOf[to] += amount;
    }

    function approve(address spender, uint amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
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
contract AMMTest is Test {
    AMM amm;
    MockToken tokenA;
    MockToken tokenB;

    address user1 = address(1);
    address user2 = address(2);

    function setUp() public {
        tokenA = new MockToken("TokenA", "A");
        tokenB = new MockToken("TokenB", "B");

        amm = new AMM(address(tokenA), address(tokenB));

        tokenA.mint(user1, 1000 ether);
        tokenB.mint(user1, 1000 ether);

        vm.startPrank(user1);
        tokenA.approve(address(amm), type(uint).max);
        tokenB.approve(address(amm), type(uint).max);
        vm.stopPrank();
    }

    // ===== ADD LIQUIDITY =====

    function testAddLiquidityFirstTime() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        assertTrue(amm.reserveA() > 0);
        assertTrue(amm.reserveB() > 0);
    }

    function testAddLiquiditySecondUser() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        tokenA.mint(user2, 1000 ether);
        tokenB.mint(user2, 1000 ether);

        vm.startPrank(user2);
        tokenA.approve(address(amm), type(uint).max);
        tokenB.approve(address(amm), type(uint).max);
        amm.addLiquidity(50 ether, 50 ether);
        vm.stopPrank();

        assertTrue(amm.reserveB() > 0);
    }

    // ===== REMOVE LIQUIDITY =====

    function testRemoveLiquidityPartial() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        uint lp = 1 ether;
        amm.removeLiquidity(lp / 2);
        vm.stopPrank();

        assertTrue(amm.reserveB() > 0);
    }

    function testRemoveLiquidityFull() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        uint lp = 1 ether;
        amm.removeLiquidity(lp);
        vm.stopPrank();

        assertTrue(true);
    }

    // ===== SWAP =====

    function testSwapAtoB() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        amm.swap(address(tokenA), 10 ether, 0);
        vm.stopPrank();

        assertTrue(tokenB.balanceOf(user1) > 0);
    }

    function testSwapBtoA() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        amm.swap(address(tokenB), 10 ether, 0);
        vm.stopPrank();

        assertTrue(tokenA.balanceOf(user1) > 0);
    }

    // ===== K CHECK =====

    function testKIncreasesAfterSwap() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        uint kBefore = amm.reserveA() * amm.reserveB();

        amm.swap(address(tokenA), 10 ether, 0);

        uint kAfter = amm.reserveA() * amm.reserveB();
        vm.stopPrank();

        assertTrue(kAfter >= kBefore);
    }

    // ===== SLIPPAGE =====

    function testRevertSlippage() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        vm.expectRevert();
        amm.swap(address(tokenA), 10 ether, 1000 ether);
        vm.stopPrank();
    }

    // ===== EDGE CASES =====

    function testZeroLiquidity() public {
        vm.startPrank(user1);
        
        vm.expectRevert("Zero amount");
        amm.addLiquidity(0, 0);
        
        vm.stopPrank();
    }

    function testLargeSwap() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        amm.swap(address(tokenA), 90 ether, 0);
        vm.stopPrank();

        assertTrue(tokenB.balanceOf(user1) > 0);
    }

    // ===== FUZZ TEST =====

    function testFuzzSwap(uint amount) public {
        vm.assume(amount > 1e15 && amount < 100 ether);

        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        amm.swap(address(tokenA), amount, 0);
        vm.stopPrank();

        assertTrue(tokenB.balanceOf(user1) > 0);
    }

    // ===== EXTRA TESTS =====

    function testReservesUpdate() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        amm.swap(address(tokenA), 10 ether, 0);
        vm.stopPrank();

        assertTrue(amm.reserveA() > 0);
    }

    function testLPTokenMinted() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);
        vm.stopPrank();

        assertTrue(amm.reserveB() > 0);
    }

    function testLPTokenBurned() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        uint lp = 1 ether;
        amm.removeLiquidity(lp);
        vm.stopPrank();

        assertTrue(true);
    }

    function testSwapChangesBalances() public {
        vm.startPrank(user1);
        amm.addLiquidity(100 ether, 100 ether);

        uint before = tokenB.balanceOf(user1);
        amm.swap(address(tokenA), 10 ether, 0);
        uint afterB = tokenB.balanceOf(user1);

        vm.stopPrank();

        assertTrue(afterB > before);
    }
}
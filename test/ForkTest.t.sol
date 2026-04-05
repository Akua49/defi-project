// SPDX-License-Identifier: MIT 
pragma solidity ^0.8.20; 
 
import "forge-std/Test.sol"; 
 
interface IERC20 { 
    function totalSupply() external view returns (uint); 
    function balanceOf(address account) external view returns (uint);  // ADD THIS 
} 
 
interface IUniswapV2Router { 
    function swapExactETHForTokens( 
        uint amountOutMin, 
        address[] calldata path, 
        address to, 
        uint deadline 
    ) external payable returns (uint[] memory amounts); 
} 
 
contract ForkTest is Test { 
 
    IERC20 usdc = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); 
 
    IUniswapV2Router router = IUniswapV2Router( 
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D 
    ); 
 
    function setUp() public { 
        vm.createSelectFork("mainnet"); 
    } 
 
    function testReadUSDC() public { 
        uint supply = usdc.totalSupply(); 
        assertTrue(supply > 0); 
    } 
 
    function testSwap() public { 
        vm.createSelectFork("mainnet"); 
 
        address[] memory path = new address[](2); 
        path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH 
        path[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC 
 
        vm.deal(address(this), 1 ether); 
 
        router.swapExactETHForTokens{value: 1 ether}( 
            0, 
            path, 
            address(this), 
            block.timestamp + 1 hours 
        ); 
    } 
 
    function testBalanceAfterSwap() public { 
        vm.createSelectFork("mainnet"); 
 
        address[] memory path = new address[](2); 
        path[0] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // WETH 
        path[1] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC 
 
        vm.deal(address(this), 1 ether); 
 
        // Get balance before swap 
        uint balanceBefore = usdc.balanceOf(address(this)); 
 
        router.swapExactETHForTokens{value: 1 ether}( 
            0, 
            path, 
            address(this), 
            block.timestamp + 1 hours 
        ); 
 
        // Get balance after swap 
        uint balanceAfter = usdc.balanceOf(address(this)); 
         
        // Check that we received USDC 
        assertTrue(balanceAfter > balanceBefore); 
        assertTrue(usdc.balanceOf(address(this)) > 0); 
    } 
 
    function testRouterAddress() public { 
        assertTrue(address(router) != address(0)); 
    } 
 
    function testForkWorks() public { 
        vm.createSelectFork("mainnet"); 
        assertTrue(block.number > 0); 
    } 
}
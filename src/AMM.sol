// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./LPToken.sol";

interface IERC20 {
    function transferFrom(address from, address to, uint amount) external returns (bool);
    function transfer(address to, uint amount) external returns (bool);
    function balanceOf(address account) external view returns (uint);
}

contract AMM {

    address public tokenA;
    address public tokenB;

    uint public reserveA;
    uint public reserveB;

    LPToken public lpToken;

    event LiquidityAdded(address user, uint amountA, uint amountB);
    event LiquidityRemoved(address user, uint amountA, uint amountB);
    event Swap(address user, address tokenIn, uint amountIn, uint amountOut);

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != _tokenB, "Same token");

        tokenA = _tokenA;
        tokenB = _tokenB;

        lpToken = new LPToken();
    }

    // ===== ADD LIQUIDITY =====
    function addLiquidity(uint amountA, uint amountB) public {
        require(amountA > 0 && amountB > 0, "Zero amount");

        IERC20(tokenA).transferFrom(msg.sender, address(this), amountA);
        IERC20(tokenB).transferFrom(msg.sender, address(this), amountB);

        uint liquidity;

        if (lpToken.totalSupply() == 0) {
            // first provider
            liquidity = sqrt(amountA * amountB);
        } else {
            // proportional liquidity
            uint liquidityA = (amountA * lpToken.totalSupply()) / reserveA;
            uint liquidityB = (amountB * lpToken.totalSupply()) / reserveB;
            liquidity = min(liquidityA, liquidityB);
        }

        require(liquidity > 0, "Insufficient liquidity minted");

        lpToken.mint(msg.sender, liquidity);

        reserveA += amountA;
        reserveB += amountB;

        emit LiquidityAdded(msg.sender, amountA, amountB);
    }

    // ===== REMOVE LIQUIDITY =====
    function removeLiquidity(uint lpAmount) public {
        require(lpAmount > 0, "Zero LP");
        require(lpToken.balanceOf(msg.sender) >= lpAmount, "Not enough LP");

        uint totalSupply = lpToken.totalSupply();

        uint amountA = (lpAmount * reserveA) / totalSupply;
        uint amountB = (lpAmount * reserveB) / totalSupply;

        lpToken.burn(msg.sender, lpAmount);

        reserveA -= amountA;
        reserveB -= amountB;

        IERC20(tokenA).transfer(msg.sender, amountA);
        IERC20(tokenB).transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }

    // ===== SWAP =====
    function swap(address tokenIn, uint amountIn, uint minAmountOut) public {
        require(amountIn > 0, "Zero input");
        require(tokenIn == tokenA || tokenIn == tokenB, "Invalid token");
        require(reserveA > 0 && reserveB > 0, "No liquidity");

        bool isA = tokenIn == tokenA;

        (uint reserveIn, uint reserveOut) = isA
            ? (reserveA, reserveB)
            : (reserveB, reserveA);

        uint amountOut = getAmountOut(amountIn, reserveIn, reserveOut);

        require(amountOut >= minAmountOut, "Slippage");

        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);

        address tokenOut = isA ? tokenB : tokenA;
        IERC20(tokenOut).transfer(msg.sender, amountOut);

        if (isA) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        emit Swap(msg.sender, tokenIn, amountIn, amountOut);
    }

    // ===== FORMULA =====
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint) {
        require(amountIn > 0, "Zero input");
        require(reserveIn > 0 && reserveOut > 0, "No liquidity");

        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;

        return numerator / denominator;
    }

    // ===== HELPERS =====
    function min(uint x, uint y) private pure returns (uint) {
        return x < y ? x : y;
    }

    function sqrt(uint y) private pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
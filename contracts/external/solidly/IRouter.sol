// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IRouter {
  function pairFor(
    address tokenA,
    address tokenB,
    bool stable
  ) external view returns (address pair);

  function removeLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint256 liquidity,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  ) external returns (uint256 amountA, uint256 amountB);

  function addLiquidity(
    address tokenA,
    address tokenB,
    bool stable,
    uint256 amountADesired,
    uint256 amountBDesired,
    uint256 amountAMin,
    uint256 amountBMin,
    address to,
    uint256 deadline
  )
    external
    returns (
      uint256 amountA,
      uint256 amountB,
      uint256 liquidity
    );
}

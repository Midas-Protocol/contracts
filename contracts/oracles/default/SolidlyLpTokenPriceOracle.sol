// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../../external/compound/IPriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";

import "../../external/solidly/IPair.sol";

import "../BasePriceOracle.sol";
import { UniswapLikeLpTokenPriceOracle } from "./UniswapLikeLpTokenPriceOracle.sol";

/**
 * @title SolidlyLpTokenPriceOracle
 * @author Carlo Mazzaferro, David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice SolidlyLpTokenPriceOracle is a price oracle for Solidly LP tokens.
 * @dev Implements the `PriceOracle` interface used by Fuse pools (and Compound v2).
 */
contract SolidlyLpTokenPriceOracle is UniswapLikeLpTokenPriceOracle {
  /**
   * @dev Fetches the fair LP token/ETH price from Uniswap, with 18 decimals of precision.
   */
  constructor(address _wtoken) UniswapLikeLpTokenPriceOracle(_wtoken) {}

  function _price(address token) internal view virtual override returns (uint256) {
    IPair pair = IPair(token);
    uint256 totalSupply = pair.totalSupply();
    if (totalSupply == 0) return 0;
    (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
    address token0 = pair.token0();
    address token1 = pair.token1();

    // Get fair price of non-WETH token (underlying the pair) in terms of ETH
    uint256 token0FairPrice = token0 == wtoken
      ? 1e18
      : (BasePriceOracle(msg.sender).price(token0) * 1e18) / (10**uint256(ERC20Upgradeable(token0).decimals()));
    uint256 token1FairPrice = token1 == wtoken
      ? 1e18
      : (BasePriceOracle(msg.sender).price(token1) * 1e18) / (10**uint256(ERC20Upgradeable(token1).decimals()));

    // Implementation from https://github.com/AlphaFinanceLab/homora-v2/blob/e643392d582c81f6695136971cff4b685dcd2859/contracts/oracle/UniswapV2Oracle.sol#L18
    uint256 sqrtK = (sqrt(reserve0 * reserve1) * (2**112)) / totalSupply;
    return (((sqrtK * 2 * sqrt(token0FairPrice)) / (2**56)) * sqrt(token1FairPrice)) / (2**56);
  }
}

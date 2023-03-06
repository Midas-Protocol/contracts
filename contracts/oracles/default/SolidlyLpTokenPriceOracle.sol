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

    uint256 priceToken0 = BasePriceOracle(msg.sender).price(token0);
    uint256 priceToken1 = BasePriceOracle(msg.sender).price(token1);

    uint256 balance0 = ERC20Upgradeable(token0).balanceOf(token);
    uint256 balance1 = ERC20Upgradeable(token1).balanceOf(token);

    uint256 price = (balance0 * priceToken0 + balance1 * priceToken1) / pair.totalSupply();

    return price;
  }
}

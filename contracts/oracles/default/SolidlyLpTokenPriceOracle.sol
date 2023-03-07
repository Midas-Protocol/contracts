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
    // Get fair reserves
    //(uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
    address token0 = pair.token0();
    address token1 = pair.token1();

    Observation memory _observation = pair.lastObservation();

    (uint256 reserve0Cumulative, uint256 reserve1Cumulative, ) = pair.currentCumulativePrices();
    if (block.timestamp == _observation.timestamp) {
      _observation = pair.observations(pair.observationLength() - 2);
    }

    uint256 timeElapsed = block.timestamp - _observation.timestamp;

    //    uint256 _reserve0 = (reserve0Cumulative - _observation.reserve0Cumulative) / timeElapsed;
    //    uint256 _reserve1 = (reserve1Cumulative - _observation.reserve1Cumulative) / timeElapsed;
    //
    //    // Get fair price of non-WETH token (underlying the pair) in terms of ETH
    //    uint256 token0FairPrice = token0 == wtoken ? 1e18 : BasePriceOracle(msg.sender).price(token0);
    //    uint256 token1FairPrice = token1 == wtoken ? 1e18 : BasePriceOracle(msg.sender).price(token1);
    //
    //    return
    //      (_reserve0 *
    //        (10**(18 - uint256(ERC20Upgradeable(token0).decimals()))) *
    //        token0FairPrice +
    //        _reserve1 *
    //        (10**(18 - uint256(ERC20Upgradeable(token1).decimals()))) *
    //        token1FairPrice) / totalSupply;
    uint256 reserve0 = (reserve0Cumulative - _observation.reserve0Cumulative) / timeElapsed;
    uint256 reserve1 = (reserve1Cumulative - _observation.reserve1Cumulative) / timeElapsed;

    uint256 price0 = BasePriceOracle(msg.sender).price(token0);
    uint256 price1 = BasePriceOracle(msg.sender).price(token1);

    return (reserve0 * price0 + reserve1 * price1) / totalSupply;
  }
}

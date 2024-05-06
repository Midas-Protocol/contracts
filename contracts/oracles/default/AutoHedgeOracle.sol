// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { IPriceOracle } from "../../external/compound/IPriceOracle.sol";
import { BasePriceOracle } from "../BasePriceOracle.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

import { IAutoHedgeStableVolatilePairUpgradeableV2 } from "../../external/autonomy/IAutoHedgeStableVolatilePairUpgradeableV2.sol";

/**
 * @title AutoHedgeOracle
 * @notice AutoHedgeOracle is a price oracle for Uniswap (and SushiSwap) LP tokens.
 * @dev I	ICompoundPriceOracle` interface used by Fuse pools (and Compound v2).
 */
contract AutoHedgeOracle is IPriceOracle, BasePriceOracle {
  address public immutable weth;

  constructor(address _weth) {
    weth = _weth;
  }

  /**
   * @notice Get the LP token price price for an underlying token address.
   * @param underlying The underlying token address for which to get the price (set to zero address for ETH)
   * @return Price denominated in ETH (scaled by 1e18)
   */
  function price(address underlying) external view override returns (uint256) {
    return _price(underlying);
  }

  /**
   * @notice Returns the price in ETH of the token underlying `cToken`.
   * @dev Implements the `ICompoundPriceOracle` interface for Fuse pools (and Compound v2).
   * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
   */
  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    address underlying = ICErc20(address(cToken)).underlying();
    // Comptroller needs prices to be scaled by 1e(36 - decimals)
    // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
    return _price(underlying);
  }

  /**
   * @dev Fetches the fair LP token/ETH price from Uniswap, with 18 decimals of precision.
   */
  function _price(address token) internal view returns (uint256) {
    IAutoHedgeStableVolatilePairUpgradeableV2 pair = IAutoHedgeStableVolatilePairUpgradeableV2(token);
    (, IERC20Metadata volatile, , IERC20Metadata uniLp, ) = pair.getTokens();
    // get the prices of the volatile and the stable
    uint256 volatilePriceInEth = BasePriceOracle(msg.sender).price(address(volatile));

    uint256 uniLpPriceInEth = BasePriceOracle(msg.sender).price(address(uniLp));

    uint256 amountVolBorrow = pair.balanceOfVolBorrow();
    uint256 balanceOfUniLp = pair.balanceOfUniLp();
    // convert that to the amounts of stable and volatile the pool owns
    uint256 uniLpValueInEth = balanceOfUniLp * uniLpPriceInEth;
    uint256 volatileOwedValueInEth = amountVolBorrow * volatilePriceInEth;

    uint256 totalValue = uniLpValueInEth - volatileOwedValueInEth;

    uint256 totalSupply = IERC20(token).totalSupply();

    if (totalSupply == 0) {
      return 0;
    }
    uint256 finalPrice = ((totalValue) / totalSupply);
    require(finalPrice > 0.1e17, "Price too low");
    return finalPrice;
  }

  /**
   * @dev Fast square root function.
   * Implementation from: https://github.com/Uniswap/uniswap-lib/commit/99f3f28770640ba1bb1ff460ac7c5292fb8291a0
   * Original implementation: https://github.com/abdk-consulting/abdk-libraries-solidity/blob/master/ABDKMath64x64.sol#L687
   */
  function sqrt(uint256 x) internal pure returns (uint256) {
    if (x == 0) return 0;
    uint256 xx = x;
    uint256 r = 1;

    if (xx >= 0x100000000000000000000000000000000) {
      xx >>= 128;
      r <<= 64;
    }
    if (xx >= 0x10000000000000000) {
      xx >>= 64;
      r <<= 32;
    }
    if (xx >= 0x100000000) {
      xx >>= 32;
      r <<= 16;
    }
    if (xx >= 0x10000) {
      xx >>= 16;
      r <<= 8;
    }
    if (xx >= 0x100) {
      xx >>= 8;
      r <<= 4;
    }
    if (xx >= 0x10) {
      xx >>= 4;
      r <<= 2;
    }
    if (xx >= 0x8) {
      r <<= 1;
    }

    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1;
    r = (r + x / r) >> 1; // Seven iterations should be enough
    uint256 r1 = x / r;
    return (r < r1 ? r : r1);
  }
}

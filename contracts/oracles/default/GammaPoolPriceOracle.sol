// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../../midas/SafeOwnableUpgradeable.sol";
import "../BasePriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";

import { IHypervisor } from "../../external/gamma/IHypervisor.sol";

import { BasePriceOracle } from "../BasePriceOracle.sol";

/**
 * @title GammaPoolPriceOracle
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 * @notice GammaPoolPriceOracle is a price oracle for Gelato Gamma wrapped Uniswap V3 LP tokens.
 * @dev Implements the `PriceOracle` interface used by Fuse pools (and Compound v2).
 */

contract GammaPoolPriceOracle is BasePriceOracle, SafeOwnableUpgradeable {
  /**
   * @dev The Wrapped native asset address.
   */
  address public WTOKEN;

  /**
   * @dev Constructor to set admin and canAdminOverwrite, wtoken address and native token USD price feed address
   */

  function initialize(address _wtoken) public initializer {
    __SafeOwnable_init(msg.sender);
    WTOKEN = _wtoken;
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
   * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
   * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
   */
  function getUnderlyingPrice(ICToken cToken) public view returns (uint256) {
    address underlying = ICErc20(address(cToken)).underlying();
    // Comptroller needs prices to be scaled by 1e(36 - decimals)
    // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
    return (_price(underlying) * 1e18) / (10**uint256(ERC20Upgradeable(underlying).decimals()));
  }

  /**
   * @dev Fetches the fair LP token/ETH price from Uniswap, with 18 decimals of precision.
   */
  function _price(address token) internal view virtual returns (uint256) {
    // Get Gamma pool and underlying tokens
    IHypervisor pool = IHypervisor(token);
    address token0 = pool.token0();
    address token1 = pool.token1();

    // Get underlying token prices
    uint256 p0 = BasePriceOracle(msg.sender).price(token0);
    uint256 p1 = BasePriceOracle(msg.sender).price(token1);

    // Get balances of the tokens in the pool given fair underlying token prices
    (uint256 r0, uint256 r1) = pool.getTotalAmounts();

    r0 = r0 * 10**(18 - uint256(ERC20Upgradeable(token0).decimals()));
    r1 = r1 * 10**(18 - uint256(ERC20Upgradeable(token1).decimals()));

    require(r0 > 0 || r1 > 0, "Gamma underlying token balances not both greater than 0.");

    // Add the total value of each token together and divide by the totalSupply to get the unit price
    return (p0 * r0 + p1 * r1) / ERC20Upgradeable(token).totalSupply();
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { EIP20Interface } from "../../compound/EIP20Interface.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";

import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";
import "../../external/curve/ICurveV2Pool.sol";
import "../../midas/SafeOwnableUpgradeable.sol";
import "../../utils/PatchedStorage.sol";

import "../BasePriceOracle.sol";

/**
 * @title CurveLpTokenPriceOracle
 * @author Carlo Mazzaferro <carlo@midascapital.xyz> (https://github.com/carlomazzaferro)
 * @notice CurveLpTokenPriceOracleNoRegistry is a price oracle for Curve V2 LP tokens (using the sender as a root oracle).
 * @dev Implements the `PriceOracle` interface used by Midas pools (and Compound v2).
 */
contract CurveV2LpTokenPriceOracleNoRegistry is SafeOwnableUpgradeable, BasePriceOracle {
  address public usdToken;
  MasterPriceOracle public masterPriceOracle;
  /**
   * @dev Maps Curve LP token addresses to pool addresses.
   */
  mapping(address => address) public poolOf;

  /**
   * @dev Initializes an array of LP tokens and pools if desired.
   * @param _lpTokens Array of LP token addresses.
   * @param _pools Array of pool addresses.
   */
  function initialize(
    address[] memory _lpTokens,
    address[] memory _pools,
    address _usdToken,
    MasterPriceOracle _masterPriceOracle
  ) public initializer {
    require(_lpTokens.length == _pools.length, "No LP tokens supplied or array lengths not equal.");
    __SafeOwnable_init();

    usdToken = _usdToken;
    masterPriceOracle = _masterPriceOracle;

    for (uint256 i = 0; i < _pools.length; i++) {
      poolOf[_lpTokens[i]] = _pools[i];
    }
  }

  /**
   * @notice Get the LP token price price for an underlying token address.
   * @param underlying The underlying token address for which to get the price (set to zero address for ETH).
   * @return Price denominated in ETH (scaled by 1e18).
   */
  function price(address underlying) external view override returns (uint256) {
    return _price(underlying);
  }

  /**
   * @notice Returns the price in ETH of the token underlying `cToken`.
   * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
   * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
   */
  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    address underlying = ICErc20(address(cToken)).underlying();
    // Comptroller needs prices to be scaled by 1e(36 - decimals)
    // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
    return (_price(underlying) * 1e18) / (10**uint256(EIP20Interface(underlying).decimals()));
  }

  /**
   * @dev Fetches the fair LP token price from Curve, with 18 decimals of precision.
   * @param lpToken The LP token contract address for price retrieval.
   */
  function _price(address lpToken) internal view returns (uint256) {
    address pool = poolOf[lpToken];
    require(pool != address(0), "LP token is not registered.");
    uint256 usdPrice = ICurveV2Pool(pool).lp_price();
    uint256 bnbUsdPrice = masterPriceOracle.price(usdToken);
    return (usdPrice / 10**18) * bnbUsdPrice;
  }

  /**
   * @dev Register the pool given LP token address and set the pool info.
   * @param _lpToken LP token to find the corresponding pool.
   * @param _pool Pool address.
   */
  function registerPool(address _lpToken, address _pool) external onlyOwner {
    address pool = poolOf[_lpToken];
    require(pool == address(0), "This LP token is already registered.");
    poolOf[_lpToken] = _pool;
  }
}

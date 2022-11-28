// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { IPriceOracle } from "../../external/compound/IPriceOracle.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { BasePriceOracle } from "../BasePriceOracle.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { NativeUSDPriceOracle } from "../evmos/NativeUSDPriceOracle.sol";
import { SafeOwnableUpgradeable } from "../../midas/SafeOwnableUpgradeable.sol";
import { IPriceOracle as IAdrastiaPriceOracle } from "adrastia/interfaces/IPriceOracle.sol";

/**
 * @title AdrastiaPriceOracle
 * @notice Returns prices from Adrastia.
 * @dev Implements `PriceOracle`.
 * @author Carlo Mazzaferro <rahul@midascapital.xyz> (https://github.com/carlomazzaferro)
 */
contract AdrastiaPriceOracle is SafeOwnableUpgradeable, IPriceOracle, BasePriceOracle {
  /**
   * @notice Maps ERC20 token addresses to NATIVE-based Adrastia price feed contracts.
   */
  mapping(address => IAdrastiaPriceOracle) public priceFeeds;

  /**
   * @notice NATIVE/USD price feed.
   */
  NativeUSDPriceOracle public NATIVE_TOKEN_USD_PRICE_FEED;

  /**
   * @dev Constructor to set admin and canAdminOverwrite, wtoken address and native token USD price feed address
   */
  function initialize(NativeUSDPriceOracle nativeUsdPriceFeed) public initializer {
    __SafeOwnable_init();
    NATIVE_TOKEN_USD_PRICE_FEED = nativeUsdPriceFeed;
  }

  /**
   * @dev Admin-only function to set price feeds.
   * @param underlyings Underlying token addresses for which to set price feeds.
   * @param feeds The Oracle price feed contract addresses for each of `underlyings`.
   */
  function setPriceFeeds(address[] memory underlyings, IAdrastiaPriceOracle[] memory feeds) external onlyOwner {
    // Input validation
    require(
      underlyings.length > 0 && underlyings.length == feeds.length,
      "Lengths of both arrays must be equal and greater than 0."
    );

    // For each token/feed
    for (uint256 i = 0; i < underlyings.length; i++) {
      address underlying = underlyings[i];
      // Set feed and base currency
      priceFeeds[underlying] = feeds[i];
    }
  }

  /**
   * @dev Internal function returning the price in W_NATIVE of `underlying`.
   * https://docs.adrastia.io/deployments/evmos
   */
  function _price(address underlying) internal view returns (uint256) {
    // Get token/ETH price from feed
    IAdrastiaPriceOracle feed = priceFeeds[underlying];
    require(address(feed) != address(0), "No price feed found for this underlying ERC20 token.");

    uint112 tokenPrice = feed.consultPrice(underlying);
    uint8 feedDecimals = feed.quoteTokenDecimals();
    return
      tokenPrice >= 0
        ? feedDecimals <= 18
          ? (uint256(tokenPrice) * 10**(18 - feedDecimals))
          : (uint256(tokenPrice) / 10**(feedDecimals - 18))
        : 0;
  }

  /**
   * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
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
    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();

    // Get price
    uint256 oraclePrice = _price(underlying);

    // Format and return price
    uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
    return
      underlyingDecimals <= 18
        ? uint256(oraclePrice) * (10**(18 - underlyingDecimals))
        : uint256(oraclePrice) / (10**(underlyingDecimals - 18));
  }
}

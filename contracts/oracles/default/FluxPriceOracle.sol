// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { CLV2V3Interface } from "../../external/flux/CLV2V3Interface.sol";
import { IPriceOracle } from "../../external/compound/IPriceOracle.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { BasePriceOracle } from "../BasePriceOracle.sol";
import { NativeUSDPriceOracle } from "../evmos/NativeUSDPriceOracle.sol";
import { SafeOwnableUpgradeable } from "../../midas/SafeOwnableUpgradeable.sol";

/**
 * @title FluxOracle
 * @notice Returns prices from Flux.
 * @dev Implements `PriceOracle`.
 * @author Rahul Sethuram & Carlo Mazzaferro <rahul@midascapital.xyz> (https://github.com/rhlsthrm)
 */
contract FluxPriceOracle is SafeOwnableUpgradeable, IPriceOracle, BasePriceOracle {
  /**
   * @notice Maps ERC20 token addresses to ETH-based Flux price feed contracts.
   */
  mapping(address => CLV2V3Interface) public priceFeeds;

  /**
   * @notice Flux NATIVE/USD price feed contracts.
   */
  NativeUSDPriceOracle public NATIVE_TOKEN_USD_PRICE_FEED;

  /**
   * @dev Constructor to set admin and canAdminOverwrite, wtoken address and native token USD price feed address
   */
  function initialize(NativeUSDPriceOracle nativeTokenUsd) public initializer {
    __SafeOwnable_init();
    NATIVE_TOKEN_USD_PRICE_FEED = nativeTokenUsd;
  }

  /**
   * @dev Admin-only function to set price feeds.
   * @param underlyings Underlying token addresses for which to set price feeds.
   * @param feeds The Oracle price feed contract addresses for each of `underlyings`.
   */
  function setPriceFeeds(address[] memory underlyings, CLV2V3Interface[] memory feeds) external onlyOwner {
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
   * @dev Internal function returning the price in ETH of `underlying`.
   * Assumes price feeds are 8 decimals!
   * https://docs.fluxprotocol.org/docs/live-data-feeds/fpo-live-networks-and-pairs#mainnet-2
   */
  function _price(address underlying) internal view returns (uint256) {
    // Get token/ETH price from feed
    CLV2V3Interface feed = priceFeeds[underlying];
    require(address(feed) != address(0), "No Flux price feed found for this underlying ERC20 token.");

    // Get the NATIVE/USD price feed from NativeUSDPriceOracle
    // 18 decimals are used
    uint256 nativeTokenUsdPrice = NATIVE_TOKEN_USD_PRICE_FEED.getValue();
    if (nativeTokenUsdPrice <= 0) return 0;
    // 8 decimals are used
    int256 tokenUsdPrice = feed.latestAnswer();
    // Flux price feed is 8 decimals:
    return tokenUsdPrice >= 0 ? (uint256(tokenUsdPrice) * 1e28) / uint256(nativeTokenUsdPrice) : 0;
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

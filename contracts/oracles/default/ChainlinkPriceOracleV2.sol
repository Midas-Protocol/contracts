// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../../external/compound/IPriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";

import "../../external/chainlink/AggregatorV3Interface.sol";

import "../BasePriceOracle.sol";

/**
 * @title ChainlinkPriceOracleV2
 * @notice Returns prices from Chainlink.
 * @dev Implements `PriceOracle`.
 * @author David Lucid <david@rari.capital> (https://github.com/davidlucid)
 */
contract ChainlinkPriceOracleV2 is IPriceOracle, BasePriceOracle {
  /**
   * @notice Maps ERC20 token addresses to ETH-based Chainlink price feed contracts.
   */
  mapping(address => AggregatorV3Interface) public priceFeeds;

  /**
   * @notice Maps ERC20 token addresses to enums indicating the base currency of the feed.
   */
  mapping(address => FeedBaseCurrency) public feedBaseCurrencies;

  /**
   * @notice Enum indicating the base currency of a Chainlink price feed.
   * @dev ETH is interchangeable with the nativeToken of the current chain.
   */
  enum FeedBaseCurrency {
    ETH,
    USD
  }

  /**
   * @notice Chainlink NATIVE/USD price feed contracts.
   */
  AggregatorV3Interface public immutable NATIVE_TOKEN_USD_PRICE_FEED;

  /**
   * @dev The administrator of this `MasterPriceOracle`.
   */
  address public admin;

  /**
   * @dev Controls if `admin` can overwrite existing assignments of oracles to underlying tokens.
   */
  bool public canAdminOverwrite;

  /**
   * @dev The Wrapped native asset address.
   */
  address public immutable wtoken;

  /**
   * @dev Constructor to set admin and canAdminOverwrite, wtoken address and native token USD price feed address
   * @param _admin The admin who can assign oracles to underlying tokens.
   * @param _canAdminOverwrite Controls if `admin` can overwrite existing assignments of oracles to underlying tokens.
   * @param _wtoken The Wrapped native asset address
   * @param nativeTokenUsd Will this oracle return prices denominated in USD or in the native token.
   */
  constructor(
    address _admin,
    bool _canAdminOverwrite,
    address _wtoken,
    address nativeTokenUsd
  ) {
    admin = _admin;
    canAdminOverwrite = _canAdminOverwrite;
    wtoken = _wtoken;
    NATIVE_TOKEN_USD_PRICE_FEED = AggregatorV3Interface(nativeTokenUsd);
  }

  /**
   * @dev Changes the admin and emits an event.
   */
  function changeAdmin(address newAdmin) external onlyAdmin {
    address oldAdmin = admin;
    admin = newAdmin;
    emit NewAdmin(oldAdmin, newAdmin);
  }

  /**
   * @dev Event emitted when `admin` is changed.
   */
  event NewAdmin(address oldAdmin, address newAdmin);

  /**
   * @dev Modifier that checks if `msg.sender == admin`.
   */
  modifier onlyAdmin() {
    require(msg.sender == admin, "Sender is not the admin.");
    _;
  }

  /**
   * @dev Admin-only function to set price feeds.
   * @param underlyings Underlying token addresses for which to set price feeds.
   * @param feeds The Chainlink price feed contract addresses for each of `underlyings`.
   * @param baseCurrency The currency in which `feeds` are based.
   */
  function setPriceFeeds(
    address[] memory underlyings,
    AggregatorV3Interface[] memory feeds,
    FeedBaseCurrency baseCurrency
  ) external onlyAdmin {
    // Input validation
    require(
      underlyings.length > 0 && underlyings.length == feeds.length,
      "Lengths of both arrays must be equal and greater than 0."
    );

    // For each token/feed
    for (uint256 i = 0; i < underlyings.length; i++) {
      address underlying = underlyings[i];

      // Check for existing oracle if !canAdminOverwrite
      if (!canAdminOverwrite)
        require(
          address(priceFeeds[underlying]) == address(0),
          "Admin cannot overwrite existing assignments of price feeds to underlying tokens."
        );

      // Set feed and base currency
      priceFeeds[underlying] = feeds[i];
      feedBaseCurrencies[underlying] = baseCurrency;
    }
  }

  /**
   * @notice Internal function returning the price in of `underlying`.
   * @dev If the oracle got constructed with `nativeTokenUsd` = TRUE this will return a price denominated in USD otherwise in the native token
   */
  function _price(address underlying) internal view returns (uint256) {
    // Return 1e18 for WTOKEN
    if (underlying == wtoken || underlying == address(0)) return 1e18;

    // Get token/ETH price from Chainlink
    AggregatorV3Interface feed = priceFeeds[underlying];
    require(address(feed) != address(0), "No Chainlink price feed found for this underlying ERC20 token.");
    FeedBaseCurrency baseCurrency = feedBaseCurrencies[underlying];

    if (baseCurrency == FeedBaseCurrency.ETH) {
      (, int256 tokenEthPrice, , , ) = feed.latestRoundData();
      return tokenEthPrice >= 0 ? (uint256(tokenEthPrice) * 1e18) / (10**uint256(feed.decimals())) : 0;
    } else if (baseCurrency == FeedBaseCurrency.USD) {
      (, int256 nativeTokenUsdPrice, , , ) = NATIVE_TOKEN_USD_PRICE_FEED.latestRoundData();
      if (nativeTokenUsdPrice <= 0) return 0;
      (, int256 tokenUsdPrice, , , ) = feed.latestRoundData();
      return
        tokenUsdPrice >= 0
          ? ((uint256(tokenUsdPrice) * 1e18 * (10**uint256(NATIVE_TOKEN_USD_PRICE_FEED.decimals()))) /
            (10**uint256(feed.decimals()))) / uint256(nativeTokenUsdPrice)
          : 0;
    } else {
      revert("unknown base currency");
    }
  }

  /**
   * @notice Returns the price in of `underlying` either in USD or the native token (implements `BasePriceOracle`).
   * @dev If the oracle got constructed with `nativeTokenUsd` = TRUE this will return a price denominated in USD otherwise in the native token
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
    // Return 1e18 for ETH
    if (cToken.isCEther()) return 1e18;

    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();

    return _price(underlying);
  }
}

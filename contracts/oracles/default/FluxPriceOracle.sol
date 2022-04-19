// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../../external/flux/CLV2V3Interface.sol";
import "../../external/compound/IPriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";
import "../BasePriceOracle.sol";

/**
 * @title FluxOracle
 * @notice Returns prices from Chainlink.
 * @dev Implements `PriceOracle`.
 * @author Rahul Sethuram <rahul@midascapital.xyz> (https://github.com/rhlsthrm)
 */
contract FluxPriceOracle is IPriceOracle, BasePriceOracle {
  /**
   * @notice Maps ERC20 token addresses to ETH-based Chainlink price feed contracts.
   */
  mapping(address => CLV2V3Interface) public priceFeeds;

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
   * @notice Flux NATIVE/USD price feed contracts.
   */
  CLV2V3Interface public immutable NATIVE_TOKEN_USD_PRICE_FEED;

  /**
   * @dev Constructor to set admin and canAdminOverwrite, wtoken address and native token USD price feed address
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
    NATIVE_TOKEN_USD_PRICE_FEED = CLV2V3Interface(nativeTokenUsd);
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
   */
  function setPriceFeeds(address[] memory underlyings, CLV2V3Interface[] memory feeds) external onlyAdmin {
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
    }
  }

  /**
   * @dev Internal function returning the price in ETH of `underlying`.
   * Assumes price feeds are 8 decimals!
   */
  function _price(address underlying) internal view returns (uint256) {
    // Return 1e18 for WTOKEN
    if (underlying == wtoken || underlying == address(0)) return 1e18;

    // Get token/ETH price from Chainlink
    CLV2V3Interface feed = priceFeeds[underlying];
    require(address(feed) != address(0), "No Flux price feed found for this underlying ERC20 token.");

    int256 nativeTokenUsdPrice = NATIVE_TOKEN_USD_PRICE_FEED.latestAnswer();
    if (nativeTokenUsdPrice <= 0) return 0;
    int256 tokenUsdPrice = feed.latestAnswer();
    return tokenUsdPrice >= 0 ? ((uint256(tokenUsdPrice) * 1e26) / (10**8)) / uint256(nativeTokenUsdPrice) : 0;
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
    // Return 1e18 for ETH
    if (cToken.isCEther()) return 1e18;

    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();

    // Get price
    uint256 chainlinkPrice = _price(underlying);

    // Format and return price
    uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
    return
      underlyingDecimals <= 18
        ? uint256(chainlinkPrice) * (10**(18 - underlyingDecimals))
        : uint256(chainlinkPrice) / (10**(underlyingDecimals - 18));
  }
}

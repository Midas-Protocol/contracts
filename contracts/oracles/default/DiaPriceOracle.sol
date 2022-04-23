// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../../external/compound/IPriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";
import "../BasePriceOracle.sol";

interface DIAOracleV2 {
  function getValue(string memory key) external view returns (uint128, uint128);
}

/**
 * @title DiaPriceOracle
 * @notice Returns prices from DIA.
 * @dev Implements `PriceOracle`.
 * @author Rahul Sethuram <rahul@midascapital.xyz> (https://github.com/rhlsthrm)
 */
contract DiaPriceOracle is IPriceOracle, BasePriceOracle {
  struct DiaOracle {
    DIAOracleV2 feed;
    string key;
  }

  /**
   * @notice Maps ERC20 token addresses to ETH-based Chainlink price feed contracts.
   */
  mapping(address => DiaOracle) public priceFeeds;

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
   * @notice DIA NATIVE/USD price feed contracts.
   */
  DIAOracleV2 public immutable NATIVE_TOKEN_USD_PRICE_FEED;
  string public NATIVE_TOKEN_USD_KEY;

  /**
   * @dev Constructor to set admin and canAdminOverwrite, wtoken address and native token USD price feed address
   */
  constructor(
    address _admin,
    bool _canAdminOverwrite,
    address _wtoken,
    address nativeTokenUsd,
    string memory nativeTokenUsdKey
  ) {
    admin = _admin;
    canAdminOverwrite = _canAdminOverwrite;
    wtoken = _wtoken;
    NATIVE_TOKEN_USD_PRICE_FEED = DIAOracleV2(nativeTokenUsd);
    NATIVE_TOKEN_USD_KEY = nativeTokenUsdKey;
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
   * @param feeds The DIA price feed contract addresses for each of `underlyings`.
   * @param keys The keys for each of `underlyings`, in the format "ETH/USD" for example
   */
  function setPriceFeeds(
    address[] memory underlyings,
    DIAOracleV2[] memory feeds,
    string[] memory keys
  ) external onlyAdmin {
    // Input validation
    require(
      underlyings.length > 0 && underlyings.length == feeds.length && underlyings.length == keys.length,
      "Lengths of both arrays must be equal and greater than 0."
    );

    // For each token/feed
    for (uint256 i = 0; i < underlyings.length; i++) {
      address underlying = underlyings[i];

      // Check for existing oracle if !canAdminOverwrite
      if (!canAdminOverwrite)
        require(
          address(priceFeeds[underlying].feed) == address(0),
          "Admin cannot overwrite existing assignments of price feeds to underlying tokens."
        );

      // Set feed and base currency
      priceFeeds[underlying] = DiaOracle({ feed: feeds[i], key: keys[i] });
    }
  }

  /**
   * @dev Internal function returning the price in ETH of `underlying`.
   * Assumes price feeds are 8 decimals!
   */
  function _price(address underlying) internal view returns (uint256) {
    // Return 1e18 for WTOKEN
    if (underlying == wtoken || underlying == address(0)) return 1e18;

    // Get token/Native price from Oracle
    DiaOracle memory feed = priceFeeds[underlying];
    require(address(feed.feed) != address(0), "No oracle price feed found for this underlying ERC20 token.");

    (uint128 nativeTokenUsdPrice, ) = NATIVE_TOKEN_USD_PRICE_FEED.getValue(NATIVE_TOKEN_USD_KEY);
    if (nativeTokenUsdPrice <= 0) return 0;
    (uint128 tokenUsdPrice, ) = feed.feed.getValue(feed.key);
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
    uint256 oraclePrice = _price(underlying);

    // Format and return price
    uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
    return
      underlyingDecimals <= 18
        ? uint256(oraclePrice) * (10**(18 - underlyingDecimals))
        : uint256(oraclePrice) / (10**(underlyingDecimals - 18));
  }
}

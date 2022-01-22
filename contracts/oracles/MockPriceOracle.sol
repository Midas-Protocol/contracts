// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0;

import "@openzeppelin/contracts-upgradeable/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

import "../external/compound/IPriceOracle.sol";
import "../external/compound/ICToken.sol";
import "../external/compound/ICErc20.sol";

import "../external/chainlink/AggregatorV3Interface.sol";

import "./BasePriceOracle.sol";

/**
 * @title MockPriceOracle
 * @notice Returns mocked prices from a Chainlink-like oracle. Used for local dev only
 * @dev Implements `PriceOracle`.
 * @author Carlo Mazzaferro <carlo.mazzaferro@gmail.com> (https://github.com/carlomazzaferro)
 */
contract MockPriceOracle is IPriceOracle, BasePriceOracle {
    using SafeMathUpgradeable for uint256;

    /**
     * @notice Maps ERC20 token addresses to ETH-based Chainlink price feed contracts.
     */
    mapping(address => AggregatorV3Interface) public ethPriceFeeds;

    /**
     * @notice Maps ERC20 token addresses to USD-based Chainlink price feed contracts.
     */
    mapping(address => AggregatorV3Interface) public usdPriceFeeds;

    /**
     * @notice Maps ERC20 token addresses to BTC-based Chainlink price feed contracts.
     */
    mapping(address => AggregatorV3Interface) public btcPriceFeeds;

    /**
     * @notice Chainlink ETH/USD price feed contracts.
     */
    AggregatorV3Interface public constant ETH_USD_PRICE_FEED = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    /**
     * @notice Chainlink BTC/ETH price feed contracts.
     */
    AggregatorV3Interface public constant BTC_ETH_PRICE_FEED = AggregatorV3Interface(0xdeb288F737066589598e9214E782fa5A8eD689e8);

    /**
     * @notice The maxmimum number of seconds elapsed since the round was last updated before the price is considered stale. If set to 0, no limit is enforced.
     */
    uint256 public maxSecondsBeforePriceIsStale;

    /**
     * @dev Constructor to set `maxSecondsBeforePriceIsStale` as well as all Chainlink price feeds.
     */
    constructor(uint256 _maxSecondsBeforePriceIsStale) {
        // Set maxSecondsBeforePriceIsStale
        maxSecondsBeforePriceIsStale = _maxSecondsBeforePriceIsStale;
    }

    /**
     * @dev Returns a boolean indicating if a price feed exists for the underlying asset.
     */

    function hasPriceFeed(address underlying) external view returns (bool) {
        return true;
    }

    /**
     * @dev Internal function returning the price in ETH of `underlying`.
     */

    function random() private view returns (uint) {
        uint r = uint(keccak256(abi.encodePacked(block.timestamp, msg.sender))) % 99;
        r = r + 1;
        return r;
    }

    function _price(address underlying) internal view returns (uint) {
        // Return 1e18 for WETH
        if (underlying == 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2) return 1e18;

        int256 tokenEthPrice = 1;
        uint r = random();

        return uint256(tokenEthPrice).mul(1e18).div(r).div(1e18);

    }

    /**
     * @dev Returns the price in ETH of `underlying` (implements `BasePriceOracle`).
     */
    function price(address underlying) external override view returns (uint) {
        return _price(underlying);
    }

    /**
     * @notice Returns the price in ETH of the token underlying `cToken`.
     * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
     * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
     */
    function getUnderlyingPrice(ICToken cToken) external override view returns (uint) {
        // Return 1e18 for ETH
        if (cToken.isCEther()) return 1e18;

        // Get underlying token address
        address underlying = ICErc20(address(cToken)).underlying();

        // Get price
        uint256 chainlinkPrice = _price(underlying);

        // Format and return price
        uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
        return underlyingDecimals <= 18 ? uint256(chainlinkPrice).mul(10 ** (18 - underlyingDecimals)) : uint256(chainlinkPrice).div(10 ** (underlyingDecimals - 18));
    }
}

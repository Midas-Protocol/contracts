// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../../external/compound/IPriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";

import "../../external/uniswap/TickMath.sol";
import "../../external/uniswap/FullMath.sol";
import "../../external/uniswap/IUniswapV3Pool.sol";

import "../BasePriceOracle.sol";

/**
 * @title UniswapV3PriceOracle
 * @author Carlo Mazzaferro <carlo@midascapital.xyz> (https://github.com/carlomazzaferro)
 * @notice UniswapV3PriceOracle is a price oracle for Uniswap V3 pairs.
 * @dev Implements the `PriceOracle` interface used by Fuse pools (and Compound v2).
 */
contract UniswapV3PriceOracle is IPriceOracle {
  /**
   * @notice Maps ERC20 token addresses to UniswapV3Pool addresses.
   */
  mapping(address => AssetConfig) public poolFeeds;

  /**
   * @dev The administrator of this `UniswapV3PriceOracle`.
   */
  address public admin;

  /**
   * @dev Controls if `admin` can overwrite existing assignments of oracles to underlying tokens.
   */
  bool public canAdminOverwrite;

  struct AssetConfig {
    address poolAddress;
    uint256 twapWindow;
  }

  /**
   * @dev Constructor to set admin, canAdminOverwrite and wtoken address
   */
  constructor(address _admin, bool _canAdminOverwrite) {
    admin = _admin;
    canAdminOverwrite = _canAdminOverwrite;
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
   * @param assetConfig The asset configuration which includes pool address and twap window.
   */
  function setPoolFeeds(address[] memory underlyings, AssetConfig[] memory assetConfig) external onlyAdmin {
    // Input validation
    require(
      underlyings.length > 0 && underlyings.length == assetConfig.length,
      "Lengths of both arrays must be equal and greater than 0."
    );

    // For each token/config
    for (uint256 i = 0; i < underlyings.length; i++) {
      address underlying = underlyings[i];

      // Check for existing oracle if !canAdminOverwrite
      if (!canAdminOverwrite)
        require(
          poolFeeds[underlying].poolAddress == address(0),
          "Admin cannot overwrite existing assignments of price feeds to underlying tokens."
        );

      // Set asset config for underlying
      poolFeeds[underlying] = assetConfig[i];
    }
  }

  /**
   * @notice Get the token price price for an underlying token address.
   * @param underlying The underlying token address for which to get the price (set to zero address for WTOKEN)
   * @return Price denominated in WTOKEN (scaled by 1e18)
   */
  function price(address underlying) external view returns (uint256) {
    return _price(underlying);
  }

  /**
   * @notice Returns the price in WTOKEN of the token underlying `cToken`.
   * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
   * @return Price in WTOKEN of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
   */
  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    address underlying = ICErc20(address(cToken)).underlying();
    // Comptroller needs prices to be scaled by 1e(36 - decimals)
    // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
    return (_price(underlying) * 1e18) / (10**uint256(ERC20Upgradeable(underlying).decimals()));
  }

  /**
   * @dev Fetches the price for a token from Uniswap v3
   */
  function _price(address token) internal view virtual returns (uint256) {
    uint32[] memory secondsAgos = new uint32[](2);
    uint256 twapWindow = poolFeeds[token].twapWindow;

    secondsAgos[0] = uint32(twapWindow);
    secondsAgos[1] = 0;

    IUniswapV3Pool pool = IUniswapV3Pool(poolFeeds[token].poolAddress);
    (int56[] memory tickCumulatives, ) = pool.observe(secondsAgos);

    int24 tick = int24((tickCumulatives[1] - tickCumulatives[0]) / int56(int256(twapWindow)));
    uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

    return getPriceX96FromSqrtPriceX96(sqrtPriceX96);
  }

  function getPriceX96FromSqrtPriceX96(uint160 sqrtPriceX96) public pure returns (uint256 priceX96) {
    return FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, uint(2**(96*2)) / 1e18);
  }
}

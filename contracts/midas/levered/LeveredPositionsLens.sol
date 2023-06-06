// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { ILeveredPositionFactory } from "./ILeveredPositionFactory.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { IComptroller, IPriceOracle } from "../../external/compound/IComptroller.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract LeveredPositionsLens is Initializable {
  ILeveredPositionFactory public factory;

  function initialize(ILeveredPositionFactory _factory) external initializer {
    factory = _factory;
  }

  /// @notice this is a lens fn, it is not intended to be used on-chain
  /// @dev returns lists of the market addresses, names and symbols of the underlying assets of those collateral markets that are whitelisted
  function getCollateralMarkets()
    external
    view
    returns (
      address[] memory markets,
      address[] memory poolOfMarket,
      address[] memory underlyings,
      uint256[] memory underlyingPrices,
      string[] memory names,
      string[] memory symbols,
      uint8[] memory decimals,
      uint256[] memory totalUnderlyingSupplied,
      uint256[] memory ratesPerBlock
    )
  {
    markets = factory.getWhitelistedCollateralMarkets();
    poolOfMarket = new address[](markets.length);
    underlyings = new address[](markets.length);
    underlyingPrices = new uint256[](markets.length);
    names = new string[](markets.length);
    symbols = new string[](markets.length);
    totalUnderlyingSupplied = new uint256[](markets.length);
    decimals = new uint8[](markets.length);
    ratesPerBlock = new uint256[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(markets[i]);
      poolOfMarket[i] = market.comptroller();
      IComptroller pool = IComptroller(poolOfMarket[i]);
      underlyingPrices[i] = IPriceOracle(pool.oracle()).getUnderlyingPrice(market);
      underlyings[i] = market.underlying();
      ERC20Upgradeable underlying = ERC20Upgradeable(underlyings[i]);
      names[i] = underlying.name();
      symbols[i] = underlying.symbol();
      decimals[i] = underlying.decimals();
      totalUnderlyingSupplied[i] = market.getTotalUnderlyingSupplied();
      ratesPerBlock[i] = market.supplyRatePerBlock();
    }
  }

  /// @notice this is a lens fn, it is not intended to be used on-chain
  /// @dev returns the Rate for the chosen borrowable at the specified  leverage ratio and supply amount
  function getBorrowRateAtRatio(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    uint256 _baseCollateral,
    uint256 _targetLeverageRatio
  ) external view returns (uint256) {
    IComptroller pool = IComptroller(_stableMarket.comptroller());
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(_stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(_collateralMarket);

    uint256 borrowAmount = ((_targetLeverageRatio - 1e18) * _baseCollateral * collateralAssetPrice) /
      (stableAssetPrice * 1e18);
    return _stableMarket.borrowRatePerBlockAfterBorrow(borrowAmount);
  }

  /// @notice this is a lens fn, it is not intended to be used on-chain
  /// @dev returns lists of the market addresses, names, symbols and the current Rate for each Borrowable asset
  function getBorrowableMarketsAndRates(ICErc20 _collateralMarket)
    external
    view
    returns (
      address[] memory markets,
      address[] memory underlyings,
      string[] memory names,
      string[] memory symbols,
      uint256[] memory rates,
      uint8[] memory decimals
    )
  {
    markets = factory.getBorrowableMarketsByCollateral(_collateralMarket);
    underlyings = new address[](markets.length);
    names = new string[](markets.length);
    symbols = new string[](markets.length);
    rates = new uint256[](markets.length);
    decimals = new uint8[](markets.length);
    for (uint256 i = 0; i < markets.length; i++) {
      ICErc20 market = ICErc20(markets[i]);
      address underlyingAddress = market.underlying();
      underlyings[i] = underlyingAddress;
      ERC20Upgradeable underlying = ERC20Upgradeable(underlyingAddress);
      names[i] = underlying.name();
      symbols[i] = underlying.symbol();
      rates[i] = market.borrowRatePerBlock();
      decimals[i] = underlying.decimals();
    }
  }

  /// @notice this is a lens fn, it is not intended to be used on-chain
  function getNetAPY(
    uint256 _supplyAPY,
    uint256 _supplyAmount,
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    uint256 _targetLeverageRatio
  ) external view returns (int256 netAPY) {
    if (_supplyAPY == 0 || _supplyAmount == 0 || _targetLeverageRatio <= 1e18) return 0;

    IComptroller pool = IComptroller(_collateralMarket.comptroller());
    IPriceOracle oracle = pool.oracle();
    // TODO the calcs can be implemented without using collateralAssetPrice
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(_collateralMarket);

    // total collateral = base collateral + levered collateral
    uint256 totalCollateral = (_supplyAmount * _targetLeverageRatio) / 1e18;
    uint256 yieldFromTotalSupplyScaled = _supplyAPY * totalCollateral;
    int256 yieldValueScaled = int256((yieldFromTotalSupplyScaled * collateralAssetPrice) / 1e18);

    uint256 borrowedValueScaled = (totalCollateral - _supplyAmount) * collateralAssetPrice;
    uint256 _borrowRate = _stableMarket.borrowRatePerBlock() * factory.blocksPerYear();
    int256 borrowInterestValueScaled = int256((_borrowRate * borrowedValueScaled) / 1e18);

    int256 netValueDiffScaled = yieldValueScaled - borrowInterestValueScaled;

    netAPY = ((netValueDiffScaled / int256(collateralAssetPrice)) * 1e18) / int256(_supplyAmount);
  }
}

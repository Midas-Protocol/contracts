// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./ILeveredPositionFactory.sol";
import "./LeveredPosition.sol";
import "../SafeOwnableUpgradeable.sol";
import "../../compound/IFuseFeeDistributor.sol";

import "../../liquidators/registry/LiquidatorsRegistry.sol";
import "../../liquidators/SolidlySwapLiquidator.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LeveredPositionFactory is ILeveredPositionFactory, SafeOwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using EnumerableSet for EnumerableSet.AddressSet;

  IFuseFeeDistributor public ffd;
  LiquidatorsRegistry public liquidatorsRegistry;
  uint256 public blocksPerYear;

  mapping(address => EnumerableSet.AddressSet) private positionsByAccount;
  EnumerableSet.AddressSet private collaterals;
  mapping(ICErc20 => EnumerableSet.AddressSet) private borrowableMarketsByCollateral;

  /*----------------------------------------------------------------
                        Initializer Functions
  ----------------------------------------------------------------*/

  constructor() {
    _disableInitializers();
  }

  function initialize(IFuseFeeDistributor _ffd, LiquidatorsRegistry _registry, uint256 _blocksPerYear) public initializer {
    __SafeOwnable_init(msg.sender);
    ffd = _ffd;
    liquidatorsRegistry = _registry;
    blocksPerYear = _blocksPerYear;
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function createPosition(ICErc20 _collateralMarket, ICErc20 _stableMarket) public returns (LeveredPosition) {
    require(borrowableMarketsByCollateral[_collateralMarket].contains(address(_stableMarket)), "!pair not whitelisted");

    LeveredPosition position = new LeveredPosition(msg.sender, _collateralMarket, _stableMarket);
    positionsByAccount[msg.sender].add(address(position));
    return position;
  }

  function createAndFundPosition(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    IERC20Upgradeable _fundingAsset,
    uint256 _fundingAmount
  ) public returns (LeveredPosition) {
    LeveredPosition position = createPosition(_collateralMarket, _stableMarket);
    _fundingAsset.safeTransferFrom(msg.sender, address(this), _fundingAmount);
    _fundingAsset.approve(address(position), _fundingAmount);
    position.fundPosition(_fundingAsset, _fundingAmount);
    return position;
  }

  // @return true if removed, otherwise false
  function removeClosedPosition(address closedPosition) public returns (bool) {
    EnumerableSet.AddressSet storage userPositions = positionsByAccount[msg.sender];
    require(userPositions.contains(closedPosition), "!no such position");
    require(LeveredPosition(closedPosition).isPositionClosed(), "!not closed");

    return userPositions.remove(closedPosition);
  }

  /*----------------------------------------------------------------
                            View Functions
  ----------------------------------------------------------------*/

  function getPositionsByAccount(address account) public view returns (address[] memory) {
    return positionsByAccount[account].values();
  }

  function getWhitelistedCollateralMarkets() public view returns (address[] memory) {
    return collaterals.values();
  }

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) public view returns (bool) {
    return liquidatorsRegistry.hasRedemptionStrategyForTokens(inputToken, outputToken);
  }

  function getMinBorrowNative() external view returns (uint256) {
    return ffd.minBorrowEth();
  }

  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy strategy, bytes memory strategyData)
  {
    return liquidatorsRegistry.getRedemptionStrategy(inputToken, outputToken);
  }

  function getBorrowRateAfter(ICErc20 _stableMarket, uint256 borrowAmount) public view returns (uint256) {
    return _stableMarket.borrowRatePerBlockAfterBorrow(borrowAmount) * blocksPerYear;
  }

  /*----------------------------------------------------------------
                            Admin Functions
  ----------------------------------------------------------------*/

  function _setPairWhitelisted(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    bool _whitelisted
  ) public onlyOwner {
    if (_whitelisted) {
      collaterals.add(address(_collateralMarket));
      borrowableMarketsByCollateral[_collateralMarket].add(address(_stableMarket));
    }
    else{
      borrowableMarketsByCollateral[_collateralMarket].remove(address(_stableMarket));
      if (borrowableMarketsByCollateral[_collateralMarket].length() == 0) collaterals.remove(address(_collateralMarket));
    }
  }
}

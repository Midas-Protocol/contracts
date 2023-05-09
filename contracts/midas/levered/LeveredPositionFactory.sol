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

  mapping(address => EnumerableSet.AddressSet) private positionsByAccount;
  mapping(ICErc20 => mapping(ICErc20 => bool)) public marketsPairsWhitelist;

  /*----------------------------------------------------------------
                        Initializer Functions
  ----------------------------------------------------------------*/

  constructor() {
    _disableInitializers();
  }

  function initialize(IFuseFeeDistributor _ffd, LiquidatorsRegistry _registry) public initializer {
    __SafeOwnable_init(msg.sender);
    ffd = _ffd;
    liquidatorsRegistry = _registry;
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function createPosition(ICErc20 _collateralMarket, ICErc20 _stableMarket) public returns (LeveredPosition) {
    require(marketsPairsWhitelist[_collateralMarket][_stableMarket], "!pair not valid");

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

  /*----------------------------------------------------------------
                            Admin Functions
  ----------------------------------------------------------------*/

  function _setPairWhitelisted(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    bool _whitelisted
  ) public onlyOwner {
    marketsPairsWhitelist[_collateralMarket][_stableMarket] = _whitelisted;
  }
}

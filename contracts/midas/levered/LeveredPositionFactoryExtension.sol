// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "../../midas/DiamondExtension.sol";
import { LeveredPositionFactoryStorage } from "./LeveredPositionFactoryStorage.sol";
import { ILeveredPositionFactoryExtension } from "./ILeveredPositionFactory.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { LeveredPosition } from "./LeveredPosition.sol";
import { IComptroller, IPriceOracle } from "../../external/compound/IComptroller.sol";
import { ILiquidatorsRegistry } from "../../liquidators/registry/ILiquidatorsRegistry.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract LeveredPositionFactoryExtension is
  LeveredPositionFactoryStorage,
  DiamondExtension,
  ILeveredPositionFactoryExtension
{
  using SafeERC20Upgradeable for IERC20Upgradeable;
  using EnumerableSet for EnumerableSet.AddressSet;

  error PairNotWhitelisted();
  error NoSuchPosition();
  error PositionNotClosed();

  // @notice maximum slippage in swaps, in bps
  uint256 public constant MAX_SLIPPAGE = 900; // 9%

  function _getExtensionFunctions() external pure override returns (bytes4[] memory) {
    uint8 fnsCount = 12;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.createPosition.selector;
    functionSelectors[--fnsCount] = this.createAndFundPosition.selector;
    functionSelectors[--fnsCount] = this.createAndFundPositionAtRatio.selector;
    functionSelectors[--fnsCount] = this.removeClosedPosition.selector;
    functionSelectors[--fnsCount] = this.isFundingAllowed.selector;
    functionSelectors[--fnsCount] = this.getMinBorrowNative.selector;
    functionSelectors[--fnsCount] = this.getRedemptionStrategies.selector;
    functionSelectors[--fnsCount] = this.getSlippage.selector;
    functionSelectors[--fnsCount] = this.getBorrowableMarketsByCollateral.selector;
    functionSelectors[--fnsCount] = this.getWhitelistedCollateralMarkets.selector;
    functionSelectors[--fnsCount] = this.getAccountsWithOpenPositions.selector;
    functionSelectors[--fnsCount] = this.getPositionsByAccount.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function createPosition(ICErc20 _collateralMarket, ICErc20 _stableMarket) public returns (LeveredPosition) {
    if (!borrowableMarketsByCollateral[_collateralMarket].contains(address(_stableMarket))) revert PairNotWhitelisted();

    LeveredPosition position = new LeveredPosition(msg.sender, _collateralMarket, _stableMarket);

    accountsWithOpenPositions.add(msg.sender);
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

  function createAndFundPositionAtRatio(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    IERC20Upgradeable _fundingAsset,
    uint256 _fundingAmount,
    uint256 _leverageRatio
  ) external returns (LeveredPosition) {
    LeveredPosition position = createAndFundPosition(_collateralMarket, _stableMarket, _fundingAsset, _fundingAmount);
    position.adjustLeverageRatio(_leverageRatio);
    return position;
  }

  // @return true if removed, otherwise false
  function removeClosedPosition(address closedPosition) external returns (bool removed) {
    EnumerableSet.AddressSet storage userPositions = positionsByAccount[msg.sender];
    if (!userPositions.contains(closedPosition)) revert NoSuchPosition();
    if (!LeveredPosition(closedPosition).isPositionClosed()) revert PositionNotClosed();

    removed = userPositions.remove(closedPosition);
    if (userPositions.length() == 0) accountsWithOpenPositions.remove(msg.sender);
  }

  /*----------------------------------------------------------------
                            View Functions
  ----------------------------------------------------------------*/

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external view returns (bool) {
    return liquidatorsRegistry.isRedemptionPathSupported(inputToken, outputToken);
  }

  function getMinBorrowNative() external view returns (uint256) {
    return fuseFeeDistributor.minBorrowEth();
  }

  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData)
  {
    return liquidatorsRegistry.getRedemptionStrategies(inputToken, outputToken);
  }

  function getSlippage(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (uint256 slippage)
  {
    slippage = conversionSlippage[inputToken][outputToken];
    if (slippage == 0) return MAX_SLIPPAGE;
  }

  function getPositionsByAccount(address account) external view returns (address[] memory positions, bool[] memory closed) {
    positions = positionsByAccount[account].values();
    closed = new bool[](positions.length);
    for (uint256 i = 0; i < positions.length; i++) {
      closed[i] = LeveredPosition(positions[i]).isPositionClosed();
    }
  }

  function getAccountsWithOpenPositions() external view returns (address[] memory) {
    return accountsWithOpenPositions.values();
  }

  function getWhitelistedCollateralMarkets() external view returns (address[] memory) {
    return collateralMarkets.values();
  }

  function getBorrowableMarketsByCollateral(ICErc20 _collateralMarket) external view returns (address[] memory) {
    return borrowableMarketsByCollateral[_collateralMarket].values();
  }
}

// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./ILeveredPositionFactory.sol";
import "./LeveredPosition.sol";
import "../SafeOwnableUpgradeable.sol";
import "../../compound/IFuseFeeDistributor.sol";
import { IRouter } from "../../external/solidly/IRouter.sol";

import "../../liquidators/SolidlySwapLiquidator.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LeveredPositionFactory is ILeveredPositionFactory, SafeOwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IFuseFeeDistributor public ffd;

  mapping(ICErc20 => mapping(ICErc20 => bool)) public marketsPairsWhitelist;
  mapping(address => LeveredPosition[]) public positionsByAccount;
  mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => IRedemptionStrategy)) public redemptionStrategies;

  // TODO store here?
  IRedemptionStrategy public solidlyLiquidator;

  /*----------------------------------------------------------------
                        Initializer Functions
  ----------------------------------------------------------------*/

  constructor() {
    _disableInitializers();
  }

  function initialize(IFuseFeeDistributor _ffd) public initializer {
    __SafeOwnable_init(msg.sender);
    ffd = _ffd;

    solidlyLiquidator = new SolidlySwapLiquidator();
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function createPosition(ICErc20 _collateralMarket, ICErc20 _stableMarket) public returns (LeveredPosition) {
    require(isValidPair(_collateralMarket, _stableMarket), "!pair not valid");

    LeveredPosition position = new LeveredPosition(msg.sender, _collateralMarket, _stableMarket);
    LeveredPosition[] storage userPositions = positionsByAccount[msg.sender];
    userPositions.push(position);
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

  /*----------------------------------------------------------------
                            View Functions
  ----------------------------------------------------------------*/

  function isValidPair(ICErc20 _collateralMarket, ICErc20 _stableMarket) public view returns (bool) {
    return marketsPairsWhitelist[_collateralMarket][_stableMarket];
  }

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) public view returns (bool) {
    return address(redemptionStrategies[inputToken][outputToken]) != address(0);
  }

  function getMinBorrowNative() external view returns (uint256) {
    return ffd.minBorrowEth();
  }

  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy strategy, bytes memory strategyData)
  {
    strategy = redemptionStrategies[inputToken][outputToken];
    if (address(strategy) == address(solidlyLiquidator)) {
      IRouter solidlyRouter = IRouter(0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109);
      address tokenTo = address(outputToken);

      // Check if stable pair exists
      address volatilePair = solidlyRouter.pairFor(address(inputToken), tokenTo, false);
      address stablePair = solidlyRouter.pairFor(address(inputToken), tokenTo, true);

      require(
        solidlyRouter.isPair(stablePair) || solidlyRouter.isPair(volatilePair),
        "Invalid SolidlyLiquidator swap path."
      );

      bool stable;
      if (!solidlyRouter.isPair(stablePair)) {
        stable = false;
      } else if (!solidlyRouter.isPair(volatilePair)) {
        stable = true;
      } else {
        (uint256 stableR0, uint256 stableR1) = solidlyRouter.getReserves(address(inputToken), tokenTo, true);
        (uint256 volatileR0, uint256 volatileR1) = solidlyRouter.getReserves(address(inputToken), tokenTo, false);
        // Determine which swap has higher liquidity
        if (stableR0 > volatileR0 && stableR1 > volatileR1) {
          stable = true;
        } else {
          stable = false;
        }
      }

      strategyData = abi.encode(solidlyRouter, outputToken, stable);
    }
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

  function _addRedemptionStrategy(
    IRedemptionStrategy strategy,
    IERC20Upgradeable inputToken,
    IERC20Upgradeable outputToken
  ) public onlyOwner {
    redemptionStrategies[inputToken][outputToken] = strategy;
  }

  function _addRedemptionStrategies(
    IRedemptionStrategy[] calldata strategies,
    IERC20Upgradeable[] calldata inputTokens,
    IERC20Upgradeable[] calldata outputTokens
  ) public onlyOwner {
    require(strategies.length == inputTokens.length && inputTokens.length == outputTokens.length, "!arrays len");

    for (uint256 i = 0; i < strategies.length; i++) {
      redemptionStrategies[inputTokens[i]][outputTokens[i]] = strategies[i];
    }
  }
}

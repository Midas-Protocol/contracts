// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./ILeveredPositionFactory.sol";
import "./LeveredPosition.sol";
import "../SafeOwnableUpgradeable.sol";
import "../../compound/IFuseFeeDistributor.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LeveredPositionFactory is ILeveredPositionFactory, SafeOwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IFuseFeeDistributor public ffd;

  mapping(ICErc20 => mapping(ICErc20 => bool)) public marketsPairsWhitelist;
  mapping(address => LeveredPosition[]) public positionsByAccount;
  mapping(IERC20Upgradeable => mapping(IERC20Upgradeable => IRedemptionStrategy)) public redemptionStrategies;

  function initialize(IFuseFeeDistributor _ffd) public initializer {
    __SafeOwnable_init(msg.sender);
    ffd = _ffd;
  }

  function createPosition(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket
  ) public returns (LeveredPosition) {
    require(isValidPair(_collateralMarket, _stableMarket), "!pair not valid");

    LeveredPosition levPos = new LeveredPosition(msg.sender, _collateralMarket, _stableMarket);
    LeveredPosition[] storage userPositions = positionsByAccount[msg.sender];
    userPositions.push(levPos);
    return levPos;
  }

  function createAndFundPosition(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    IERC20Upgradeable _fundingAsset,
    uint256 _fundingAmount
  ) public returns (LeveredPosition) {
    LeveredPosition levPos = createPosition(_collateralMarket, _stableMarket);
    _fundingAsset.safeTransferFrom(msg.sender, address(this), _fundingAmount);
    _fundingAsset.approve(address(levPos), _fundingAmount);
    levPos.fundPosition(_fundingAsset, _fundingAmount);
    return levPos;
  }

  function isValidPair(ICErc20 _collateralMarket, ICErc20 _stableMarket) public view returns (bool) {
    return marketsPairsWhitelist[_collateralMarket][_stableMarket];
  }

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) public view returns (bool) {
    return address(redemptionStrategies[inputToken][outputToken]) != address(0);
  }

  function _setPairWhitelisted(ICErc20 _collateralMarket, ICErc20 _stableMarket, bool _whitelisted) public onlyOwner {
    marketsPairsWhitelist[_collateralMarket][_stableMarket] = _whitelisted;
  }

  function getMinBorrowNative() external view returns (uint256) {
    return ffd.minBorrowEth();
  }

  function _addRedemptionStrategy(IRedemptionStrategy strategy, IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) public onlyOwner {
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

  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
  external
  view
  returns (IRedemptionStrategy strategy, bytes memory strategyData) {

  }
}
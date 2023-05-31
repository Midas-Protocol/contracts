// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { ICErc20 } from "../../compound/CTokenInterfaces.sol";
import { LeveredPosition } from "./LeveredPosition.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ILeveredPositionFactory {
  function getRedemptionStrategies(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy[] memory strategies, bytes[] memory strategiesData);

  function getMinBorrowNative() external view returns (uint256);

  function createPosition(ICErc20 _collateralMarket, ICErc20 _stableMarket) external returns (LeveredPosition);

  function createAndFundPosition(
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket,
    IERC20Upgradeable _fundingAsset,
    uint256 _fundingAmount
  ) external returns (LeveredPosition);

  function isFundingAllowed(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external view returns (bool);

  function getSlippage(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken) external view returns (uint256);
}

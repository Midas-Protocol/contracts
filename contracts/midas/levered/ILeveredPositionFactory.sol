// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IFundsConversionStrategy, IRedemptionStrategy } from "../../liquidators/IFundsConversionStrategy.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ILeveredPositionFactory {
  function getRedemptionStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    external
    view
    returns (IRedemptionStrategy fundingStrategy, bytes memory strategyData);

  function getMinBorrowNative() external view returns (uint256);
}

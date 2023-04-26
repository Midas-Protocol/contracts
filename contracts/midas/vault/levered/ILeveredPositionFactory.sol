// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IFundsConversionStrategy } from "../../../liquidators/IFundsConversionStrategy.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ILeveredPositionFactory {
  function getFundingStrategy(
    IERC20Upgradeable fundingToken
  ) external returns (IFundsConversionStrategy fundingStrategy, bytes memory strategyData);
}

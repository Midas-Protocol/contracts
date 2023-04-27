// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IFundsConversionStrategy } from "../../../liquidators/IFundsConversionStrategy.sol";
import { IFlashLoanStrategy } from "../../../flashloan/IFlashLoanStrategy.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ILeveredPositionFactory {
  function getFundingStrategy(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
  external
  returns (IFundsConversionStrategy fundingStrategy, bytes memory strategyData);

  function getFlashLoanStrategy(IERC20Upgradeable tokenToBorrow) external returns (IFlashLoanStrategy strategy);
}

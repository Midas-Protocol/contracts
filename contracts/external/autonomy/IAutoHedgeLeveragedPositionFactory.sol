// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IComptroller } from "../compound/IComptroller.sol";
import "./IFlashloanWrapper.sol";
import "../../oracles/MasterPriceOracle.sol";
import "./IAutoHedgeLeveragedPosition.sol";

interface IAutoHedgeLeveragedPositionFactory {
  event LeveragedPositionCreated(address indexed creator, address lvgPos);

  function flw() external view returns (IFlashloanWrapper);

  function oracle() external view returns (MasterPriceOracle);

  function createLeveragedPosition(IComptroller comptroller, IAutoHedgeLeveragedPosition.TokensLev memory tokens_)
    external
    returns (address lvgPos);
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { IComptroller } from "../compound/IComptroller.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import "./IAutoHedgeStableVolatilePairUpgradeableV2.sol";
import "./IFlashloanWrapper.sol";
import { IAutoHedgeLeveragedPositionFactory } from "./IAutoHedgeLeveragedPositionFactory.sol";

interface IAutoHedgeLeveragedPosition {
  struct TokensLev {
    IERC20Metadata stable;
    ICErc20 cStable;
    IERC20Metadata vol;
    ICErc20 cVol;
    IAutoHedgeStableVolatilePairUpgradeableV2 pair;
    ICErc20 cAhlp;
  }

  struct FinishDeposit {
    IFlashloanWrapper.FinishRoute fr;
    uint256 amountStableDeposit;
    uint256 amountStableToFlashloan;
    address referrer;
    uint256 flashloanFee;
  }

  struct FinishWithdraw {
    IFlashloanWrapper.FinishRoute fr;
    uint256 amountAhlpRedeem;
    uint256 amountStableToFlashloan;
    uint256 flashloanFee;
  }

  event DepositLev(
    address indexed pair,
    uint256 amountStableDeposit,
    uint256 amountStableFlashloan,
    uint256 leverageRatio
  );

  function initialize(
    IAutoHedgeLeveragedPositionFactory factory_,
    IComptroller comptroller,
    TokensLev memory tokens_
  ) external;

  function finishDeposit(bytes calldata data) external;

  function finishWithdraw(bytes calldata data) external;
}

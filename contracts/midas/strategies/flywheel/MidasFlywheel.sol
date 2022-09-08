// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { IFlywheelRewards } from "flywheel/interfaces/IFlywheelRewards.sol";
import { IFlywheelBooster } from "flywheel/interfaces/IFlywheelBooster.sol";
import { MidasFlywheelCore } from "./MidasFlywheelCore.sol";

contract MidasFlywheel is MidasFlywheelCore {
  bool public constant isRewardsDistributor = true;

  bool public constant isFlywheel = true;

  function flywheelPreSupplierAction(ERC20 market, address supplier) external {
    accrue(market, supplier);
  }

  function flywheelPreBorrowerAction(ERC20 market, address borrower) external {}

  function flywheelPreTransferAction(
    ERC20 market,
    address src,
    address dst
  ) external {
    accrue(market, src, dst);
  }

  function compAccrued(address user) external view returns (uint256) {
    return rewardsAccrued[user];
  }

  function addMarketForRewards(ERC20 strategy) external {
    _addStrategyForRewards(strategy);
  }

  function marketState(ERC20 strategy) external view returns (RewardsState memory) {
    return strategyState[strategy];
  }
}

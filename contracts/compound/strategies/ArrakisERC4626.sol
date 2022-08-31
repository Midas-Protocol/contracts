// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { RewardsClaimer } from "./RewardsClaimer.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IGuniPool {
  function deposit(uint256) external;

  function withdraw(uint256) external;

  function stake(address) external view returns (uint256);

  function totalStake() external view returns (uint256);

  function _users(address) external view returns (uint256, uint256);

  function pendingMIMO(address) external view returns (uint256);

  function releaseMIMO(address) external;
}

contract ArrakisERC4626 is MidasERC4626, RewardsClaimer {
  using SafeERC20Upgradeable for ERC20Upgradeable;
  using FixedPointMathLib for uint256;

  IGuniPool public pool;
  FlywheelCore public flywheel;

  function initialize(
    ERC20Upgradeable asset,
    FlywheelCore _flywheel,
    IGuniPool _pool,
    address _rewardsDestination,
    ERC20Upgradeable[] memory _rewardTokens
  ) public initializer {
    __MidasER4626_init(asset);
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);

    pool = _pool;
    flywheel = _flywheel;
    asset.approve(address(pool), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {
    return paused() ? _asset().balanceOf(address(this)) : pool.stake(address(this));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    pool.deposit(amount);
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    pool.withdraw(amount);
  }

  function beforeClaim() internal override {
    pool.releaseMIMO(address(this));
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    pool.withdraw(pool.stake(address(this)));
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    pool.deposit(_asset().balanceOf(address(this)));
  }
}

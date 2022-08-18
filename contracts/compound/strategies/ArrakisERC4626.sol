// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { MidasERC4626 } from "./MidasERC4626.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { RewardsClaimer } from "fuse-flywheel/utils/RewardsClaimer.sol";

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
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  IGuniPool public immutable pool;
  FlywheelCore public immutable flywheel;

  constructor(ERC20 _asset, FlywheelCore _flywheel, IGuniPool _pool, address _rewardsDestination, ERC20[] memory _rewardTokens)
    MidasERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol()))
    )
    RewardsClaimer(_rewardsDestination, _rewardTokens)
  {
    pool = _pool;
    flywheel = _flywheel;
    asset.approve(address(pool), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {
    return paused() ? asset.balanceOf(address(this)) : pool.stake(address(this));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
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
    pool.deposit(asset.balanceOf(address(this)));
  }
}

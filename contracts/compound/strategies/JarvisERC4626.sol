// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { RewardsClaimer } from "./RewardsClaimer.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IElysianFields {
  function deposit(uint256, uint256) external;

  function withdraw(uint256, uint256) external;

  function userInfo(uint256, address) external view returns (uint256, uint256);

  function pendingRwd(uint256, address) external view returns (uint256);

  function safeRewardTransfer(address, uint256) external;
}

contract JarvisERC4626 is MidasERC4626, RewardsClaimer {
  using SafeERC20Upgradeable for ERC20Upgradeable;
  using FixedPointMathLib for uint256;

  uint256 public poolId;
  IElysianFields public vault;
  FlywheelCore public flywheel;

  function initialize(
    ERC20Upgradeable asset,
    FlywheelCore _flywheel,
    IElysianFields _vault,
    uint256 _poolId,
    address _rewardsDestination,
    ERC20Upgradeable[] memory _rewardTokens
  ) public initializer {
    __MidasER4626_init(asset);
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);

    vault = _vault;
    flywheel = _flywheel;
    poolId = _poolId;
    asset.approve(address(vault), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return _asset().balanceOf(address(this));
    }

    (uint256 amount, ) = vault.userInfo(poolId, address(this));

    return amount;
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    vault.deposit(poolId, amount);
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    vault.withdraw(poolId, amount);
  }

  function beforeClaim() internal override {
    uint256 pendingRwd = vault.pendingRwd(poolId, address(this));
    vault.safeRewardTransfer(address(this), pendingRwd);
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    (uint256 amount, ) = vault.userInfo(poolId, address(this));
    vault.withdraw(poolId, amount);
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    vault.deposit(poolId, _asset().balanceOf(address(this)));
  }
}

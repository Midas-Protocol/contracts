// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { RewardsClaimer } from "fuse-flywheel/utils/RewardsClaimer.sol";

interface IStellaDistributorV2 {
  function deposit(uint256 _pid, uint256 _amount) external;

  function withdraw(uint256 _pid, uint256 _amount) external;

  function userInfo(uint256 _pid, address _owner) external view returns (
    uint256 amount, // How many LP tokens the user has provided.
    uint256 rewardDebt, // Reward debt. See explanation below.
    uint256 rewardLockedUp, // Reward locked up.
    uint256 nextHarvestUntil // When can the user harvest again.
  );

  function pendingTokens(uint256 _pid, address _user) external view returns (
    address[] memory addresses,
    string[] memory symbols,
    uint256[] memory decimals,
    uint256[] memory amounts
  );

  function poolTotalLp(uint256 _pid) external view returns (uint256);
}

contract StellaLpERC4626 is MidasERC4626, RewardsClaimer {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  FlywheelCore[] public flywheels;
  IStellaDistributorV2 public immutable distributor;
  uint256 public immutable poolId;
  address[] public assetsAsArray;

  constructor(
    ERC20 _asset,
    FlywheelCore[] memory _flywheels,
    IStellaDistributorV2 _distributor,
    uint256 _poolId,
    address _rewardsDestination,
    ERC20[] memory _rewardTokens
  ) 
    MidasERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol))
    )
    RewardsClaimer(_rewardsDestination, _rewardTokens)
  {
    flywheels = _flywheels;
    distributor = _distributor;
    poolId = _poolId;

    assetsAsArray.push(address(_asset));

    asset.approve(address(distributor), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return asset.balanceOf(address(this));
    } else {
      (uint256 amount, , , ) = distributor.userInfo(poolId, address(this));
      return amount;
    }
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    distributor.deposit(poolId, amount);
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    distributor.withdraw(poolId, amount);
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    (uint256 amount, , , ) = distributor.userInfo(poolId, address(this));
    distributor.withdraw(poolId, amount);
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    distributor.deposit(poolId, asset.balanceOf(address(this)));
  }
}
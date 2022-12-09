// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { RewardsClaimer } from "../RewardsClaimer.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

struct UserInfo {
  uint256 amount;
  int256 rewardDebt;
}

interface IRewarder {
  function pendingTokens(
    uint256,
    address,
    uint256
  ) external view returns (address[] memory, uint256[] memory);
}

interface IMiniChefV2 {
  function userInfo(uint256 pid, address user) external view returns (UserInfo memory);

  function deposit(
    uint256 pid,
    uint256 amount,
    address to
  ) external;

  function withdraw(
    uint256 pid,
    uint256 amount,
    address to
  ) external;

  function withdrawAndHarvest(
    uint256 pid,
    uint256 amount,
    address to
  ) external;

  function rewarder(uint256) external view returns (IRewarder);

  function lpToken(uint256) external view returns (address);

  function poolLength() external view returns (uint256);

  function harvest(uint256, address) external;

  function pendingDiffusion(uint256, address) external view returns (uint256);
}

/**
 * @title MiniChef ERC4626 Contract
 * @notice ERC4626 wrapper for MiniChef Contracts
 * @author RedVeil
 *
 * Wraps https://github.com/kinesis-labs/kinesis-contract/blob/main/contracts/rewards/MiniChefV2.sol
 *
 */
contract MiniChefERC4626 is MidasERC4626, RewardsClaimer {
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  uint256 public poolId;
  IMiniChefV2 public miniChef;

  /* ========== INITIALIZER ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _poolId The poolId in AutofarmV2
     @param _miniChef Kenisis MiniChefV2 contract
    */
  function initialize(
    ERC20Upgradeable _asset,
    uint256 _poolId,
    IMiniChefV2 _miniChef,
    address _rewardsDestination,
    ERC20Upgradeable[] memory _rewardTokens
  ) public initializer {
    __MidasER4626_init(_asset);
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);

    poolId = _poolId;
    miniChef = _miniChef;

    _asset.approve(address(miniChef), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return _asset().balanceOf(address(this));
    }

    return miniChef.userInfo(poolId, address(this)).amount;
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    miniChef.deposit(poolId, amount, address(this));
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    miniChef.withdraw(poolId, amount, address(this));
  }

  function beforeClaim() internal override {
    miniChef.harvest(poolId, address(this));
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    uint256 amount = miniChef.userInfo(poolId, address(this)).amount;
    miniChef.withdrawAndHarvest(poolId, amount, address(this));
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    miniChef.deposit(poolId, _asset().balanceOf(address(this)), address(this));
  }
}

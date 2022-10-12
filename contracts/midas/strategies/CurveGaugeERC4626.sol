// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { RewardsClaimer } from "../RewardsClaimer.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface IChildGauge {
  function deposit(
    uint256 amount,
    address user,
    bool claim_rewards
  ) external;

  function withdraw(
    uint256 amount,
    address user,
    bool claim_rewards
  ) external;

  function claim_rewards() external;

  function lp_token() external view returns (address);

  function balanceOf(address user) external view returns (uint256);
}

/**
 * @title Curve Gauge ERC4626 Contract
 * @notice ERC4626 Strategy using Curves Gauge. Allows depositing LP-Token to earn additional rewards
 * @author RedVeil
 *
 * Stakes and withdraws deposited LP-Token in/from https://github.com/curvefi/curve-xchain-factory/blob/master/contracts/implementations/ChildGauge.vy
 * and claims rewards from the same contract
 *
 */
contract CurveGaugeERC4626 is MidasERC4626, RewardsClaimer {
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  IChildGauge public gauge;

  /* ========== INITIALIZER ========== */

  /**
     @notice Initializes the Vault.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _gauge The Curve Gauge which accepts the `asset`.
     @param _rewardsDestination The address to send rewards to.
     @param _rewardTokens The rewardsToken which will be send to `rewardsDestination`.
    */
  function initialize(
    ERC20Upgradeable _asset,
    IChildGauge _gauge,
    address _rewardsDestination,
    ERC20Upgradeable[] memory _rewardTokens
  ) public initializer {
    require(address(_asset) == _gauge.lp_token(), "asset != lpToken");

    __MidasER4626_init(_asset);
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);

    performanceFee = 5e16;
    gauge = _gauge;

    _asset.approve(address(_gauge), type(uint256).max);
  }

  function reinitialize() public reinitializer(2) onlyOwner {
    performanceFee = 5e16;
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return paused() ? _asset().balanceOf(address(this)) : gauge.balanceOf(address(this));
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    gauge.deposit(amount, address(this), true);
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    gauge.withdraw(amount, address(this), true);
  }

  function beforeClaim() internal override {
    gauge.claim_rewards();
  }

  /* ========== EMERGENCY FUNCTIONS ========== */

  function emergencyWithdrawAndPause() external override onlyOwner {
    gauge.withdraw(gauge.balanceOf(address(this)), address(this), true);
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    gauge.deposit(_asset().balanceOf(address(this)), address(this), true);
  }
}

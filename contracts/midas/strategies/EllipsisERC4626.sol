// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface ILpTokenStaker {
  function rewardToken() external view returns (ERC20Upgradeable);

  function userInfo(ERC20Upgradeable _token, address _user) external view returns (uint256, uint256);

  function balanceOf(address) external returns (uint256);

  // Deposit LP tokens into the contract. Also triggers a claim.
  function deposit(
    ERC20Upgradeable _token,
    uint256 _amount,
    bool _claimRewards
  ) external returns (uint256);

  // Withdraw LP tokens. Also triggers a claim.
  function withdraw(
    ERC20Upgradeable _token,
    uint256 _amount,
    bool _claimRewards
  ) external returns (uint256);
}

/**
 * @title Ellipsis ERC4626 Contract
 * @notice ERC4626 Strategy for Ellipsis LP-Staking
 * @author RedVeil
 *
 * Stakes and withdraws deposited LP-Token in/from https://github.com/ellipsis-finance/ellipsis/blob/master/contracts/LpTokenStaker.sol
 * and claims rewards from https://github.com/ellipsis-finance/ellipsis/blob/master/contracts/EpsStaker.sol
 *
 */
contract EllipsisERC4626 is MidasERC4626 {
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  ILpTokenStaker public lpTokenStaker;
  FlywheelCore public flywheel;

  /* ========== INITIALIZER ========== */

  /**
     @notice Initializes the Vault.
     @param asset The ERC20 compliant token the Vault should accept.
     @param _flywheel Flywheel to pull EPX rewards
     @param _lpTokenStaker LpTokenStaker contract from Ellipsis
    */
  function initialize(
    ERC20Upgradeable asset,
    FlywheelCore _flywheel,
    ILpTokenStaker _lpTokenStaker
  ) public initializer {
    __MidasER4626_init(asset);

    lpTokenStaker = _lpTokenStaker;
    flywheel = _flywheel;

    asset.approve(address(lpTokenStaker), type(uint256).max);
    lpTokenStaker.rewardToken().approve(address(flywheel.flywheelRewards()), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    (uint256 amount, ) = lpTokenStaker.userInfo(_asset(), address(this));
    return amount;
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    lpTokenStaker.deposit(_asset(), amount, true);
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    lpTokenStaker.withdraw(_asset(), amount, true);
  }

  /* Comment out for now
   * Todo: needs test for verification
   */

  // function emergencyWithdrawAndPause() external override onlyOwner {
  //   lpTokenStaker.withdraw(_asset(), lpTokenStaker.balanceOf(address(this)), true);
  //   _pause();
  // }

  // function unpause() external override onlyOwner {
  //   _unpause();
  //   lpTokenStaker.deposit(_asset(), _asset().balanceOf(address(this)), true);
  // }
}

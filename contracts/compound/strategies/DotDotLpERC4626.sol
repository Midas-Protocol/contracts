// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";
import { RewardsClaimer } from "fuse-flywheel/utils/RewardsClaimer.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface ILpDepositor {
  // user -> pool -> deposit amount
  function userBalances(address _user, ERC20Upgradeable _token) external view returns (uint256);

  function deposit(
    address _user,
    ERC20Upgradeable _token,
    uint256 _amount
  ) external;

  function withdraw(
    address _receiver,
    ERC20Upgradeable _token,
    uint256 _amount
  ) external;

  function claim(
    address _receiver,
    ERC20Upgradeable[] calldata _tokens,
    uint256 _maxBondAmount
  ) external;

  function depositTokens(ERC20Upgradeable lpToken) external view returns (ERC20Upgradeable);
}

/**
 * @title DotDot LpToken ERC4626 Contract
 * @notice ERC4626 Strategy using DotDotFinance for Ellipsis LP-Token
 * @author RedVeil
 *
 * Stakes and withdraws deposited LP-Token in/from https://github.com/dotdot-ellipsis/dotdot-contracts/blob/main/contracts/LpDepositor.sol
 * and claims rewards from the same contract
 *
 */
contract DotDotLpERC4626 is MidasERC4626, RewardsClaimer {
  using SafeERC20Upgradeable for ERC20Upgradeable;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  FlywheelCore public dddFlywheel;
  FlywheelCore public epxFlywheel;
  ILpDepositor public lpDepositor;
  ERC20Upgradeable[] public assetAsArray;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param asset The ERC20 compliant token the Vault should accept.
     @param _dddFlywheel Flywheel to pull DDD rewards
     @param _epxFlywheel Flywheel to pull EPX rewards
     @param _lpDepositor DotDot deposit contract for LpToken
    */
  function initialize(
    ERC20Upgradeable asset,
    FlywheelCore _dddFlywheel,
    FlywheelCore _epxFlywheel,
    ILpDepositor _lpDepositor,
    address _rewardsDestination,
    ERC20Upgradeable[] memory _rewardTokens
  ) public initializer {
    __MidasER4626_init(asset);
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);

    dddFlywheel = _dddFlywheel;
    epxFlywheel = _epxFlywheel;
    lpDepositor = _lpDepositor;

    // lpDepositor wants an address array for claiming
    assetAsArray.push(asset);

    asset.approve(address(lpDepositor), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return paused() ? _asset().balanceOf(address(this)) : lpDepositor.userBalances(address(this), _asset());
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    lpDepositor.deposit(address(this), _asset(), amount);
    lpDepositor.claim(address(this), assetAsArray, 0);
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    lpDepositor.withdraw(address(this), _asset(), amount);
    lpDepositor.claim(address(this), assetAsArray, 0);
  }

  function beforeClaim() internal override {
    lpDepositor.claim(address(this), assetAsArray, 0);
  }

  /* ========== EMERGENCY FUNCTIONS ========== */

  function emergencyWithdrawAndPause() external override onlyOwner {
    lpDepositor.withdraw(address(this), _asset(), lpDepositor.depositTokens(_asset()).balanceOf(address(this)));
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    lpDepositor.deposit(address(this), _asset(), _asset().balanceOf(address(this)));
  }
}

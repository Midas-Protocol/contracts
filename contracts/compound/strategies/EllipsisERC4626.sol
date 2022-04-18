// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { ERC4626 } from "../../utils/ERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

interface ILpTokenStaker {
  function rewardToken() external view returns (address);

  function userInfo(address _token, address _user) external view returns (uint256, uint256);

  // Deposit LP tokens into the contract. Also triggers a claim.
  function deposit(
    address _token,
    uint256 _amount,
    bool _claimRewards
  ) external returns (uint256);

  // Withdraw LP tokens. Also triggers a claim.
  function withdraw(
    address _token,
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
contract EllipsisERC4626 is ERC4626 {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  ILpTokenStaker public immutable lpTokenStaker;
  FlywheelCore public immutable flywheel;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _name The name for the vault token.
     @param _symbol The symbol for the vault token.
     @param _lpTokenStaker TODO
     @param _flywheel TODO
    */
  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol,
    ILpTokenStaker _lpTokenStaker,
    FlywheelCore _flywheel
  ) ERC4626(_asset, _name, _symbol) {
    lpTokenStaker = _lpTokenStaker;
    flywheel = _flywheel;

    asset.approve(address(lpTokenStaker), type(uint256).max);
    ERC20(lpTokenStaker.rewardToken()).approve(address(flywheel.flywheelRewards()), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    (uint256 amount, ) = lpTokenStaker.userInfo(address(asset), address(this));
    return amount;
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    lpTokenStaker.deposit(address(asset), amount, true);
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    lpTokenStaker.withdraw(address(asset), amount, true);
  }
}

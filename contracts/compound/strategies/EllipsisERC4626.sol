// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.11;

import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";
import { ERC4626 } from "../../utils/ERC4626.sol";
import { SafeTransferLib } from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { IFlywheelCore } from "../../flywheel/interfaces/IFlywheelCore.sol";

interface ILpTokenStaker {
  function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);

  // Deposit LP tokens into the contract. Also triggers a claim.
  function deposit(uint256 _pid, uint256 _amount) external;

  // Withdraw LP tokens. Also triggers a claim.
  function withdraw(uint256 _pid, uint256 _amount) external;
}

interface IEpsStaker {
  // Withdraw staked tokens
  // First withdraws unlocked tokens, then earned tokens. Withdrawing earned tokens
  // incurs a 50% penalty which is distributed based on locked balances.
  function withdraw(uint256 amount) external;

  function stakingToken() external returns (address);

  function totalBalance(address user) external view returns (uint256);
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
  uint256 public immutable poolId;
  ILpTokenStaker public immutable lpTokenStaker;
  IEpsStaker public immutable epsStaker;
  IFlywheelCore public immutable flywheel;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _name The name for the vault token.
     @param _symbol The symbol for the vault token.
     @param _poolId TODO
     @param _lpTokenStaker TODO
     @param _epsStaker TODO
     @param _flywheel TODO
    */
  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol,
    uint256 _poolId,
    ILpTokenStaker _lpTokenStaker,
    IEpsStaker _epsStaker,
    IFlywheelCore _flywheel
  ) ERC4626(_asset, _name, _symbol) {
    poolId = _poolId;
    lpTokenStaker = _lpTokenStaker;
    epsStaker = _epsStaker;
    flywheel = _flywheel;

    asset.approve(address(lpTokenStaker), type(uint256).max);
    ERC20(epsStaker.stakingToken()).approve(address(flywheel.flywheelRewards()), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    (uint256 amount, ) = lpTokenStaker.userInfo(poolId, address(this));
    return amount;
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    lpTokenStaker.deposit(poolId, amount);

    //Total Rewarded EPS
    uint256 totalEPSReward = epsStaker.totalBalance(address(this));
    if (totalEPSReward > 0) {
      //Withdraw totalEPSReward minus 50% penalty
      epsStaker.withdraw(totalEPSReward / 2);
    }
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    lpTokenStaker.withdraw(poolId, amount);

    //Total Rewarded EPS
    uint256 totalEPSReward = epsStaker.totalBalance(address(this));
    if (totalEPSReward > 0) {
      //Withdraw totalEPSReward minus 50% penalty
      epsStaker.withdraw(totalEPSReward / 2);
    }
  }
}

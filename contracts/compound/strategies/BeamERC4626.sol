// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

interface IVault {
  // Info of each user.

  function userInfo(uint256 _pid, address _address)
    external
    view
    returns (
      uint256,
      uint256,
      uint256,
      uint256
    );

  function poolInfo(uint256 _pid)
    external
    view
    returns (
      ERC20Upgradeable,
      uint256,
      uint256,
      uint256,
      uint16,
      uint256,
      uint256
    );

  function balanceOf(address) external returns (uint256);

  function deposit(uint256 _pid, uint256 _amount) external;

  function withdraw(uint256 _pid, uint256 _amount) external;
}

contract BeamERC4626 is MidasERC4626 {
  using SafeERC20Upgradeable for ERC20Upgradeable;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */

  IVault public vault;
  FlywheelCore public flywheelCore;
  uint256 public poolId;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param asset The ERC20 compliant token the Vault should accept.
     @param _flyWheel flyWheelCore that handling rewards for pool.
     @param _poolId pool id on beamswap.
     @param _vault The Vault contract.
    */
  function initialize(
    ERC20Upgradeable asset,
    FlywheelCore _flyWheel,
    uint256 _poolId,
    IVault _vault
  ) public initializer
  {
    __MidasER4626_init(asset);

    vault = _vault;
    poolId = _poolId;
    flywheelCore = _flyWheel;

    asset.approve(address(vault), type(uint256).max);
    _flyWheel.rewardToken().approve(address(_flyWheel.flywheelRewards()), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return _asset().balanceOf(address(this));
    } else {
      (uint256 amount, , , ) = vault.userInfo(poolId, address(this));
      return amount;
    }
  }

  /// @notice Calculates the total amount of underlying tokens the account holds.
  /// @return The total amount of underlying tokens the account holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    vault.deposit(poolId, amount);
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    vault.withdraw(poolId, amount);
  }

  event amount(uint256);

  function emergencyWithdrawAndPause() external override onlyOwner {
    (ERC20Upgradeable lpToken, , , , , , ) = vault.poolInfo(poolId);
    vault.withdraw(poolId, lpToken.balanceOf(address(vault)));
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    vault.deposit(poolId, _asset().balanceOf(address(this)));
  }
}

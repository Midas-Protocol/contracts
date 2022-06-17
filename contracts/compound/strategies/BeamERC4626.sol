// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC4626 } from "solmate/mixins/ERC4626.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

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

  function deposit(uint256 _pid, uint256 _amount) external;

  function withdraw(uint256 _pid, uint256 _amount) external;
}

contract BeamERC4626 is ERC4626 {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */

  IVault public immutable VAULT;
  FlywheelCore public immutable FLYWHEEL_CORE;
  uint256 public immutable POOL_ID;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _flyWheel flyWheelCore that handling rewards for pool.
     @param _poolId pool id on beamswap.
     @param _rewardToken reward token. Used to getting rewards from flyWheel.
     @param _vault The Vault contract.
    */
  constructor(
    ERC20 _asset,
    FlywheelCore _flyWheel,
    uint256 _poolId,
    ERC20 _rewardToken,
    IVault _vault
  ) ERC4626(_asset, _asset.name(), _asset.symbol()) {
    VAULT = _vault;
    POOL_ID = _poolId;
    FLYWHEEL_CORE = _flyWheel;

    asset.approve(address(VAULT), type(uint256).max);
    _rewardToken.approve(address(_flyWheel.flywheelRewards()), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    (uint256 amount, , , ) = VAULT.userInfo(POOL_ID, address(this));
    return amount;
  }

  /// @notice Calculates the total amount of underlying tokens the account holds.
  /// @return The total amount of underlying tokens the account holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    VAULT.deposit(POOL_ID, amount);
  }

  function beforeWithdraw(uint256, uint256 shares) internal override {
    VAULT.withdraw(POOL_ID, shares);
  }
}

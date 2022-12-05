// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC4626 } from "solmate/mixins/ERC4626.sol";
import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface IAutofarmV2 {
  function AUTO() external view returns (address);

  function deposit(uint256 _pid, uint256 _wantAmt) external;

  function withdraw(uint256 _pid, uint256 _wantAmt) external;

  //Returns underlying balance in strategies
  function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256);

  function balanceOf(address) external view returns (uint256);

  function userInfo(uint256, address) external view returns (uint256, uint256);

  function want() external view returns (address);

  function poolInfo(uint256)
    external
    view
    returns (
      address,
      uint256,
      uint256,
      uint256,
      address
    );
}

interface IAutoStrat {
  function wantLockedTotal() external view returns (uint256);

  function wantLockedInHere() external view returns (uint256);

  function autoFarmAddress() external view returns (address);

  function vTokenAddress() external view returns (address);
}

/**
 * @title Autofarm ERC4626 Contract
 * @notice ERC4626 wrapper for AutofarmV2
 * @author RedVeil
 *
 * Wraps https://github.com/autofarmnetwork/AutofarmV2_CrossChain/blob/master/AutoFarmV2.sol
 *
 */
contract AutofarmERC4626 is MidasERC4626 {
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  uint256 public poolId;
  IAutofarmV2 public autofarm;
  FlywheelCore public flywheel;

  /* ========== INITIALIZER ========== */

  /**
     @notice Initializes the Vault.
     @param asset The ERC20 compliant token the Vault should accept.
     @param _flywheel Flywheel to pull AUTO rewards
     @param _poolId The poolId in AutofarmV2
     @param _autoToken The AUTO token. Used to approve flywheel
     @param _autofarm The autofarm contract.
    */
  function initialize(
    ERC20Upgradeable asset,
    FlywheelCore _flywheel,
    uint256 _poolId,
    ERC20Upgradeable _autoToken,
    IAutofarmV2 _autofarm
  ) public initializer {
    __MidasER4626_init(asset);
    poolId = _poolId;
    autofarm = _autofarm;
    flywheel = _flywheel;

    performanceFee = 5e16;
    asset.approve(address(autofarm), type(uint256).max);
    _autoToken.approve(address(flywheel.flywheelRewards()), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return autofarm.stakedWantTokens(poolId, address(this));
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    autofarm.deposit(poolId, amount);
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    autofarm.withdraw(poolId, amount);
  }

  /* Comment out for now
   * Todo: needs test for verification
   */

  // function emergencyWithdrawAndPause() external override onlyOwner {
  //   autofarm.withdraw(poolId, autofarm.balanceOf(address(this)));
  //   _pause();
  // }

  // function unpause() external override onlyOwner {
  //   _unpause();
  //   autofarm.deposit(poolId, asset.balanceOf(address(this)));
  // }
}

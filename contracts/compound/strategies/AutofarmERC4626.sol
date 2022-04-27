// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";

import { ERC4626 } from "../../utils/ERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

interface IAutofarmV2 {
  function AUTO() external view returns (address);

  function deposit(uint256 _pid, uint256 _wantAmt) external;

  function withdraw(uint256 _pid, uint256 _wantAmt) external;

  //Returns underlying balance in strategies
  function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256);
}

/**
 * @title Autofarm ERC4626 Contract
 * @notice ERC4626 wrapper for AutofarmV2
 * @author RedVeil
 *
 * Wraps https://github.com/autofarmnetwork/AutofarmV2_CrossChain/blob/master/AutoFarmV2.sol
 *
 */
contract AutofarmERC4626 is ERC4626 {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  uint256 public immutable poolId;
  IAutofarmV2 public immutable autofarm;
  FlywheelCore public immutable flywheel;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _flywheel TODO
     @param _poolId TODO
     @param _autoToken The AUTO token. Used to approve flywheel
     @param _autofarm The autofarm contract.

    */
  constructor(
    ERC20 _asset,
    FlywheelCore _flywheel,
    uint256 _poolId,
    ERC20 _autoToken,
    IAutofarmV2 _autofarm
  )
    ERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol()))
    )
  {
    poolId = _poolId;
    autofarm = _autofarm;
    flywheel = _flywheel;

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
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    autofarm.deposit(poolId, amount);
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    autofarm.withdraw(poolId, amount);
  }
}

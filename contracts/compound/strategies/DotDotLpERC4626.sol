// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { MidasERC4626 } from "./MidasERC4626.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";
import { FlywheelCore } from "flywheel-v2/FlywheelCore.sol";

interface ILpDepositor {
  // user -> pool -> deposit amount
  function userBalances(address _user, address _token) external view returns (uint256);

  function deposit(
    address _user,
    address _token,
    uint256 _amount
  ) external;

  function withdraw(
    address _receiver,
    address _token,
    uint256 _amount
  ) external;

  function claim(
    address _receiver,
    address[] calldata _tokens,
    uint256 _maxBondAmount
  ) external;

  function depositTokens(address lpToken) external view returns (address);
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
contract DotDotLpERC4626 is MidasERC4626 {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */
  FlywheelCore public immutable dddFlywheel;
  FlywheelCore public immutable epxFlywheel;
  ILpDepositor public immutable lpDepositor;
  address[] public assetAsArray;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _dddFlywheel Flywheel to pull DDD rewards
     @param _epxFlywheel Flywheel to pull EPX rewards
     @param _lpDepositor DotDot deposit contract for LpToken
    */
  constructor(
    ERC20 _asset,
    FlywheelCore _dddFlywheel,
    FlywheelCore _epxFlywheel,
    ILpDepositor _lpDepositor
  )
    MidasERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol()))
    )
  {
    dddFlywheel = _dddFlywheel;
    epxFlywheel = _epxFlywheel;
    lpDepositor = _lpDepositor;

    // lpDepositor wants an address array for claiming
    assetAsArray.push(address(_asset));

    ERC20(dddFlywheel.rewardToken()).approve(address(dddFlywheel.flywheelRewards()), type(uint256).max);
    ERC20(epxFlywheel.rewardToken()).approve(address(epxFlywheel.flywheelRewards()), type(uint256).max);

    asset.approve(address(lpDepositor), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return lpDepositor.userBalances(address(this), address(asset));
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    lpDepositor.deposit(address(this), address(asset), amount);
    //lpDepositor.claim(address(this), assetAsArray, 0);
  }

  /// @notice withdraws specified amount of underlying token if possible
  function beforeWithdraw(uint256 amount, uint256) internal override {
    lpDepositor.withdraw(address(this), address(asset), amount);
    lpDepositor.claim(address(this), assetAsArray, 0);
  }

  /* ========== EMERGENCY FUNCTIONS ========== */

  function emergencyWithdrawAndPause() external override onlyOwner {
    lpDepositor.withdraw(
      address(this),
      address(asset),
      ERC20(lpDepositor.depositTokens(address(asset))).balanceOf(address(this))
    );
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    lpDepositor.deposit(address(this), address(asset), asset.balanceOf(address(this)));
  }
}

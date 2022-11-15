// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { RewardsClaimer } from "../RewardsClaimer.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface IWmxVault {
  function deposit(uint256 assets, address receiver) external returns (uint256);

  function withdraw(
    uint256 assets,
    address receiver,
    address owner
  ) external returns (uint256);

  function balanceOf(address account) external view returns (uint256);

  function allRewardTokens() external view returns (address[] memory);

  function totalAssets() external view returns (uint256);

  function getReward(address, bool) external returns (bool);
}

contract WombatLpERC4626 is MidasERC4626, RewardsClaimer {
  using FixedPointMathLib for uint256;

  IWmxVault public vault;
  uint256 public poolId;

  function initialize(
    ERC20Upgradeable asset,
    IWmxVault _vault,
    ERC20Upgradeable[] memory _rewardTokens,
    address _rewardsDestination
  ) public initializer {
    __MidasER4626_init(asset);
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);

    vault = _vault;
    asset.approve(address(vault), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return _asset().balanceOf(address(this));
    }

    uint256 amount = vault.balanceOf(address(this));
    return amount;
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 assets, uint256) internal override {
    vault.deposit(assets, address(this));
  }

  function beforeWithdraw(uint256 assets, uint256) internal override {
    vault.withdraw(assets, address(this), address(this));
  }

  function beforeClaim() internal override {
    vault.getReward(address(this), false);
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    uint256 amount = vault.balanceOf(address(this));
    vault.withdraw(amount, address(this), address(this));
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    vault.deposit(_asset().balanceOf(address(this)), address(this));
  }
}

// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import "./MidasERC4626.sol";
import { RewardsClaimer } from "../RewardsClaimer.sol";

import { ERC20Upgradeable as ERC20 } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { MidasFlywheel } from "./flywheel/MidasFlywheel.sol";

interface GaugeV2 {
  function getReward() external;

  function deposit(uint256) external;

  function withdraw(uint256) external;

  function depositAll() external;

  function withdrawAll() external;

  function earned(address) external view returns (uint256);

  function balanceOf(address) external view returns (uint256);

  function rewardToken() external view returns (ERC20);

  function TOKEN() external view returns (address);
}

interface VoterV3 {
  function gauges(ERC20) external view returns (GaugeV2);
}

contract ThenaLpERC4626 is MidasERC4626, RewardsClaimer {
  MidasFlywheel public flywheel;
  GaugeV2 public gauge;

  VoterV3 public constant GAUGES_FACTORY = VoterV3(0x3A1D0952809F4948d15EBCe8d345962A282C4fCb);

  constructor() {
    _disableInitializers();
  }

  function initialize(
    ERC20 _asset,
    address _rewardsDestination,
    MidasFlywheel _flywheel
  ) public initializer {
    __MidasER4626_init(_asset);

    ERC20[] memory _rewardTokens = new ERC20[](1);
    ERC20 _rewardToken = gauge.rewardToken();
    _rewardTokens[0] = _rewardToken;
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);

    gauge = GAUGES_FACTORY.gauges(_asset);
    flywheel = _flywheel;

    _asset.approve(address(gauge), type(uint256).max);
    _rewardToken.approve(address(flywheel.flywheelRewards()), type(uint256).max);
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    gauge.deposit(amount);
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    gauge.withdraw(amount);
  }

  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return _asset().balanceOf(address(this));
    }

    return gauge.balanceOf(address(this)) + gauge.earned(address(this));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function beforeClaim() internal override {
    gauge.getReward();
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    gauge.withdrawAll();
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    gauge.depositAll();
  }
}

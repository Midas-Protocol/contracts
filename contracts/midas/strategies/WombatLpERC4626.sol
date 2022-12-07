// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { RewardsClaimer } from "../RewardsClaimer.sol";

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
}

interface IBooster {
  function deposit(
    uint256 _pid,
    uint256 _amount,
    bool _stake
  ) external;

  function poolInfo(uint256 _pid)
    external
    view
    returns (
      address lptoken,
      address token,
      address gauge,
      address crvRewards,
      bool shutdown
    );
}

interface IVoterProxy {
  function operator() external view returns (address);
}

interface IBaseRewardPool {
  function balanceOf(address) external view returns (uint256);

  function withdrawAndUnwrap(uint256 amount, bool claim) external returns (bool);

  function getReward(address, bool) external returns (bool);

  function totalSupply() external view returns (uint256);

  function earned(address, address) external view returns (uint256);

  function userRewardPerTokenPaid(address, address) external view returns (uint256);

  function queueNewRewards(address, uint256) external;
}

contract WombatLpERC4626 is MidasERC4626, RewardsClaimer {
  IVoterProxy public voterProxy;
  uint256 public poolId;

  function initialize(
    ERC20Upgradeable asset,
    IVoterProxy _voterProxy,
    uint256 _poolId,
    ERC20Upgradeable[] memory _rewardTokens,
    address _rewardsDestination
  ) public initializer {
    __MidasER4626_init(asset);
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);

    voterProxy = _voterProxy;
    poolId = _poolId;
    asset.approve(address(_booster()), type(uint256).max);
  }

  function _booster() internal view returns (IBooster) {
    address booster = voterProxy.operator();
    return IBooster(booster);
  }

  function _baseRewardPool() internal view returns (IBaseRewardPool) {
    (, , , address crvRewards, ) = _booster().poolInfo(poolId);
    return IBaseRewardPool(crvRewards);
  }

  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return _asset().balanceOf(address(this));
    }

    uint256 amount = _baseRewardPool().balanceOf(address(this));
    return amount;
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 assets, uint256) internal override {
    _booster().deposit(poolId, assets, true);
  }

  function beforeWithdraw(uint256 assets, uint256) internal override {
    _baseRewardPool().withdrawAndUnwrap(assets, false);
  }

  function beforeClaim() internal override {
    _baseRewardPool().getReward(address(this), false);
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    uint256 amount = _baseRewardPool().balanceOf(address(this));
    _baseRewardPool().withdrawAndUnwrap(amount, false);
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    _booster().deposit(poolId, _asset().balanceOf(address(this)), true);
  }
}

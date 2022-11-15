// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";
import { RewardsClaimer } from "../RewardsClaimer.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

interface IJAR {
  function join(uint256 wad) external;

  function exit(uint256 wad) external;

  function balanceOf(address) external view returns (uint256);
}

contract HelioERC4626 is MidasERC4626, RewardsClaimer {
  using FixedPointMathLib for uint256;

  IJAR public jar;

  function initialize(
    ERC20Upgradeable asset,
    IJAR _jar,
    address _rewardsDestination,
    ERC20Upgradeable[] memory _rewardTokens
  ) public initializer {
    __MidasER4626_init(asset);
    __RewardsClaimer_init(_rewardsDestination, _rewardTokens);
    jar = _jar;

    asset.approve(address(jar), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {
    if (paused()) {
      return _asset().balanceOf(address(this));
    }

    return jar.balanceOf(address(this));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    jar.join(amount);
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    jar.exit(amount);
  }

  function beforeClaim() internal override {
    jar.exit(0);
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    uint256 amount = jar.balanceOf(address(this));
    jar.exit(amount);
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
    jar.join(_asset().balanceOf(address(this)));
  }
}
// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { MidasERC4626 } from "./MidasERC4626.sol";

interface IJAR {
  function join(uint256 wad) external {};

  function exit(uint256 wad) external {};
}

contract HelioERC4626 is MidasERC4626 {
  using FixedPointMathLib for uint256;

  IJAR public jar;

  function initialize(
    ERC20Upgradeable asset,
    IJAR _jar,
  ) public initializer {
    __MidasERC4626_init(asset);
    jar = _jar;

    asset.approve(address(jar), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {

  }

  function balanceOfUnderlying(address account) public view returns (uint256) {

  }

  function afterDeposit(uint256 amount, uint256) internal override {
    jar.join(amount);
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    jar.exit(amount);
  }

  function emergencyWithdrawAndPause() external override onlyOwner {
    _pause();
  }

  function unpause() external override onlyOwner {
    _unpause();
  }
}
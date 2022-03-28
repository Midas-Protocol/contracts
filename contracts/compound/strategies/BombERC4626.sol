// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../../utils/ERC4626.sol";
import "../../external/bomb/IXBomb.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract BombERC4626 is ERC4626 {
  IXBomb public xbomb;

  constructor(IXBomb _xbomb, ERC20 asset) ERC4626(asset, asset.name(), asset.symbol()) {
    xbomb = _xbomb;
    asset.approve(address(xbomb), type(uint256).max);
  }

  function totalAssets() public view override returns (uint256) {
    return xbomb.toREWARD(xbomb.balanceOf(address(this)));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  function afterDeposit(uint256 bombAssets, uint256 xbombShares) internal override {
    xbomb.enter(bombAssets);
  }

  function beforeWithdraw(uint256 bombAssets, uint256 xbombShares) internal override {
    xbomb.leave(xbombShares);
  }

  function previewDeposit(uint256 bombAssets) public view override returns (uint256) {
    return xbomb.toSTAKED(bombAssets);
  }
}

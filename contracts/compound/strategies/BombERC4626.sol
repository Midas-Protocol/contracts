// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../../utils/ERC4626.sol";
import "../../external/bomb/IXBomb.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract BombERC4626 is ERC4626 {
  IXBomb xbomb;

  constructor(IXBomb _xbomb, ERC20 asset) ERC4626(asset, asset.name(), asset.symbol()) {
    xbomb = _xbomb;
  }

  function totalAssets() public view override returns (uint256) {
    return xbomb.toREWARD(xbomb.balanceOf(address(this)));
  }

  function balanceOfUnderlying(address account) public view returns (uint256) {
    return xbomb.toREWARD(xbomb.balanceOf(account));
  }

  function afterDeposit(uint256 amount, uint256) internal override {
    xbomb.enter(amount);
  }

  function beforeWithdraw(uint256 amount, uint256) internal override {
    xbomb.leave(amount);
  }
}

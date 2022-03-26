// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../../utils/ERC4626.sol";
import "../../external/bomb/IXBomb.sol";
import { ERC20 } from "@rari-capital/solmate/src/tokens/ERC20.sol";

contract BombERC4626 is ERC4626 {
  IXBomb xbomb = IXBomb(0xAf16cB45B8149DA403AF41C63AbFEBFbcd16264b);

  constructor(
    ERC20 bomb
  ) ERC4626(bomb, bomb.name(), bomb.symbol()) {}

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

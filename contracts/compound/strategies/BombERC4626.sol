// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import { MidasERC4626 } from "./MidasERC4626.sol";
import "../../external/bomb/IXBomb.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

/**
 * @title Bomb ERC4626 Contract
 * @notice ERC4626 strategy for BOMB staking
 * @author vminkov
 *
 * Stakes the deposited BOMB in the xBOMB token contract which mints xBOMB for the depositor
 * and that xBOMB can be redeemed for a better xBOMB/BOMB rate when BOMB rewards are accumulated
 */
contract BombERC4626 is MidasERC4626 {
  // the staking token through which the rewards are distributed and redeemed
  IXBomb public xbomb;

  /* ========== CONSTRUCTOR ========== */

  /**
   * @notice Creates a new Vault that accepts a specific underlying token.
   * @param asset The BOMB ERC20-compliant token the Vault should accept.
   * @param _xbombAddress the xBOMB contract address
   */
  function initialize(ERC20Upgradeable asset, address _xbombAddress) public initializer {
    __MidasER4626_init(asset);

    xbomb = IXBomb(_xbombAddress);
    asset.approve(address(xbomb), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return xbomb.toREWARD(xbomb.balanceOf(address(this)));
  }

  /// @notice Calculates the total amount of underlying tokens the user holds.
  /// @return The total amount of underlying tokens the user holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf(account));
  }

  /// @notice Calculates the number of xBOMB shares that will be minted for the specified BOMB deposit.
  /// @return The number of xBOMB shares that will be minted for the specified BOMB deposit.
  function previewDeposit(uint256 bombAssets) public view override returns (uint256) {
    return xbomb.toSTAKED(bombAssets);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  /// @notice stakes the specified amount of BOMB in the xBOMB contract
  function afterDeposit(uint256 bombAssets, uint256) internal override {
    xbomb.enter(bombAssets);
  }

  /// @notice unstakes the specified amount of xBOMB shares from the xBOMB contract
  function beforeWithdraw(uint256, uint256 xbombShares) internal override {
    xbomb.leave(xbombShares);
  }

  // function emergencyWithdrawAndPause() external override onlyOwner {
  //   xbomb.leave(xbomb.balanceOf(address(this)));
  //   _pause();
  // }

  // function unpause() external override onlyOwner {
  //   _unpause();
  //   xbomb.enter(asset.balanceOf(address(this)));
  // }
}

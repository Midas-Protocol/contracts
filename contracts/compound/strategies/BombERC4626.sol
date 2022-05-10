// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "../../utils/ERC4626.sol";
import "../../external/bomb/IXBomb.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

/**
 * @title Bomb ERC4626 Contract
 * @notice ERC4626 strategy for BOMB staking
 * @author vminkov
 *
 * Stakes the deposited BOMB in the xBOMB token contract which mints xBOMB for the depositor
 * and that xBOMB can be redeemed for a better xBOMB/BOMB rate when BOMB rewards are accumulated
 */
contract BombERC4626 is ERC4626 {
  // the staking token through which the rewards are distributed and redeemed
  IXBomb public xbomb;

  /* ========== CONSTRUCTOR ========== */

  /**
   * @notice Creates a new Vault that accepts a specific underlying token.
   * @param _asset The BOMB ERC20-compliant token the Vault should accept.
   * @param _xbombAddress the xBOMB contract address
   */
  constructor(ERC20 _asset, address _xbombAddress)
    ERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol()))
    )
  {
    xbomb = IXBomb(_xbombAddress);
    _asset.approve(address(xbomb), type(uint256).max);
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
    return convertToAssets(balanceOf[account]);
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
}

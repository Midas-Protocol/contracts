// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ERC4626 } from "../../utils/ERC4626.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "../../utils/FixedPointMathLib.sol";

interface IBeefyVault {
  function deposit(uint256 _amount) external;

  function withdraw(uint256 _shares) external;

  function balanceOf(address _account) external view returns (uint256);

  //Returns total balance of underlying token in the vault and its strategies
  function balance() external view returns (uint256);

  function totalSupply() external view returns (uint256);
}

/**
 * @title Beefy ERC4626 Contract
 * @notice ERC4626 wrapper for beefy vaults
 * @author RedVeil
 *
 * Wraps https://github.com/beefyfinance/beefy-contracts/blob/master/contracts/BIFI/vaults/BeefyVaultV6.sol
 */
contract BeefyERC4626 is ERC4626 {
  using SafeTransferLib for ERC20;
  using FixedPointMathLib for uint256;

  /* ========== STATE VARIABLES ========== */

  IBeefyVault public immutable beefyVault;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _beefyVault The Beefy Vault contract.
    */
  constructor(ERC20 _asset, IBeefyVault _beefyVault)
    ERC4626(
      _asset,
      string(abi.encodePacked("Midas ", _asset.name(), " Vault")),
      string(abi.encodePacked("mv", _asset.symbol()))
    )
  {
    beefyVault = _beefyVault;

    asset.approve(address(beefyVault), type(uint256).max);
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return beefyVault.balanceOf(address(this)).mulDivDown(beefyVault.balance(), beefyVault.totalSupply());
  }

  /// @notice Calculates the total amount of underlying tokens the account holds.
  /// @return The total amount of underlying tokens the account holds.
  function balanceOfUnderlying(address account) public view returns (uint256) {
    return convertToAssets(balanceOf[account]);
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256) internal override {
    beefyVault.deposit(amount);
  }

  function beforeWithdraw(uint256, uint256 shares) internal override {
    beefyVault.withdraw(shares);
  }

  function previewWithdraw(uint256 assets) public view override returns (uint256) {
    uint256 supply = totalSupply;

    // shares in the vault ? sharesInThis4626
    //             shares = (_amount.mul(totalSupply())).div(balance());
    // sharesInTheVaultToRedeem = assets * beefyVaultTotalShares / beefyVaultTotalAssets
    // TODO muldivdown
    //    return supply == 0 ? assets : assets.mulDivDown(beefyVault.totalSupply(), beefyVault.balance());

    // underlyingToWithdraw * this4626TotalSupply / ourAssetsInTheBeefyVault
    //    return supply == 0 ? assets : assets.mulDivUp(supply, totalAssets());


    return supply == 0 ? assets : assets * beefyVault.totalSupply() / beefyVault.balance();
  }

  function previewRedeem(uint256 shares) public view override returns (uint256) {
    uint256 supply = totalSupply;

    // ourShares * ourAssetsInTheBeefyVault / ourTotalSupply

    return supply == 0 ? shares : shares * beefyVault.balance() / beefyVault.totalSupply();
    // return supply;
  }
}

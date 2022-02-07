// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20, ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

interface IBeefyVault {
  function deposit(uint _amount) external;
  function withdraw(uint256 _shares) external;
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

  /* ========== STATE VARIABLES ========== */

  IBeefyVault public immutable beefyVault;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _name The name for the vault token.
     @param _symbol The symbol for the vault token.
     @param _beefyVault The Beefy Vault contract.
    */
  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol,
    IBeefyVault _beefyVault,
  ) ERC4626(_asset, _name, _symbol){
    beefyVault = _beefyVault;
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return beefyVault.balanceOf(address(this));
  }

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function balanceOfUnderlying(address _) public view override returns (uint256) {
    return beefyVault.balanceOf(address(this));
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256 shares) internal override {
    asset.approve(address(beefyVault), amount);
    beefyVault.deposit(amount);
  }

  function beforeWithdraw(uint256 amount, uint256 shares) internal override {
    beefyVault.withdraw(shares);
  }
}

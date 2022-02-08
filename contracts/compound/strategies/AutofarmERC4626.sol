// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "@rari-capital/solmate/src/tokens/ERC20.sol";
import {ERC4626} from "../../utils/ERC4626.sol";
import {SafeTransferLib} from "@rari-capital/solmate/src/utils/SafeTransferLib.sol";

interface IAutofarmStratX2 {
  function deposit(address _userAddress, uint256 _wantAmt) external returns (uint256);

  function withdraw(address _userAddress, uint256 _wantAmt) external returns (uint256);

  function balanceOf(address _account) external view returns (uint256);
}

/**
 * @title Autofarm ERC4626 Contract
 * @notice ERC4626 wrapper for Autofarm StratX2
 * @author RedVeil
 *
 * Wraps https://github.com/autofarmnetwork/AutofarmV2_CrossChain/blob/master/StratX2.sol
 */
contract AutofarmERC4626 is ERC4626 {
  using SafeTransferLib for ERC20;

  /* ========== STATE VARIABLES ========== */

  IAutofarmStratX2 public immutable autofarmStrat;

  /* ========== CONSTRUCTOR ========== */

  /**
     @notice Creates a new Vault that accepts a specific underlying token.
     @param _asset The ERC20 compliant token the Vault should accept.
     @param _name The name for the vault token.
     @param _symbol The symbol for the vault token.
     @param _autofarmStrat The Beefy Vault contract.
    */
  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol,
    IAutofarmStratX2 _autofarmStrat
  ) ERC4626(_asset, _name, _symbol) {
    autofarmStrat = _autofarmStrat;
  }

  /* ========== VIEWS ========== */

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function totalAssets() public view override returns (uint256) {
    return autofarmStrat.wantLockedTotal();
  }

  /// @notice Calculates the total amount of underlying tokens the Vault holds.
  /// @return The total amount of underlying tokens the Vault holds.
  function balanceOfUnderlying(address _x) public view returns (uint256) {
    _x;
    return autofarmStrat.wantLockedTotal();
  }

  /* ========== INTERNAL FUNCTIONS ========== */

  function afterDeposit(uint256 amount, uint256 shares) internal override {
    asset.approve(address(autofarmStrat), amount);
    autofarmStrat.deposit(address(this), amount);
  }

  function beforeWithdraw(uint256 amount, uint256 shares) internal override {
    autofarmStrat.withdraw(address(this), shares);
  }
}

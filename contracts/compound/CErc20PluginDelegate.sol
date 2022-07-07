// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CErc20Delegate.sol";
import "./EIP20Interface.sol";
import "./IERC4626.sol";
import "../external/uniswap/IUniswapV2Pair.sol";

/**
 * @title Rari's CErc20Plugin's Contract
 * @notice CToken which outsources token logic to a plugin
 * @author Joey Santoro
 *
 * CErc20PluginDelegate deposits and withdraws from a plugin conract
 * It is also capable of delegating reward functionality to a PluginRewardsDistributor
 */
contract CErc20PluginDelegate is CErc20Delegate {
  /**
   * @notice Plugin address
   */
  IERC4626 public plugin;

  uint256 public constant PRECISION = 1e18;

  /**
   * @notice Delegate interface to become the implementation
   * @param data The encoded arguments for becoming
   */
  function _becomeImplementation(bytes calldata data) external virtual override {
    require(msg.sender == address(this) || hasAdminRights(), "needs admin rights");

    address _plugin = abi.decode(data, (address));
    require(_plugin != address(0), "0");

    require(
      IFuseFeeDistributor(fuseAdmin).pluginImplementationWhitelist(address(this), _plugin),
      "new plugin needs to be whitelisted"
    );

    if (address(plugin) != address(0) && plugin.balanceOf(address(this)) != 0) {
      plugin.redeem(plugin.balanceOf(address(this)), address(this), address(this));
    }

    plugin = IERC4626(_plugin);

    EIP20Interface(underlying).approve(_plugin, type(uint256).max);

    uint256 amount = EIP20Interface(underlying).balanceOf(address(this));
    if (amount != 0) {
      deposit(amount);
    }
  }

  /*** CToken Overrides ***/

  /*** Safe Token ***/

  /**
   * @notice Gets balance of the plugin in terms of the underlying
   * @return The quantity of underlying tokens owned by this contract
   */
  function getCashPrior() internal view override returns (uint256) {
    return plugin.previewRedeem(plugin.balanceOf(address(this)));
  }

  /**
   * @notice Transfer the underlying to the cToken and trigger a deposit
   * @param from Address to transfer funds from
   * @param amount Amount of underlying to transfer
   * @return The actual amount that is transferred
   */
  function doTransferIn(address from, uint256 amount) internal override returns (uint256) {
    // Perform the EIP-20 transfer in
    require(EIP20Interface(underlying).transferFrom(from, address(this), amount), "send");

    deposit(amount);
    return amount;
  }

  function deposit(uint256 amount) internal {
    plugin.deposit(amount, address(this));
  }

  /**
   * @notice Transfer the underlying from plugin to destination
   * @param to Address to transfer funds to
   * @param amount Amount of underlying to transfer
   */
  function doTransferOut(address to, uint256 amount) internal override {
    plugin.withdraw(amount, to, address(this));
  }
}

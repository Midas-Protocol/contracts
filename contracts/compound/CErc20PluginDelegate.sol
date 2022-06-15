// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CErc20Delegate.sol";
import "./EIP20Interface.sol";
import "./IERC4626.sol";

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
    require(msg.sender == address(this) || hasAdminRights());

    address _plugin = abi.decode(data, (address));

    require(_plugin != address(0), "0");

    if (address(plugin) == 0x0b96dccbAA03447Fd5f5Fd733e0ebD10680E84c1 && totalSupply > 0) {
      // the two larges holders
      _burnAll(0x0D8e060CA2D847553ec14394ee6B304623E0d1d6);
      _burnAll(0x49707808908f0C2450B3F2672E012eDBf49eD808);

      // burn dust leftover
      _burnAll(0x55452c8Ffa2434bf5E738D752C5581B409E6633D);
      _burnAll(0xa13c2DEF62c36697407fBe7d574e946bf60d7350);
      _burnAll(0xc43e5C94f0fCf442Db226aB78F4985607d366052);
      _burnAll(0x75C1D99B8C39Dd31b6815A6269Dc7B16D43a11c1);
      _burnAll(0x489CAF6518c28804E31CaE58a1429341D739b73f);

      totalSupply = 0;
    }

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

  function _burnAll(address from) private {
    emit Transfer(from, address(0), accountTokens[from]);
    accountTokens[from] = 0;
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

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CErc20PluginDelegate.sol";

contract CErc20PluginRewardsDelegate is CErc20PluginDelegate {
  /// @notice A reward token claim function
  /// to be overriden for use cases where rewardToken needs to be pulled in
  function claim() external {}

  function _becomeImplementation(bytes calldata data) external virtual override {
    require(msg.sender == address(this) || hasAdminRights());

    address _plugin = abi.decode(data, (address));

    require(_plugin != address(0), "0");

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

  /// @notice token approval function
  function approve(address _token, address _spender) external {
    require(hasAdminRights(), "!admin");
    require(_token != underlying && _token != address(plugin), "!");

    EIP20Interface(_token).approve(_spender, type(uint256).max);
  }
}

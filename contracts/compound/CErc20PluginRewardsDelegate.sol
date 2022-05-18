// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CErc20PluginDelegate.sol";

contract CErc20PluginRewardsDelegate is CErc20PluginDelegate {
    /**
     * @notice Delegate interface to become the implementation
     * @param data The encoded arguments for becoming
     */
    function _becomeImplementation(bytes calldata data) external override {
        require(msg.sender == address(this) || hasAdminRights());

        address _plugin = abi.decode(data, (address));

        plugin = IERC4626(_plugin);
        EIP20Interface(underlying).approve(_plugin, type(uint256).max);
    }

    /// @notice A reward token claim function
    /// to be overriden for use cases where rewardToken needs to be pulled in
    function claim() external {}

    /// @notice token approval function
    function approve(address _token, address _spender) external {
        require(hasAdminRights(), "!admin");
        require(_token != underlying && _token != address(plugin), "!");

        EIP20Interface(_token).approve(_spender, type(uint256).max);
    }
}

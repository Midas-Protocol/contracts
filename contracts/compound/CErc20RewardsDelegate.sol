// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CErc20Delegate.sol";
import "./EIP20Interface.sol";

contract CErc20RewardsDelegate is CErc20Delegate {
  /// @notice A reward token claim function
  /// to be overriden for use cases where rewardToken needs to be pulled in
  function claim() external {}

  /// @notice token approval function
  function approve(address _token, address _spender) external {
    require(hasAdminRights(), "!admin");
    require(_token != underlying, "!underlying");

    EIP20Interface(_token).approve(_spender, type(uint256).max);
  }

  function contractType() external view override returns (string memory) {
    return "CErc20RewardsDelegate";
  }
}

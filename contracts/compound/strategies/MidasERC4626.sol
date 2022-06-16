// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity >=0.8.0;

import "solmate/mixins/ERC4626.sol";
import "solmate/tokens/ERC20.sol";
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import { Pausable } from "@openzeppelin/contracts/security/Pausable.sol";

abstract contract MidasERC4626 is ERC4626, Ownable, Pausable {
  constructor(
    ERC20 _asset,
    string memory _name,
    string memory _symbol
  ) ERC4626(_asset, _name, _symbol) {}

  // Should withdraw all funds from the strategy and pause the contract
  function emergencyWithdrawFromStrategy() external onlyOwner {}

  function unpause() external onlyOwner {
    _unpause();
  }

  function emergencyWithdrawal(uint256 shares) external {
    _burn(owner, shares);

    uint256 supply = totalSupply; // Saves an extra SLOAD if totalSupply is non-zero.

    asset.safeTransfer(supply == 0 ? shares : shares.mulDivUp(asset.balanceOf(address(this)), supply));
  }
}

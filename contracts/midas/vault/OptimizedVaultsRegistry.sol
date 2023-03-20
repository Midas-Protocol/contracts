pragma solidity ^0.8.0;

import "../SafeOwnableUpgradeable.sol";
import "./MultiStrategyVault.sol";

contract OptimizedVaultsRegistry is SafeOwnableUpgradeable {
  MultiStrategyVault[] public vaults;

  function initialize() public initializer {
    __SafeOwnable_init(msg.sender);
  }

  function getAllVaults() public view returns (MultiStrategyVault[] memory) {
    return vaults;
  }

  function addVault(address vault) public onlyOwner returns (bool) {
    for (uint256 i; i < vaults.length; i++) {
      if (address(vaults[i]) == vault) {
        return false;
      }
    }
    vaults.push(MultiStrategyVault(vault));
    return true;
  }

  function removeVault(address vault) public onlyOwner returns (bool) {
    for (uint256 i; i < vaults.length; i++) {
      if (address(vaults[i]) == vault) {
        vaults[i] = vaults[vaults.length - 1];
        delete vaults[vaults.length - 1];
        return true;
      }
    }
    return false;
  }
}

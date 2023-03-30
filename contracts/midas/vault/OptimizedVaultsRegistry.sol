pragma solidity ^0.8.0;

import "../SafeOwnableUpgradeable.sol";
import "./OptimizedAPRVault.sol";
import "../strategies/CompoundMarketERC4626.sol";

contract OptimizedVaultsRegistry is SafeOwnableUpgradeable {
  OptimizedAPRVault[] public vaults;

  function initialize() public initializer {
    __SafeOwnable_init(msg.sender);
  }

  function getAllVaults() public view returns (OptimizedAPRVault[] memory) {
    return vaults;
  }

  function addVault(address vault) public onlyOwner returns (bool) {
    for (uint256 i; i < vaults.length; i++) {
      if (address(vaults[i]) == vault) {
        return false;
      }
    }
    vaults.push(OptimizedAPRVault(vault));
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

  function setEmergencyExit() external onlyOwner {
    for (uint256 i; i < vaults.length; ++i) {
      uint8 adapterCount = vaults[i].adapterCount();
      for (uint256 j; j < adapterCount; ++j) {
        (CompoundMarketERC4626 adapter, ) = vaults[i].adapters(j);
        try adapter.emergencyWithdrawAndPause() {} catch {}
      }
      vaults[i].setEmergencyExit();
    }
  }

  // TODO lens function to list all flywheels for which a user can accrue and claim rewards
}

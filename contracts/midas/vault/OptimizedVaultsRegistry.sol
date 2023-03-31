pragma solidity ^0.8.0;

import "../SafeOwnableUpgradeable.sol";
import "./OptimizedAPRVault.sol";
import "../strategies/CompoundMarketERC4626.sol";
import "../strategies/flywheel/MidasFlywheel.sol";

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

  // @notice lens function to list all flywheels for which the account can claim rewards
  function getClaimableRewards(address account)
    external
    returns (address[] memory flywheels_, uint256[] memory rewards_)
  {
    uint256 totalFlywheels = 0;
    for (uint256 i = 0; i < vaults.length; i++) {
      MidasFlywheel[] memory flywheels = vaults[i].getAllFlywheels();
      totalFlywheels += flywheels.length;
    }

    flywheels_ = new address[](totalFlywheels);
    rewards_ = new uint256[](totalFlywheels);

    for (uint256 i = 0; i < vaults.length; i++) {
      OptimizedAPRVault vault = vaults[i];
      MidasFlywheel[] memory flywheels = vault.getAllFlywheels();
      uint256 flywheelsLen = flywheels.length;

      for (uint256 j = 0; j < flywheelsLen; j++) {
        MidasFlywheel flywheel = flywheels[j];
        flywheels_[i * flywheelsLen + j] = address(flywheel);
        rewards_[i * flywheelsLen + j] = flywheel.accrue(ERC20(address(vault)), account);
      }
    }
  }
}

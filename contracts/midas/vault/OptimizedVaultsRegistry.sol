pragma solidity ^0.8.0;

import "../SafeOwnableUpgradeable.sol";
import "./OptimizedAPRVault.sol";
import "../strategies/CompoundMarketERC4626.sol";
import "../strategies/flywheel/MidasFlywheel.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

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
      uint8 adaptersCount = vaults[i].adaptersCount();
      for (uint256 j; j < adaptersCount; ++j) {
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

  struct AdapterInfo {
    address adapter;
    address market;
    address pool;
  }

  struct VaultInfo {
    address asset;
    string assetSymbol;
    uint8 assetDecimals;
    uint256 estimatedTotalAssets;
    uint256 apr;
    uint256 adaptersCount;
    bool isEmergencyStopped;
    uint64 performanceFee;
    uint64 depositFee;
    uint64 withdrawalFee;
    uint64 managementFee;
    AdapterInfo[] adaptersData;
  }

  function getVaultsData() public view returns (VaultInfo[] memory vaultsData) {
    vaultsData = new VaultInfo[](vaults.length);
    for (uint256 i; i < vaults.length; ++i) {
      OptimizedAPRVault vault = vaults[i];
      uint8 adaptersCount = vaults[i].adaptersCount();
      AdapterInfo[] memory adaptersData = new AdapterInfo[](adaptersCount);

      for (uint256 j; j < adaptersCount; ++j) {
        (CompoundMarketERC4626 adapter, ) = vaults[i].adapters(j);
        ICErc20 market = adapter.market();
        adaptersData[j].adapter = address(adapter);
        adaptersData[j].market = address(market);
        adaptersData[j].pool = market.comptroller();
      }

      (uint64 performanceFee, uint64 depositFee, uint64 withdrawalFee, uint64 managementFee) = vault.fees();

      vaultsData[i] = VaultInfo({
        asset: vault.asset(),
        assetSymbol: IERC20Metadata(vault.asset()).symbol(),
        assetDecimals: IERC20Metadata(vault.asset()).decimals(),
        estimatedTotalAssets: vault.estimatedTotalAssets(),
        apr: vault.estimatedAPR(),
        adaptersCount: adaptersCount,
        isEmergencyStopped: vault.emergencyExit(),
        performanceFee: performanceFee,
        depositFee: depositFee,
        withdrawalFee: withdrawalFee,
        managementFee: managementFee,
        adaptersData: adaptersData
      });
    }
  }
}

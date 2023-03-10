// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../SafeOwnableUpgradeable.sol";
import "../strategies/OptimizedERC4626.sol";

import { IERC4626Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/interfaces/IERC4626Upgradeable.sol";
import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract MultiAssetOptimizer is SafeOwnableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  IERC20Upgradeable[] public assets;
  mapping(IERC20Upgradeable => IERC4626Upgradeable) vaultForAsset;
  mapping(IERC4626Upgradeable => bool) isVaultActive;

  address public defaultProxyAdmin;

  constructor() {
    _disableInitializers();
  }

  function initialize(address _defaultProxyAdmin) public initializer {
    __SafeOwnable_init();
    defaultProxyAdmin = _defaultProxyAdmin;
  }

  function addVaultForAsset(IERC20Upgradeable asset, bool active) public onlyOwner {
    IERC4626Upgradeable vault = vaultForAsset[asset];
    require(address(vault) == address(0), "already added");

    // instantiate the vault as an upgradable contract
    OptimizedERC4626 vaultImpl = new OptimizedERC4626();
    TransparentUpgradeableProxy vaultProxy = new TransparentUpgradeableProxy(
      address(vaultImpl),
      defaultProxyAdmin,
      abi.encode(asset)
    );
    vault = OptimizedERC4626(address(vaultProxy));

    // add the vault to the state
    vaultForAsset[asset] = vault;
    assets.push(asset);
    isVaultActive[vault] = active;
  }

  function getAllAssets() public view returns (IERC20Upgradeable[] memory) {
    return assets;
  }

  function deposit(uint256 amount) public {
    IERC4626Upgradeable vault = IERC4626Upgradeable(msg.sender);
    require(!isVaultActive[vault], "!invalid caller");

    IERC20Upgradeable asset = IERC20Upgradeable(vault.asset());
    asset.safeTransferFrom(address(vault), address(this), amount);

    // TODO if rebalancing is needed, withdraw this asset holdings and redeposit them
  }

  function withdraw(uint256 amount) public {
    IERC4626Upgradeable vault = IERC4626Upgradeable(msg.sender);
    require(!isVaultActive[vault], "!invalid caller");

    IERC20Upgradeable asset = IERC20Upgradeable(vault.asset());
    asset.safeTransfer(address(vault), amount);
  }

  /*

  function proposeAdapters(AdapterConfig[10] calldata newAdapters, uint8 newAdapterCount) external onlyOwner {
    _verifyAdapterConfig(newAdapters, newAdapterCount);

    for (uint8 i; i < newAdapterCount; i++) {
      proposedAdapters[i] = newAdapters[i];
    }

    proposedAdapterCount = newAdapterCount;

    proposedAdapterTime = block.timestamp;

    emit NewAdaptersProposed(newAdapters, proposedAdapterCount, block.timestamp);
  }

  function _verifyAdapterConfig(AdapterConfig[10] calldata newAdapters, uint8 adapterCount_) internal {
    if (adapterCount_ == 0 || adapterCount_ > 10) revert InvalidConfig();

    uint256 totalAllocation;
    for (uint8 i; i < adapterCount_; i++) {
      if (newAdapters[i].adapter.asset() != asset()) revert AssetInvalid();

      uint256 allocation = uint256(newAdapters[i].allocation);
      if (allocation == 0) revert InvalidConfig();

      totalAllocation += allocation;
    }
    if (totalAllocation != 1e18) revert InvalidConfig();
  }

  function changeAdapters() external takeFees {
  ....
   }
*/
}

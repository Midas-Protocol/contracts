// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PoolRolesAuthority } from "../midas/PoolRolesAuthority.sol";
import { SafeOwnableUpgradeable } from "../midas/SafeOwnableUpgradeable.sol";
import { IComptroller } from "../compound/ComptrollerInterface.sol";

import { TransparentUpgradeableProxy } from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

contract AuthoritiesRegistry is SafeOwnableUpgradeable {
  mapping(address => PoolRolesAuthority) public poolsAuthorities;
  PoolRolesAuthority public poolAuthLogic;

  function initialize() public initializer {
    __SafeOwnable_init(msg.sender);
    poolAuthLogic = new PoolRolesAuthority();
  }

  function reinitialize() public {
    poolAuthLogic = new PoolRolesAuthority();
  }

  function createPoolAuthority(address pool) public onlyOwner returns (PoolRolesAuthority auth) {
    require(address(poolsAuthorities[pool]) == address(0), "already created");

    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(poolAuthLogic), _getProxyAdmin(), "");
    auth = PoolRolesAuthority(address(proxy));
    auth.initialize(address(this));

    poolsAuthorities[pool] = auth;

    reconfigureAuthority(pool);
    auth.setUserRole(address(this), auth.REGISTRY_ROLE(), true);

    auth.setOwner(msg.sender);
  }

  function reconfigureAuthority(address poolAddress) public {
    IComptroller pool = IComptroller(poolAddress);
    PoolRolesAuthority auth = poolsAuthorities[address(pool)];

    require(address(auth) != address(0), "no such authority");
    require(msg.sender == owner() || msg.sender == poolAddress, "not owner or pool");

    auth.configureRegistryCapabilities();
    auth.configurePoolSupplierCapabilities(pool);
    auth.configurePoolBorrowerCapabilities(pool);
    auth.configureOpenPoolLiquidatorCapabilities(pool);
    auth.configureLeveredPositionCapabilities(pool);
  }

  function canCall(
    address pool,
    address user,
    address target,
    bytes4 functionSig
  ) external view returns (bool) {
    PoolRolesAuthority authorityForPool = poolsAuthorities[pool];
    if (address(authorityForPool) == address(0)) {
      // allow everyone to be a supplier by default
      return poolAuthLogic.isSupplierCall(target, functionSig);
    }

    return authorityForPool.canCall(user, target, functionSig);
  }
}
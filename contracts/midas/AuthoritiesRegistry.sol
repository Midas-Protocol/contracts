// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { PoolRolesAuthority } from "../midas/PoolRolesAuthority.sol";
import { SafeOwnableUpgradeable } from "../midas/SafeOwnableUpgradeable.sol";

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


  function createPoolAuthority(address pool) public onlyOwner {
    require(address(poolsAuthorities[pool]) == address(0), "already created");

    {
      TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(address(poolAuthLogic), owner(), "");
      PoolRolesAuthority auth = PoolRolesAuthority(address(proxy));
      auth.initialize(address(this));

      poolsAuthorities[pool] = auth;
    }
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
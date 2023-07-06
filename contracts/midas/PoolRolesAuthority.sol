// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IComptroller } from "../compound/ComptrollerInterface.sol";
import { ICErc20 } from "../compound/CTokenInterfaces.sol";

import { RolesAuthority, Authority } from "solmate/auth/authorities/RolesAuthority.sol";

import "openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";

contract PoolRolesAuthority is RolesAuthority, Initializable {
  constructor() RolesAuthority(address(0), Authority(address(0))) {
    _disableInitializers();
  }

  function initialize(address _owner) public initializer {
    owner = _owner;
  }

  // up to 256 roles
  uint8 public constant SUPPLIER_ROLE = 1;
  uint8 public constant BORROWER_ROLE = 2;
  uint8 public constant LIQUIDATOR_ROLE = 3;

  function configurePoolSupplierCapabilities(IComptroller pool) external requiresAuth {
    _configurePoolSupplierCapabilities(pool, SUPPLIER_ROLE);
  }

  function _configurePoolSupplierCapabilities(IComptroller pool, uint8 role) internal {
    setRoleCapability(role, address(pool), pool.enterMarkets.selector, true);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setRoleCapability(role, address(allMarkets[i]), allMarkets[i].mint.selector, true);
      setRoleCapability(role, address(allMarkets[i]), allMarkets[i].redeem.selector, true);
      setRoleCapability(role, address(allMarkets[i]), allMarkets[i].redeemUnderlying.selector, true);
      setRoleCapability(role, address(allMarkets[i]), allMarkets[i].transfer.selector, true);
      // TODO fns needed at all?
      setRoleCapability(role, address(allMarkets[i]), allMarkets[i].transferFrom.selector, true);
      setRoleCapability(role, address(allMarkets[i]), allMarkets[i].approve.selector, true);

      //setRoleCapability(role, address(allMarkets[i]), allMarkets[i].multicall.selector, true);
    }
  }

  function configurePoolBorrowerCapabilities(IComptroller pool) external requiresAuth {
    // TODO borrowers are supplier role by default?
    _configurePoolSupplierCapabilities(pool, BORROWER_ROLE);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].borrow.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrow.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrowBehalf.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), allMarkets[i].flash.selector, true);
    }
  }

  function configurePoolLiquidatorCapabilities(IComptroller pool) external requiresAuth {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setRoleCapability(LIQUIDATOR_ROLE, address(allMarkets[i]), allMarkets[i].liquidateBorrow.selector, true);
      // seize is called by other CTokens
      //setRoleCapability(LIQUIDATOR_ROLE, address(allMarkets[i]), allMarkets[i].seize.selector, true);
    }
  }
}

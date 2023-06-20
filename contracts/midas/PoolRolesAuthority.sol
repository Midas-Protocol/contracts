// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IComptroller } from "../compound/ComptrollerInterface.sol";

import { RolesAuthority } from "solmate/auth/authorities/RolesAuthority.sol";

import "openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";

contract PoolRolesAuthority is RolesAuthority, Initializeable {
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

  function configurePoolSupplierRole(IComptroller pool) external requiresAuth {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for(uint256 i = 0; i < allMarkets.length; i++) {
      // TODO make fns gated
      setRoleCapability(SUPPLIER_ROLE, address(allMarkets[i]), ICErc20.mint.selector, true);
      setRoleCapability(SUPPLIER_ROLE, address(allMarkets[i]), ICErc20.redeem.selector, true);
      setRoleCapability(SUPPLIER_ROLE, address(allMarkets[i]), ICErc20.redeemUnderlying.selector, true);
      setRoleCapability(SUPPLIER_ROLE, address(allMarkets[i]), ICErc20.transfer.selector, true);
      // TODO fns needed at all?
      setRoleCapability(SUPPLIER_ROLE, address(allMarkets[i]), ICErc20.transferFrom.selector, true);
      setRoleCapability(SUPPLIER_ROLE, address(allMarkets[i]), ICErc20.approve.selector, true);


      //setRoleCapability(SUPPLIER_ROLE, address(allMarkets[i]), ICErc20.multicall.selector, true);
    }
  }

  function configurePoolBorrowerRole(IComptroller pool) external requiresAuth {
    // TODO borrowers are supplier role by default?
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for(uint256 i = 0; i < allMarkets.length; i++) {
      // TODO make fns gated
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), ICErc20.borrow.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), ICErc20.repayBorrow.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), ICErc20.repayBorrowBehalf.selector, true);
      setRoleCapability(BORROWER_ROLE, address(allMarkets[i]), ICErc20.flash.selector, true);
    }
  }

  function configurePoolLiquidatorRole(IComptroller pool) external requiresAuth {
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for(uint256 i = 0; i < allMarkets.length; i++) {
      // TODO make fns gated
      setRoleCapability(LIQUIDATOR_ROLE, address(allMarkets[i]), ICErc20.liquidateBorrow.selector, true);
      // seize is called by other CTokens
      //setRoleCapability(LIQUIDATOR_ROLE, address(allMarkets[i]), ICErc20.seize.selector, true);
    }
  }
}
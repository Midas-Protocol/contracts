// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IComptroller, ComptrollerInterface } from "../compound/ComptrollerInterface.sol";
import { ICErc20, CErc20Interface, CTokenExtensionInterface } from "../compound/CTokenInterfaces.sol";

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
  uint8 public constant LEVERED_POSITION_ROLE = 4;

  function configurePoolSupplierCapabilities(IComptroller pool) external requiresAuth {
    _configurePoolSupplierCapabilities(pool, SUPPLIER_ROLE);
  }

  function getSupplierMarketSelectors() public pure returns (bytes4[] memory selectors) {
    uint8 fnsCount = 6;
    selectors = new bytes4[](fnsCount);
    selectors[--fnsCount] = CErc20Interface.mint.selector;
    selectors[--fnsCount] = CErc20Interface.redeem.selector;
    selectors[--fnsCount] = CErc20Interface.redeemUnderlying.selector;

    // TODO transfer/approve fns needed at all?
    selectors[--fnsCount] = CTokenExtensionInterface.transfer.selector;
    selectors[--fnsCount] = CTokenExtensionInterface.transferFrom.selector;
    selectors[--fnsCount] = CTokenExtensionInterface.approve.selector;

    // selectors[--fnsCount] = ICErc20.multicall.selector;

    require(fnsCount == 0, "use the correct array length");
    return selectors;
  }

  function isSupplierCall(address target, bytes4 selector) external pure returns (bool) {
    if (selector == ComptrollerInterface.enterMarkets.selector) return true;
    if (selector == ComptrollerInterface.exitMarket.selector) return true;

    bytes4[] memory supplierSelectors = getSupplierMarketSelectors();
    for (uint256 i = 0; i < supplierSelectors.length; i++) {
      if (selector == supplierSelectors[i]) return true;
    }

    return false;
  }

  function _configurePoolSupplierCapabilities(IComptroller pool, uint8 role) internal {
    setRoleCapability(role, address(pool), pool.enterMarkets.selector, true);
    setRoleCapability(role, address(pool), pool.exitMarket.selector, true);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      bytes4[] memory selectors = getSupplierMarketSelectors();
      for (uint256 j = 0; j < selectors.length; j++) {
        setRoleCapability(role, address(allMarkets[i]), selectors[j], true);
      }
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

  function configureLeveredPositionCapabilities(IComptroller pool) external requiresAuth {
    setRoleCapability(LEVERED_POSITION_ROLE, address(pool), pool.enterMarkets.selector, true);
    setRoleCapability(LEVERED_POSITION_ROLE, address(pool), pool.exitMarket.selector, true);
    ICErc20[] memory allMarkets = pool.getAllMarkets();
    for (uint256 i = 0; i < allMarkets.length; i++) {
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].mint.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].redeem.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].redeemUnderlying.selector, true);

      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].borrow.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].repayBorrow.selector, true);
      setRoleCapability(LEVERED_POSITION_ROLE, address(allMarkets[i]), allMarkets[i].flash.selector, true);
    }
  }
}

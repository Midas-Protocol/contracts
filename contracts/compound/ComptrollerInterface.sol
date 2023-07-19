// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BasePriceOracle } from "../oracles/BasePriceOracle.sol";
import { ICErc20 } from "./CTokenInterfaces.sol";
import { DiamondExtension } from "../ionic/DiamondExtension.sol";
import { ComptrollerV3Storage } from "../compound/ComptrollerStorage.sol";

interface ComptrollerInterface {
  function isDeprecated(ICErc20 cToken) external view returns (bool);

  function _becomeImplementation() external;

  function _deployMarket(
    uint8 delegateType,
    bytes memory constructorData,
    bytes calldata becomeImplData,
    uint256 collateralFactorMantissa
  ) external returns (uint256);

  function getAssetsIn(address account) external view returns (ICErc20[] memory);

  function checkMembership(address account, ICErc20 cToken) external view returns (bool);

  function _setPriceOracle(BasePriceOracle newOracle) external returns (uint256);

  function _setCloseFactor(uint256 newCloseFactorMantissa) external returns (uint256);

  function _setCollateralFactor(ICErc20 market, uint256 newCollateralFactorMantissa) external returns (uint256);

  function _setLiquidationIncentive(uint256 newLiquidationIncentiveMantissa) external returns (uint256);

  function _setWhitelistEnforcement(bool enforce) external returns (uint256);

  function _setWhitelistStatuses(address[] calldata _suppliers, bool[] calldata statuses) external returns (uint256);

  function _addRewardsDistributor(address distributor) external returns (uint256);

  function getHypotheticalAccountLiquidity(
    address account,
    address cTokenModify,
    uint256 redeemTokens,
    uint256 borrowAmount
  )
    external
    view
    returns (
      uint256,
      uint256,
      uint256
    );

  function getMaxRedeemOrBorrow(
    address account,
    ICErc20 cToken,
    bool isBorrow
  ) external view returns (uint256);

  /*** Assets You Are In ***/

  function enterMarkets(address[] calldata cTokens) external returns (uint256[] memory);

  function exitMarket(address cToken) external returns (uint256);

  /*** Policy Hooks ***/

  function mintAllowed(
    address cToken,
    address minter,
    uint256 mintAmount
  ) external returns (uint256);

  function redeemAllowed(
    address cToken,
    address redeemer,
    uint256 redeemTokens
  ) external returns (uint256);

  function redeemVerify(
    address cToken,
    address redeemer,
    uint256 redeemAmount,
    uint256 redeemTokens
  ) external;

  function borrowAllowed(
    address cToken,
    address borrower,
    uint256 borrowAmount
  ) external returns (uint256);

  function borrowWithinLimits(address cToken, uint256 accountBorrowsNew) external view returns (uint256);

  function repayBorrowAllowed(
    address cToken,
    address payer,
    address borrower,
    uint256 repayAmount
  ) external returns (uint256);

  function liquidateBorrowAllowed(
    address cTokenBorrowed,
    address cTokenCollateral,
    address liquidator,
    address borrower,
    uint256 repayAmount
  ) external returns (uint256);

  function seizeAllowed(
    address cTokenCollateral,
    address cTokenBorrowed,
    address liquidator,
    address borrower,
    uint256 seizeTokens
  ) external returns (uint256);

  function transferAllowed(
    address cToken,
    address src,
    address dst,
    uint256 transferTokens
  ) external returns (uint256);

  function mintVerify(
    address cToken,
    address minter,
    uint256 actualMintAmount,
    uint256 mintTokens
  ) external;

  /*** Liquidity/Liquidation Calculations ***/

  function getAccountLiquidity(address account)
    external
    view
    returns (
      uint256,
      uint256,
      uint256
    );

  function liquidateCalculateSeizeTokens(
    address cTokenBorrowed,
    address cTokenCollateral,
    uint256 repayAmount
  ) external view returns (uint256, uint256);

  /*** Pool-Wide/Cross-Asset Reentrancy Prevention ***/

  function _beforeNonReentrant() external;

  function _afterNonReentrant() external;
}

interface ComptrollerStorageInterface {
  function admin() external view returns (address);

  function adminHasRights() external view returns (bool);

  function ionicAdmin() external view returns (address);

  function ionicAdminHasRights() external view returns (bool);

  function oracle() external view returns (BasePriceOracle);

  function pauseGuardian() external view returns (address);

  function closeFactorMantissa() external view returns (uint256);

  function liquidationIncentiveMantissa() external view returns (uint256);

  function isUserOfPool(address user) external view returns (bool);

  function whitelist(address account) external view returns (bool);

  function enforceWhitelist() external view returns (bool);

  function borrowCapForCollateral(address borrowed, address collateral) external view returns (uint256);

  function borrowingAgainstCollateralBlacklist(address borrowed, address collateral) external view returns (bool);

  function suppliers(address account) external view returns (bool);

  function cTokensByUnderlying(address) external view returns (address);

  function supplyCaps(address cToken) external view returns (uint256);

  function borrowCaps(address cToken) external view returns (uint256);

  function markets(address cToken) external view returns (bool, uint256);

  function accountAssets(address, uint256) external view returns (address);

  function borrowGuardianPaused(address cToken) external view returns (bool);

  function mintGuardianPaused(address cToken) external view returns (bool);

  function rewardsDistributors(uint256) external view returns (address);
}

interface ComptrollerExtensionInterface {
  function getWhitelistedSuppliersSupply(address cToken) external view returns (uint256 supplied);

  function getWhitelistedBorrowersBorrows(address cToken) external view returns (uint256 borrowed);

  function getAllMarkets() external view returns (ICErc20[] memory);

  function getAllBorrowers() external view returns (address[] memory);

  function getRewardsDistributors() external view returns (address[] memory);

  function getAccruingFlywheels() external view returns (address[] memory);

  function _supplyCapWhitelist(
    address cToken,
    address account,
    bool whitelisted
  ) external;

  function _setBorrowCapForCollateral(
    address cTokenBorrow,
    address cTokenCollateral,
    uint256 borrowCap
  ) external;

  function _setBorrowCapForCollateralWhitelist(
    address cTokenBorrow,
    address cTokenCollateral,
    address account,
    bool whitelisted
  ) external;

  function isBorrowCapForCollateralWhitelisted(
    address cTokenBorrow,
    address cTokenCollateral,
    address account
  ) external view returns (bool);

  function _blacklistBorrowingAgainstCollateral(
    address cTokenBorrow,
    address cTokenCollateral,
    bool blacklisted
  ) external;

  function _blacklistBorrowingAgainstCollateralWhitelist(
    address cTokenBorrow,
    address cTokenCollateral,
    address account,
    bool whitelisted
  ) external;

  function isBlacklistBorrowingAgainstCollateralWhitelisted(
    address cTokenBorrow,
    address cTokenCollateral,
    address account
  ) external view returns (bool);

  function isSupplyCapWhitelisted(address cToken, address account) external view returns (bool);

  function _borrowCapWhitelist(
    address cToken,
    address account,
    bool whitelisted
  ) external;

  function isBorrowCapWhitelisted(address cToken, address account) external view returns (bool);

  function _removeFlywheel(address flywheelAddress) external returns (bool);

  function getWhitelist() external view returns (address[] memory);

  function addNonAccruingFlywheel(address flywheelAddress) external returns (bool);

  function _setMarketSupplyCaps(ICErc20[] calldata cTokens, uint256[] calldata newSupplyCaps) external;

  function _setMarketBorrowCaps(ICErc20[] calldata cTokens, uint256[] calldata newBorrowCaps) external;

  function _setBorrowCapGuardian(address newBorrowCapGuardian) external;

  function _setPauseGuardian(address newPauseGuardian) external returns (uint256);

  function _setMintPaused(ICErc20 cToken, bool state) external returns (bool);

  function _setBorrowPaused(ICErc20 cToken, bool state) external returns (bool);

  function _setTransferPaused(bool state) external returns (bool);

  function _setSeizePaused(bool state) external returns (bool);

  function _unsupportMarket(ICErc20 cToken) external returns (uint256);

  function getAssetAsCollateralValueCap(
    ICErc20 collateral,
    ICErc20 cTokenModify,
    bool redeeming,
    address account
  ) external view returns (uint256);
}

interface UnitrollerInterface {
  function comptrollerImplementation() external view returns (address);

  function _upgrade() external;

  function _acceptAdmin() external returns (uint256);

  function _setPendingAdmin(address newPendingAdmin) external returns (uint256);

  function _toggleAdminRights(bool hasRights) external returns (uint256);
}

interface IComptrollerExtension is ComptrollerExtensionInterface, ComptrollerStorageInterface {}

//interface IComptrollerBase is ComptrollerInterface, ComptrollerStorageInterface {}

interface IComptroller is
  ComptrollerInterface,
  ComptrollerExtensionInterface,
  UnitrollerInterface,
  ComptrollerStorageInterface
{

}

abstract contract ComptrollerBase is ComptrollerV3Storage {
  /// @notice Indicator that this is a Comptroller contract (for inspection)
  bool public constant isComptroller = true;
}

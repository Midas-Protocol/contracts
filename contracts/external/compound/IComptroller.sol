// SPDX-License-Identifier: BSD-3-Clause
pragma solidity >=0.8.0;

import "./IPriceOracle.sol";
import "./ICToken.sol";
import "./IUnitroller.sol";
import "./IRewardsDistributor.sol";

/**
 * @title Compound's Comptroller Contract
 * @author Compound
 */
interface IComptroller {
    function admin() external view returns (address);
    function adminHasRights() external view returns (bool);
    function fuseAdminHasRights() external view returns (bool);

    function oracle() external view returns (IPriceOracle);
    function closeFactorMantissa() external view returns (uint);
    function liquidationIncentiveMantissa() external view returns (uint);

    function markets(address cToken) external view returns (bool, uint);

    function getAssetsIn(address account) external view returns (ICToken[] memory);
    function checkMembership(address account, ICToken cToken) external view returns (bool);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);

    function _setPriceOracle(IPriceOracle newOracle) external returns (uint);
    function _setCloseFactor(uint newCloseFactorMantissa) external returns (uint256);
    function _setLiquidationIncentive(uint newLiquidationIncentiveMantissa) external returns (uint);
    function _become(IUnitroller unitroller) external;

    function borrowGuardianPaused(address cToken) external view returns (bool);

    function getRewardsDistributors() external view returns (IRewardsDistributor[] memory);
    function getAllMarkets() external view returns (ICToken[] memory);
    function getAllBorrowers() external view returns (address[] memory);
    function suppliers(address account) external view returns (bool);
    function enforceWhitelist() external view returns (bool);
    function whitelist(address account) external view returns (bool);

    function _setWhitelistEnforcement(bool enforce) external returns (uint);
    function _setWhitelistStatuses(address[] calldata _suppliers, bool[] calldata statuses) external returns (uint);

    function _toggleAutoImplementations(bool enabled) external returns (uint);
}

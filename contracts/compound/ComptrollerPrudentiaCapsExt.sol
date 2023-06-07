// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import { DiamondExtension } from "../midas/DiamondExtension.sol";
import { CTokenInterface, CTokenExtensionInterface, CErc20Interface } from "./CTokenInterfaces.sol";
import { ComptrollerV4Storage } from "./ComptrollerStorage.sol";

/**
 * @title ComptrollerPrudentiaCapsExt
 * @author Tyler Loewen (TRILEZ SOFTWARE INC. dba. Adrastia)
 * @notice A diamond extension that allows the Comptroller to use Adrastia Prudentia to control supply and borrow caps.
 */
contract ComptrollerPrudentiaCapsExt is DiamondExtension, ComptrollerV4Storage {
  /**
   * @notice Emitted when the Adrastia Prudentia supply cap config is changed.
   * @param oldConfig The old config.
   * @param newConfig The new config.
   */
  event NewSupplyCapConfig(PrudentiaConfig oldConfig, PrudentiaConfig newConfig);

  /**
   * @notice Emitted when the Adrastia Prudentia borrow cap config is changed.
   * @param oldConfig The old config.
   * @param newConfig The new config.
   */
  event NewBorrowCapConfig(PrudentiaConfig oldConfig, PrudentiaConfig newConfig);

  /**
   * @notice Sets the Adrastia Prudentia supply cap config.
   * @dev Specifying a zero address for the `controller` parameter will make the Comptroller use the native supply caps.
   * @param newConfig The new config.
   */
  function _setSupplyCapConfig(PrudentiaConfig calldata newConfig) external {
    require(msg.sender == admin || msg.sender == borrowCapGuardian, "!admin");

    PrudentiaConfig memory oldConfig = supplyCapConfig;
    supplyCapConfig = newConfig;

    emit NewSupplyCapConfig(oldConfig, newConfig);
  }

  /**
   * @notice Sets the Adrastia Prudentia supply cap config.
   * @dev Specifying a zero address for the `controller` parameter will make the Comptroller use the native borrow caps.
   * @param newConfig The new config.
   */
  function _setBorrowCapConfig(PrudentiaConfig calldata newConfig) external {
    require(msg.sender == admin || msg.sender == borrowCapGuardian, "!admin");

    PrudentiaConfig memory oldConfig = borrowCapConfig;
    borrowCapConfig = newConfig;

    emit NewBorrowCapConfig(oldConfig, newConfig);
  }

  /**
   * @notice Retrieves Adrastia Prudentia borrow cap config from storage.
   * @return The config.
   */
  function getBorrowCapConfig() external view returns (PrudentiaConfig memory) {
    return borrowCapConfig;
  }

  /**
   * @notice Retrieves Adrastia Prudentia supply cap config from storage.
   * @return The config.
   */
  function getSupplyCapConfig() external view returns (PrudentiaConfig memory) {
    return supplyCapConfig;
  }

  function _getExtensionFunctions() external pure virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 4;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this._setSupplyCapConfig.selector;
    functionSelectors[--fnsCount] = this._setBorrowCapConfig.selector;
    functionSelectors[--fnsCount] = this.getBorrowCapConfig.selector;
    functionSelectors[--fnsCount] = this.getSupplyCapConfig.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }
}

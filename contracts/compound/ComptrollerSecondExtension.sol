// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { DiamondExtension } from "../midas/DiamondExtension.sol";
import { ComptrollerErrorReporter } from "../compound/ErrorReporter.sol";
import { ComptrollerV3Storage } from "./Comptroller.sol";

contract ComptrollerSecondExtension is DiamondExtension, ComptrollerV3Storage, ComptrollerErrorReporter {
  function getFirstMarketSymbol() public view returns (string memory) {
    return allMarkets[0].symbol();
  }

  function _setTransferPaused(bool state) public returns (bool) {
    return false;
  }

  function _setSeizePaused(bool state) public returns (bool) {
    return false;
  }

  // a dummy fn to test if the replacement of extension fns works
  function getSecondMarketSymbol() public view returns (string memory) {
    return allMarkets[1].symbol();
  }

  function _getExtensionFunctions() external view virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 4;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this._setTransferPaused.selector;
    functionSelectors[--fnsCount] = this._setSeizePaused.selector;
    functionSelectors[--fnsCount] = this.getFirstMarketSymbol.selector;
    functionSelectors[--fnsCount] = this.getSecondMarketSymbol.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }
}

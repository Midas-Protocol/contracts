// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import "./LeveredVaultStorage.sol";
import { DiamondExtension } from "../../DiamondExtension.sol";

import { ReentrancyGuardUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/security/ReentrancyGuardUpgradeable.sol";

abstract contract LeveredVaultExtension is ReentrancyGuardUpgradeable, LeveredVaultStorage, DiamondExtension {
  constructor() {
    _disableInitializers();
  }

  function _getExtensionFunctions() external pure virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 1;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.initialize.selector;

    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }

  function initialize(bytes memory initData) public {
    (ICErc20 _collateral, IERC20[] memory _borrowable) = abi.decode(initData, (ICErc20, IERC20[]));

    collateral = _collateral;
    borrowable = _borrowable;
  }

  function depositCollateralBorrowStableSwapAndLeverUp(uint256 amount) public {
    address caller = msg.sender;
  }

  function _depositCollateral(uint256 amount) internal {
    require(collateral.mint(amount) == 0, "deposit collateral failed");
  }

  function _borrowStable() internal {}

  function _swapForCollateral() internal {}

  function _leverUp() internal {}
}

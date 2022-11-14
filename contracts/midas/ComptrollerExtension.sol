// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../compound/ComptrollerStorage.sol";
import "../compound/Unitroller.sol";

abstract contract ComptrollerExtension is ComptrollerV3Storage {
  function _initExtension(ComptrollerExtension extension) external {
    require(hasAdminRights(), "!unauthorized");

    LibDiamond.init(extension);
  }

  function _getExtensionFunctions() external view virtual returns (bytes4[] memory);
}

library LibDiamond {
  bytes32 constant DIAMOND_STORAGE_POSITION = keccak256("diamond.standard.diamond.storage");

  struct Function {
    address implementation;
    uint16 index; // used to remove functions without looping
  }

  struct LogicStorage {
    mapping(bytes4 => Function) functions;
    bytes4[] indexes;
    // mapping(bytes4 => bool) supportedInterfaces;
  }

  function diamondStorage() internal pure returns (LogicStorage storage ds) {
    bytes32 position = DIAMOND_STORAGE_POSITION;
    assembly {
      ds.slot := position
    }
  }

  function init(ComptrollerExtension extension) internal {
    bytes4[] memory fnsToAdd = extension._getExtensionFunctions();
    addFunctions(address(extension), fnsToAdd);
  }

  function registerExtension(address extensionToAdd, address extensionToReplace) internal {
    require(extensionToAdd != address(0), "CannotAddSelectorsToZeroAddress");
    enforceHasContractCode(extensionToAdd, "LibDiamondCut: extension has no code");

    LogicStorage storage ds = diamondStorage();
    uint16 totalSelectorsCount = uint16(ds.indexes.length);

    if (extensionToReplace != address(0)) {
      // first remove all functions of the extension to replace
      for (uint256 i = 0; i < totalSelectorsCount; i++) {
        bytes4 selector = ds.indexes[i];
        address selectorImpl = ds.functions[selector].implementation;
        if (selectorImpl == extensionToReplace) {
          removeFunctionAtIndex(i);
        }
      }
    }

    bytes4[] memory fnsToAdd = ComptrollerExtension(extensionToAdd)._getExtensionFunctions();
    addFunctions(extensionToAdd, fnsToAdd);
  }

  function removeFunctionAtIndex(uint256 index) internal {
    // TODO
    LogicStorage storage ds = diamondStorage();
    bytes4 selector = ds.indexes[index];
    delete ds.functions[selector];
    ds.indexes[index] = ds.indexes[ds.indexes.length - 1];
    ds.indexes.pop();
  }

  function addFunctions(address extension, bytes4[] memory _functionSelectors) internal {
    require(extension != address(0), "CannotAddSelectorsToZeroAddress");
    LogicStorage storage ds = diamondStorage();
    uint16 selectorCount = uint16(ds.indexes.length);
    enforceHasContractCode(extension, "LibDiamondCut: extension has no code");
    for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
      bytes4 selector = _functionSelectors[selectorIndex];
      address oldImplementation = ds.functions[selector].implementation;
      require(oldImplementation == address(0), "CannotAddFunctionToDiamondThatAlreadyExists");
      ds.functions[selector] = Function(extension, selectorCount);
      ds.indexes.push(selector);
      selectorCount++;
    }
  }

  function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
    uint256 contractSize;
    assembly {
      contractSize := extcodesize(_contract)
    }
    require(contractSize != 0, _errorMessage);
  }
}

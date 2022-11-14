// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../compound/ComptrollerStorage.sol";
import "../compound/Unitroller.sol";

abstract contract ComptrollerExtension is ComptrollerV3Storage {
  function _initExtension(address extension, bytes calldata data) external {
    require(hasAdminRights(), "!unauthorized");

    LibDiamond.init(extension, data);
  }
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

  function init(address extension, bytes memory data) internal {
    bytes4[] memory fnsToAdd = abi.decode(data, (bytes4[]));
    addFunctions(extension, fnsToAdd);
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

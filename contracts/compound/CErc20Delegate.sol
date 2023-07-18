// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./CToken.sol";

/**
 * @title Compound's CErc20Delegate Contract
 * @notice CTokens which wrap an EIP-20 underlying and are delegated to
 * @author Compound
 */
contract CErc20Delegate is CErc20 {
  function _getExtensionFunctions() public pure virtual override returns (bytes4[] memory functionSelectors) {
    uint8 fnsCount = 6;

    bytes4[] memory superFunctionSelectors = super._getExtensionFunctions();
    functionSelectors = new bytes4[](superFunctionSelectors.length + fnsCount);

    for (uint256 i = 0; i < superFunctionSelectors.length; i++) {
      functionSelectors[i] = superFunctionSelectors[i];
    }

    functionSelectors[--fnsCount + superFunctionSelectors.length] = this.implementation.selector;
    functionSelectors[--fnsCount + superFunctionSelectors.length] = this.contractType.selector;
    functionSelectors[--fnsCount + superFunctionSelectors.length] = this.delegateType.selector;
    functionSelectors[--fnsCount + superFunctionSelectors.length] = this._becomeImplementation.selector;
    functionSelectors[--fnsCount + superFunctionSelectors.length] = this._setImplementationSafe.selector;
    functionSelectors[--fnsCount + superFunctionSelectors.length] = this._prepare.selector;

    require(fnsCount == 0, "use the correct array length");
  }

  /**
   * @notice Called by the delegator on a delegate to initialize it for duty
   */
  function _becomeImplementation(bytes memory) public virtual override {
    require(msg.sender == address(this) || hasAdminRights(), "!self || !admin");
  }

  function implementation() public view returns (address) {
    return LibDiamond.getExtensionForFunction(this.delegateType.selector);
  }

  /**
   * @dev Internal function to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationInternal(
    address implementation_,
    bytes memory becomeImplementationData
  ) internal {
    address currentDelegate = implementation();
    LibDiamond.registerExtension(DiamondExtension(implementation_), DiamondExtension(currentDelegate));
    _updateExtensions();

    // TODO can we replace it with reinitialize?
    this._becomeImplementation(becomeImplementationData);

    emit NewImplementation(currentDelegate, implementation_);
  }

  function _updateExtensions() internal {
    address currentDelegate = implementation();
    address[] memory latestExtensions = IFeeDistributor(ionicAdmin).getCErc20DelegateExtensions(currentDelegate);
    address[] memory currentExtensions = LibDiamond.listExtensions();

    // removed the current (old) extensions
    for (uint256 i = 0; i < currentExtensions.length; i++) {
      LibDiamond.removeExtension(DiamondExtension(currentExtensions[i]));
    }
    // add the new extensions
    for (uint256 i = 0; i < latestExtensions.length; i++) {
      LibDiamond.addExtension(DiamondExtension(latestExtensions[i]));
    }
  }

  /**
   * @notice Called by the admin to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationSafe(
    address implementation_,
    bool allowResign,
    bytes calldata becomeImplementationData
  ) external override {
    // Check admin rights
    require(hasAdminRights(), "!admin");

    // TODO allowResign is unused
    // Set implementation
    _setImplementationInternal(implementation_, becomeImplementationData);
  }

  /**
   * @notice Function called before all delegator functions
   * @dev upgrades the implementation if necessary
   */
  function _prepare() external payable override {
    require(msg.sender == address(this) || hasAdminRights(), "!self or admin");

    uint8 currentDelegateType = delegateType();
    (address latestCErc20Delegate, bool allowResign, bytes memory becomeImplementationData) = IFeeDistributor(
      ionicAdmin
    ).latestCErc20Delegate(currentDelegateType);
    // TODO allowResign is unused

    address currentDelegate = implementation();
    if (currentDelegate != latestCErc20Delegate) {
      _setImplementationInternal(latestCErc20Delegate, becomeImplementationData);
    } else {
      // only update the extensions without reinitializing with becomeImplementationData
      _updateExtensions();
    }
  }

  function delegateType() public pure virtual override returns (uint8) {
    return 1;
  }

  function contractType() external pure virtual override returns (string memory) {
    return "CErc20Delegate";
  }
}

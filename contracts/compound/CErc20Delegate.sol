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
   * @notice Called by the delegator on a delegate to forfeit its responsibility
   */
  function _resignImplementation() internal virtual {}

  /**
   * @dev Internal function to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param allowResign Flag to indicate whether to call _resignImplementation on the old implementation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationInternal(
    address implementation_,
    bool allowResign,
    bytes memory becomeImplementationData
  ) internal {
    // Call _resignImplementation internally (this delegate's code)
    if (allowResign) _resignImplementation();

    address currentDelegate = LibDiamond.getExtensionForFunction(this.delegateType.selector);
    LibDiamond.registerExtension(DiamondExtension(implementation_), DiamondExtension(currentDelegate));

    this._becomeImplementation(becomeImplementationData);

    emit NewImplementation(currentDelegate, implementation_);
  }

  function _updateExtensions() internal {
    address currentDelegate = LibDiamond.getExtensionForFunction(this.delegateType.selector);
    address[] memory latestExtensions = IFeeDistributor(ionicAdmin).getCErc20DelegateExtensions(currentDelegate);
    address[] memory currentExtensions = LibDiamond.listExtensions();

    // don't update if they are the same
    if (latestExtensions.length == 1 && currentExtensions.length == 1 && latestExtensions[0] == currentExtensions[0])
      return;

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

    // Set implementation
    _setImplementationInternal(implementation_, allowResign, becomeImplementationData);
  }

  /**
   * @notice Function called before all delegator functions
   * @dev Checks comptroller.autoImplementation and upgrades the implementation if necessary
   */
  function _prepare() external payable override {
    if (msg.sender != address(this) && ComptrollerV3Storage(address(comptroller)).autoImplementation()) {
      uint8 currentDelegateType = delegateType();
      (address latestCErc20Delegate, bool allowResign, bytes memory becomeImplementationData) = IFeeDistributor(
        ionicAdmin
      ).latestCErc20Delegate(currentDelegateType);

      address currentDelegate = LibDiamond.getExtensionForFunction(this.delegateType.selector);
      if (currentDelegate != latestCErc20Delegate) {
        _setImplementationInternal(latestCErc20Delegate, allowResign, becomeImplementationData);
      } else {
        _updateExtensions();
      }
    }
  }

  function delegateType() public pure virtual override returns (uint8) {
    return 1;
  }

  function contractType() external pure virtual override returns (string memory) {
    return "CErc20Delegate";
  }
}

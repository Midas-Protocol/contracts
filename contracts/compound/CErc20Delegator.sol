// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./ComptrollerInterface.sol";
import "./InterestRateModel.sol";
import "../ionic/DiamondExtension.sol";
import { CErc20DelegatorBase, CDelegateInterface } from "./CTokenInterfaces.sol";
import { IFeeDistributor } from "./IFeeDistributor.sol";
import { EIP20Interface } from "./EIP20Interface.sol";

/**
 * @title Compound's CErc20Delegator Contract
 * @notice CTokens which wrap an EIP-20 underlying and delegate to an implementation
 * @author Compound
 */
contract CErc20Delegator is CErc20DelegatorBase, DiamondBase {
  /**
   * @notice Emitted when implementation is changed
   */
  event NewImplementation(address oldImplementation, address newImplementation);

  /**
   * @notice Initialize the new money market
   * @param underlying_ The address of the underlying asset
   * @param comptroller_ The address of the Comptroller
   * @param feeDistributor The FeeDistributor contract address.
   * @param interestRateModel_ The address of the interest rate model
   * @param name_ ERC-20 name of this token
   * @param symbol_ ERC-20 symbol of this token
   */
  constructor(
    address underlying_,
    IComptroller comptroller_,
    address payable feeDistributor,
    InterestRateModel interestRateModel_,
    string memory name_,
    string memory symbol_,
    uint256 reserveFactorMantissa_,
    uint256 adminFeeMantissa_
  ) {
    // CToken initialize does the bulk of the work
    uint256 initialExchangeRateMantissa_ = 0.2e18;
    uint8 decimals_ = EIP20Interface(underlying_).decimals();
    superInitialize(
      comptroller_,
      feeDistributor,
      interestRateModel_,
      initialExchangeRateMantissa_,
      name_,
      symbol_,
      decimals_,
      reserveFactorMantissa_,
      adminFeeMantissa_
    );

    // Set underlying and sanity check it
    underlying = underlying_;
    EIP20Interface(underlying).totalSupply();
  }

  /**
   * @notice Initialize the money market
   * @param comptroller_ The address of the Comptroller
   * @param ionicAdmin_ The FeeDistributor contract address.
   * @param interestRateModel_ The address of the interest rate model
   * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
   * @param name_ EIP-20 name of this token
   * @param symbol_ EIP-20 symbol of this token
   * @param decimals_ EIP-20 decimal precision of this token
   */
  function superInitialize(
    IComptroller comptroller_,
    address payable ionicAdmin_,
    InterestRateModel interestRateModel_,
    uint256 initialExchangeRateMantissa_,
    string memory name_,
    string memory symbol_,
    uint8 decimals_,
    uint256 reserveFactorMantissa_,
    uint256 adminFeeMantissa_
  ) public {
    require(msg.sender == ionicAdmin_, "!admin");
    require(accrualBlockNumber == 0 && borrowIndex == 0, "!initialized");

    ionicAdmin = ionicAdmin_;

    // Set initial exchange rate
    initialExchangeRateMantissa = initialExchangeRateMantissa_;
    require(initialExchangeRateMantissa > 0, "!exchangeRate>0");

    // Set the comptroller
    comptroller = comptroller_;

    // Initialize block number and borrow index (block number mocks depend on comptroller being set)
    accrualBlockNumber = block.number;
    borrowIndex = 1e18;

    // Set the interest rate model (depends on block number / borrow index)
    require(interestRateModel_.isInterestRateModel(), "!notIrm");
    interestRateModel = interestRateModel_;
    emit NewMarketInterestRateModel(InterestRateModel(address(0)), interestRateModel_);

    name = name_;
    symbol = symbol_;
    decimals = decimals_;

    // Set reserve factor
    // Check newReserveFactor ≤ maxReserveFactor
    require(
      reserveFactorMantissa_ + adminFeeMantissa + ionicFeeMantissa <= reserveFactorPlusFeesMaxMantissa,
      "!rf:set"
    );
    reserveFactorMantissa = reserveFactorMantissa_;
    emit NewReserveFactor(0, reserveFactorMantissa_);

    // Set admin fee
    // Sanitize adminFeeMantissa_
    if (adminFeeMantissa_ == type(uint256).max) adminFeeMantissa_ = adminFeeMantissa;
    // Get latest Ionic fee
    uint256 newFuseFeeMantissa = IFeeDistributor(ionicAdmin).interestFeeRate();
    require(
      reserveFactorMantissa + adminFeeMantissa_ + newFuseFeeMantissa <= reserveFactorPlusFeesMaxMantissa,
      "!adminFee:set"
    );
    adminFeeMantissa = adminFeeMantissa_;
    emit NewAdminFee(0, adminFeeMantissa_);
    ionicFeeMantissa = newFuseFeeMantissa;
    emit NewFuseFee(0, newFuseFeeMantissa);

    // The counter starts true to prevent changing it from zero to non-zero (i.e. smaller cost/refund)
    _notEntered = true;
  }

  function implementation() public view returns (address) {
    return LibDiamond.getExtensionForFunction(bytes4(keccak256(bytes("delegateType()"))));
  }

  /**
   * @dev Internal function to update the implementation of the delegator
   * @param implementation_ The address of the new implementation for delegation
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationInternal(address implementation_, bytes memory becomeImplementationData) internal {
    address currentDelegate = implementation();
    LibDiamond.registerExtension(DiamondExtension(implementation_), DiamondExtension(currentDelegate));
    _updateExtensions(currentDelegate);

    // TODO can we replace it with reinitialize? "_becomeImplementation(bytes)"
    _functionCall(
      address(this),
      abi.encodeWithSelector(CDelegateInterface._becomeImplementation.selector, becomeImplementationData),
      "!become impl"
    );

    emit NewImplementation(currentDelegate, implementation_);
  }

  function _updateExtensions(address currentDelegate) internal {
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
   * @param becomeImplementationData The encoded bytes data to be passed to _becomeImplementation
   */
  function _setImplementationSafe(address implementation_, bytes calldata becomeImplementationData) external override {
    // Check admin rights
    require(hasAdminRights(), "!admin");

    // Set implementation
    _setImplementationInternal(implementation_, becomeImplementationData);
  }

  /**
   * @notice Function called before all delegator functions
   * @dev upgrades the implementation if necessary
   */
  function _prepare() external payable override {
    require(msg.sender == address(this) || hasAdminRights(), "!self or admin");

    (bool success, bytes memory data) = address(this).staticcall(abi.encodeWithSignature("delegateType()"));
    require(success, "no delegate type");

    uint8 currentDelegateType = abi.decode(data, (uint8));
    (address latestCErc20Delegate, bytes memory becomeImplementationData) = IFeeDistributor(ionicAdmin)
      .latestCErc20Delegate(currentDelegateType);

    address currentDelegate = implementation();
    if (currentDelegate != latestCErc20Delegate) {
      _setImplementationInternal(latestCErc20Delegate, becomeImplementationData);
    } else {
      // only update the extensions without reinitializing with becomeImplementationData
      _updateExtensions(currentDelegate);
    }
  }

  /**
   * @dev register a logic extension
   * @param extensionToAdd the extension whose functions are to be added
   * @param extensionToReplace the extension whose functions are to be removed/replaced
   */
  function _registerExtension(DiamondExtension extensionToAdd, DiamondExtension extensionToReplace) external override {
    require(msg.sender == address(ionicAdmin), "!unauthorized");
    LibDiamond.registerExtension(extensionToAdd, extensionToReplace);
  }

  function _functionCall(
    address target,
    bytes memory data,
    string memory errorMessage
  ) internal returns (bytes memory) {
    (bool success, bytes memory returndata) = target.call(data);

    if (!success) {
      // Look for revert reason and bubble it up if present
      if (returndata.length > 0) {
        // The easiest way to bubble the revert reason is using memory via assembly

        // solhint-disable-next-line no-inline-assembly
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }

    return returndata;
  }
}

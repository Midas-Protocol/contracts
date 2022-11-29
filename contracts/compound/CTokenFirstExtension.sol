// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { DiamondExtension } from "../midas/DiamondExtension.sol";
import { CTokenExtensionInterface, ComptrollerV3Storage } from "./CTokenInterfaces.sol";
import { TokenErrorReporter } from "./ErrorReporter.sol";
import { Exponential } from "./Exponential.sol";
import { CDelegationStorage } from "./CDelegateInterface.sol";
import { InterestRateModel } from "./InterestRateModel.sol";

contract CTokenFirstExtension is
  CDelegationStorage,
  CTokenExtensionInterface,
  TokenErrorReporter,
  Exponential,
  DiamondExtension
{
  function _getExtensionFunctions() external view virtual override returns (bytes4[] memory) {
    uint8 fnsCount = 5;
    bytes4[] memory functionSelectors = new bytes4[](fnsCount);
    functionSelectors[--fnsCount] = this.transfer.selector;
    functionSelectors[--fnsCount] = this.transferFrom.selector;
    functionSelectors[--fnsCount] = this.allowance.selector;
    functionSelectors[--fnsCount] = this.approve.selector;
    functionSelectors[--fnsCount] = this.balanceOf.selector;
    require(fnsCount == 0, "use the correct array length");
    return functionSelectors;
  }

  /* ERC20 fns */
  /**
   * @notice Transfer `tokens` tokens from `src` to `dst` by `spender`
   * @dev Called by both `transfer` and `transferFrom` internally
   * @param spender The address of the account performing the transfer
   * @param src The address of the source account
   * @param dst The address of the destination account
   * @param tokens The number of tokens to transfer
   * @return Whether or not the transfer succeeded
   */
  function transferTokens(
    address spender,
    address src,
    address dst,
    uint256 tokens
  ) internal returns (uint256) {
    /* Fail if transfer not allowed */
    uint256 allowed = comptroller.transferAllowed(address(this), src, dst, tokens);
    if (allowed != 0) {
      return failOpaque(Error.COMPTROLLER_REJECTION, FailureInfo.TRANSFER_COMPTROLLER_REJECTION, allowed);
    }

    /* Do not allow self-transfers */
    if (src == dst) {
      return fail(Error.BAD_INPUT, FailureInfo.TRANSFER_NOT_ALLOWED);
    }

    /* Get the allowance, infinite for the account owner */
    uint256 startingAllowance = 0;
    if (spender == src) {
      startingAllowance = type(uint256).max;
    } else {
      startingAllowance = transferAllowances[src][spender];
    }

    /* Do the calculations, checking for {under,over}flow */
    MathError mathErr;
    uint256 allowanceNew;
    uint256 srcTokensNew;
    uint256 dstTokensNew;

    (mathErr, allowanceNew) = subUInt(startingAllowance, tokens);
    if (mathErr != MathError.NO_ERROR) {
      return fail(Error.MATH_ERROR, FailureInfo.TRANSFER_NOT_ALLOWED);
    }

    (mathErr, srcTokensNew) = subUInt(accountTokens[src], tokens);
    if (mathErr != MathError.NO_ERROR) {
      return fail(Error.MATH_ERROR, FailureInfo.TRANSFER_NOT_ENOUGH);
    }

    (mathErr, dstTokensNew) = addUInt(accountTokens[dst], tokens);
    if (mathErr != MathError.NO_ERROR) {
      return fail(Error.MATH_ERROR, FailureInfo.TRANSFER_TOO_MUCH);
    }

    /////////////////////////
    // EFFECTS & INTERACTIONS
    // (No safe failures beyond this point)

    accountTokens[src] = srcTokensNew;
    accountTokens[dst] = dstTokensNew;

    /* Eat some of the allowance (if necessary) */
    if (startingAllowance != type(uint256).max) {
      transferAllowances[src][spender] = allowanceNew;
    }

    /* We emit a Transfer event */
    emit Transfer(src, dst, tokens);

    /* We call the defense hook */
    // unused function
    // comptroller.transferVerify(address(this), src, dst, tokens);

    return uint256(Error.NO_ERROR);
  }

  /**
   * @notice Transfer `amount` tokens from `msg.sender` to `dst`
   * @param dst The address of the destination account
   * @param amount The number of tokens to transfer
   * @return Whether or not the transfer succeeded
   */
  function transfer(address dst, uint256 amount) external override nonReentrant(false) returns (bool) {
    return transferTokens(msg.sender, msg.sender, dst, amount) == uint256(Error.NO_ERROR);
  }

  /**
   * @notice Transfer `amount` tokens from `src` to `dst`
   * @param src The address of the source account
   * @param dst The address of the destination account
   * @param amount The number of tokens to transfer
   * @return Whether or not the transfer succeeded
   */
  function transferFrom(
    address src,
    address dst,
    uint256 amount
  ) external override nonReentrant(false) returns (bool) {
    return transferTokens(msg.sender, src, dst, amount) == uint256(Error.NO_ERROR);
  }

  /**
   * @notice Approve `spender` to transfer up to `amount` from `src`
   * @dev This will overwrite the approval amount for `spender`
   *  and is subject to issues noted [here](https://eips.ethereum.org/EIPS/eip-20#approve)
   * @param spender The address of the account which may transfer tokens
   * @param amount The number of tokens that are approved (-1 means infinite)
   * @return Whether or not the approval succeeded
   */
  function approve(address spender, uint256 amount) external override returns (bool) {
    address src = msg.sender;
    transferAllowances[src][spender] = amount;
    emit Approval(src, spender, amount);
    return true;
  }

  /**
   * @notice Get the current allowance from `owner` for `spender`
   * @param owner The address of the account which owns the tokens to be spent
   * @param spender The address of the account which may transfer tokens
   * @return The number of tokens allowed to be spent (-1 means infinite)
   */
  function allowance(address owner, address spender) external view override returns (uint256) {
    return transferAllowances[owner][spender];
  }

  /**
   * @notice Get the token balance of the `owner`
   * @param owner The address of the account to query
   * @return The number of tokens owned by `owner`
   */
  function balanceOf(address owner) external view override returns (uint256) {
    return accountTokens[owner];
  }

  /**
   * @notice updates the cToken ERC20 name and symbol
   * @dev Admin function to update the cToken ERC20 name and symbol
   * @param _name the new ERC20 token name to use
   * @param _symbol the new ERC20 token symbol to use
   */
  function _setNameAndSymbol(string calldata _name, string calldata _symbol) external {
    // Check caller is admin
    require(hasAdminRights(), "!admin");

    // Set ERC20 name and symbol
    name = _name;
    symbol = _symbol;
  }

  /**
   * @notice accrues interest and sets a new reserve factor for the protocol using _setReserveFactorFresh
   * @dev Admin function to accrue interest and set a new reserve factor
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _setReserveFactor(uint256 newReserveFactorMantissa) external override nonReentrant(false) returns (uint256) {
    uint256 error = asCTokenInterface().accrueInterest();
    if (error != uint256(Error.NO_ERROR)) {
      // accrueInterest emits logs on errors, but on top of that we want to log the fact that an attempted reserve factor change failed.
      return fail(Error(error), FailureInfo.SET_RESERVE_FACTOR_ACCRUE_INTEREST_FAILED);
    }
    // _setReserveFactorFresh emits reserve-factor-specific logs on errors, so we don't need to.
    return asCTokenInterface()._setReserveFactorFresh(newReserveFactorMantissa);
  }

  /**
   * @notice accrues interest and sets a new admin fee for the protocol using _setAdminFeeFresh
   * @dev Admin function to accrue interest and set a new admin fee
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _setAdminFee(uint256 newAdminFeeMantissa) external override nonReentrant(false) returns (uint256) {
    uint256 error = asCTokenInterface().accrueInterest();
    if (error != uint256(Error.NO_ERROR)) {
      // accrueInterest emits logs on errors, but on top of that we want to log the fact that an attempted admin fee change failed.
      return fail(Error(error), FailureInfo.SET_ADMIN_FEE_ACCRUE_INTEREST_FAILED);
    }
    // _setAdminFeeFresh emits reserve-factor-specific logs on errors, so we don't need to.
    return asCTokenInterface()._setAdminFeeFresh(newAdminFeeMantissa);
  }

  /**
   * @notice Accrues interest and reduces Fuse fees by transferring to Fuse
   * @param withdrawAmount Amount of fees to withdraw
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _withdrawFuseFees(uint256 withdrawAmount) external override nonReentrant(false) returns (uint256) {
    uint256 error = asCTokenInterface().accrueInterest();
    if (error != uint256(Error.NO_ERROR)) {
      // accrueInterest emits logs on errors, but on top of that we want to log the fact that an attempted Fuse fee withdrawal failed.
      return fail(Error(error), FailureInfo.WITHDRAW_FUSE_FEES_ACCRUE_INTEREST_FAILED);
    }
    // _withdrawFuseFeesFresh emits reserve-reduction-specific logs on errors, so we don't need to.
    return asCTokenInterface()._withdrawFuseFeesFresh(withdrawAmount);
  }

  /**
   * @notice Accrues interest and reduces admin fees by transferring to admin
   * @param withdrawAmount Amount of fees to withdraw
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _withdrawAdminFees(uint256 withdrawAmount) external override nonReentrant(false) returns (uint256) {
    uint256 error = asCTokenInterface().accrueInterest();
    if (error != uint256(Error.NO_ERROR)) {
      // accrueInterest emits logs on errors, but on top of that we want to log the fact that an attempted admin fee withdrawal failed.
      return fail(Error(error), FailureInfo.WITHDRAW_ADMIN_FEES_ACCRUE_INTEREST_FAILED);
    }
    // _withdrawAdminFeesFresh emits reserve-reduction-specific logs on errors, so we don't need to.
    return asCTokenInterface()._withdrawAdminFeesFresh(withdrawAmount);
  }

  /**
   * @notice accrues interest and updates the interest rate model using _setInterestRateModelFresh
   * @dev Admin function to accrue interest and update the interest rate model
   * @param newInterestRateModel the new interest rate model to use
   * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
   */
  function _setInterestRateModel(InterestRateModel newInterestRateModel) public override returns (uint256) {
    uint256 error = asCTokenInterface().accrueInterest();
    if (error != uint256(Error.NO_ERROR)) {
      // accrueInterest emits logs on errors, but on top of that we want to log the fact that an attempted change of interest rate model failed
      return fail(Error(error), FailureInfo.SET_INTEREST_RATE_MODEL_ACCRUE_INTEREST_FAILED);
    }
    // _setInterestRateModelFresh emits interest-rate-model-update-specific logs on errors, so we don't need to.
    return asCTokenInterface()._setInterestRateModelFresh(newInterestRateModel);
  }

  /**
   * @notice Returns a boolean indicating if the sender has admin rights
   */
  function hasAdminRights() internal view returns (bool) {
    ComptrollerV3Storage comptrollerStorage = ComptrollerV3Storage(address(comptroller));
    return
      (msg.sender == comptrollerStorage.admin() && comptrollerStorage.adminHasRights()) ||
      (msg.sender == address(fuseAdmin) && comptrollerStorage.fuseAdminHasRights());
  }

  /*** Reentrancy Guard ***/

  /**
   * @dev Prevents a contract from calling itself, directly or indirectly.
   */
  modifier nonReentrant(bool localOnly) {
    _beforeNonReentrant(localOnly);
    _;
    _afterNonReentrant(localOnly);
  }

  /**
   * @dev Split off from `nonReentrant` to keep contract below the 24 KB size limit.
   * Saves space because function modifier code is "inlined" into every function with the modifier).
   * In this specific case, the optimization saves around 1500 bytes of that valuable 24 KB limit.
   */
  function _beforeNonReentrant(bool localOnly) private {
    require(_notEntered, "re-entered");
    if (!localOnly) comptroller._beforeNonReentrant();
    _notEntered = false;
  }

  /**
   * @dev Split off from `nonReentrant` to keep contract below the 24 KB size limit.
   * Saves space because function modifier code is "inlined" into every function with the modifier).
   * In this specific case, the optimization saves around 150 bytes of that valuable 24 KB limit.
   */
  function _afterNonReentrant(bool localOnly) private {
    _notEntered = true; // get a gas-refund post-Istanbul
    if (!localOnly) comptroller._afterNonReentrant();
  }
}
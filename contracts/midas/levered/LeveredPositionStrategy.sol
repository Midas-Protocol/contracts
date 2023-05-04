// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { IComptroller, IPriceOracle } from "../../external/compound/IComptroller.sol";
import { IFundsConversionStrategy } from "../../liquidators/IFundsConversionStrategy.sol";
import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { ILeveredPositionFactory } from "./ILeveredPositionFactory.sol";
import { IFlashLoanReceiver } from "../IFlashLoanReceiver.sol";
import { CTokenExtensionInterface } from "../../compound/CTokenInterfaces.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

// TODO upgradeable?
contract LeveredPositionStrategy is IFlashLoanReceiver {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  address public positionOwner;
  ICErc20 public collateralMarket;
  ICErc20 public stableMarket;
  IComptroller public pool;

  IERC20Upgradeable public collateralAsset;
  IERC20Upgradeable public stableAsset;
  // @notice the base collateral is the collateral which is not backing any borrows
  uint256 public baseCollateral;
  ILeveredPositionFactory public factory;

  constructor(
    address _positionOwner,
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket
  ) {
    address collateralPool = _collateralMarket.comptroller();
    address stablePool = _stableMarket.comptroller();
    require(collateralPool == stablePool, "markets pools differ");
    pool = IComptroller(collateralPool);

    positionOwner = _positionOwner;
    collateralMarket = _collateralMarket;
    collateralAsset = IERC20Upgradeable(_collateralMarket.underlying());
    stableMarket = _stableMarket;
    stableAsset = IERC20Upgradeable(_stableMarket.underlying());

    baseCollateral = 0;
    factory = ILeveredPositionFactory(msg.sender);
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function fundPosition(IERC20Upgradeable fundingAsset, uint256 amount) public {
    fundingAsset.safeTransferFrom(msg.sender, address(this), amount);
    baseCollateral += _supplyCollateral(fundingAsset);

    // TODO if not entered yet
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(collateralMarket);
    pool.enterMarkets(cTokens);
  }

  // @notice this will make the position liquidatable
  function withdrawMax() public {
    withdrawMax(msg.sender);
  }

  // @notice this will make the position liquidatable
  function withdrawMax(address withdrawTo) public {
    withdraw(getMaxWithdrawable(), withdrawTo);
  }

  function withdraw(uint256 amount) public {
    withdraw(amount, msg.sender);
  }

  function withdraw(uint256 amount, address withdrawTo) public {
    require(msg.sender == positionOwner, "only owner");

    // it is assumed that all collateral is supplied to the market all the time
    require(collateralMarket.redeemUnderlying(amount) == 0, "redeem max failed");
    // therefore, withdrawing only what is redeemed
    collateralAsset.safeTransfer(withdrawTo, amount);

    uint256 borrowBalance = stableMarket.borrowBalanceCurrent(address(this));
    _updateBaseCollateral(borrowBalance);
  }

  function closePosition() public returns (uint256) {
    return closePosition(msg.sender);
  }

  function closePosition(address withdrawTo) public returns (uint256 withdrawAmount) {
    require(msg.sender == positionOwner, "only owner");

    _leverDown(type(uint256).max);

    uint256 maxRedeem = pool.getMaxRedeemOrBorrow(address(this), collateralMarket, false);
    require(collateralMarket.redeemUnderlying(maxRedeem) == 0, "redeem failed");

    //require(borrowBalance == 0);
    baseCollateral = collateralMarket.balanceOfUnderlyingHypo(address(this));

    // withdraw the redeemed collateral
    withdrawAmount = collateralAsset.balanceOf(address(this));
    collateralAsset.safeTransfer(withdrawTo, withdrawAmount);
  }

  function adjustLeverageRatio(uint256 targetRatioMantissa) public returns (uint256) {
    require(msg.sender == positionOwner, "only owner");

    uint256 currentRatio = getCurrentLeverageRatio();
    if (currentRatio < targetRatioMantissa) _leverUp(targetRatioMantissa);
    else _leverDown(targetRatioMantissa);

    // return the de facto achieved ratio
    return getCurrentLeverageRatio();
  }

  function receiveFlashLoan(
    address assetAddress,
    uint256 borrowedAmount,
    bytes calldata data
  ) external override {
    if (msg.sender == address(collateralMarket)) {
      // increasing the leverage ratio
      uint256 borrowAmount = abi.decode(data, (uint256));
      _leverUpPostFL(borrowAmount);
      require(collateralAsset.balanceOf(address(this)) >= borrowedAmount, "!cannot repay collateral FL");
    } else if (msg.sender == address(stableMarket)) {
      // decreasing the leverage ratio
      uint256 amountToRedeem = abi.decode(data, (uint256));
      _leverDownPostFL(borrowedAmount, amountToRedeem);
      require(stableAsset.balanceOf(address(this)) >= borrowedAmount, "!cannot repay stable FL");
    } else {
      revert("!fl not from either markets");
    }

    // repay FL
    IERC20Upgradeable(assetAddress).approve(msg.sender, borrowedAmount);
  }

  // TODO figure out if needed
  function withdrawStableLeftovers(address withdrawTo) public returns (uint256) {
    require(msg.sender == positionOwner, "only owner");
    require(baseCollateral == 0, "only when closed");

    uint256 stableLeftovers = stableAsset.balanceOf(address(this));
    stableAsset.safeTransfer(withdrawTo, stableLeftovers);
    return stableLeftovers;
  }

  /*----------------------------------------------------------------
                          View Functions
  ----------------------------------------------------------------*/

  function getCurrentLeverageRatio() public view returns (uint256) {
    if (baseCollateral == 0) return 0;

    uint256 suppliedCollateralCurrent = collateralMarket.balanceOfUnderlyingHypo(address(this));
    return (suppliedCollateralCurrent * 1e18) / baseCollateral;
  }

  function getMaxLeverageRatio() public view returns (uint256) {
    if (baseCollateral == 0) return 0;

    (, uint256 stableCollateralFactor) = pool.markets(address(stableMarket));
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);
    uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
    uint256 maxBorrowValueScaled = maxBorrow * stableAssetPrice;

    // not accounting for swaps slippage
    uint256 maxTopUpRepay = maxBorrowValueScaled / collateralAssetPrice;
    uint256 maxFlashLoaned = (maxTopUpRepay * 1e18) / (1e18 - stableCollateralFactor);

    uint256 suppliedCollateralCurrent = collateralMarket.balanceOfUnderlyingHypo(address(this));
    return ((suppliedCollateralCurrent + maxFlashLoaned) * 1e18) / baseCollateral;
  }

  function getMaxWithdrawable() public view returns (uint256) {
    return pool.getMaxRedeemOrBorrow(address(this), collateralMarket, false);
  }

  function isFundingAssetSupported(IERC20Upgradeable fundingAsset) public view returns (bool) {
    (IRedemptionStrategy redemptionStrategy,) = factory.getRedemptionStrategy(
      fundingAsset,
      collateralAsset
    );

    return (address(redemptionStrategy) != address(0));
  }

  /*----------------------------------------------------------------
                            Internal Functions
  ----------------------------------------------------------------*/

  function _supplyCollateral(IERC20Upgradeable fundingAsset) internal returns (uint256 amountToSupply) {
    // in case the funding is with a different asset
    if (address(collateralAsset) != address(fundingAsset)) {
      // swap for collateral asset
      convertAllTo(fundingAsset, collateralAsset);
    }

    // supply the collateral
    amountToSupply = collateralAsset.balanceOf(address(this));
    collateralAsset.approve(address(collateralMarket), amountToSupply);
    require(collateralMarket.mint(amountToSupply) == 0, "supply collateral failed");
  }

  function _leverUp(uint256 targetRatioMantissa) internal {
    (, uint256 stableCollateralFactor) = pool.markets(address(stableMarket));
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);

    // baseCollateral + overcollateralization + flashLoanAmount = totalCollateralSupplied
    // baseCollateral / totalCollateralSupplied = targetRatio
    // therefore => flashLoanAmount = (targetRatio - 1) * collateralFactor * baseCollateral
    // flash loan the flashLoanAmount, then borrow stable and swap for the amount needed to repay the FL
    //uint256 flashLoanCollateralAmount = ((((targetRatioMantissa - 1e18) * stableCollateralFactor) / 1e18) * baseCollateral) / 1e18;
    uint256 flashLoanCollateralAmount = (baseCollateral * stableCollateralFactor) / (targetRatioMantissa + 1e18);
    //(baseCollateral * targetRatioMantissa) / 1e18;
    uint256 flashLoanedCollateralValueScaled = flashLoanCollateralAmount * collateralAssetPrice;
    // not accounting for swaps slippage
    uint256 stableToBorrow = flashLoanedCollateralValueScaled / stableAssetPrice;

    {
      // 5% slippage
      stableToBorrow = (stableToBorrow * 105) / 100;
    }

    CTokenExtensionInterface(address(collateralMarket)).flash(flashLoanCollateralAmount, abi.encode(stableToBorrow));
    // the execution will first receive a callback to receiveFlashLoan()
    // then it continues from here
    uint256 borrowBalance = stableMarket.borrowBalanceCurrent(address(this));
    _updateBaseCollateral(borrowBalance);
  }

  function _leverUpPostFL(uint256 borrowAmount) internal {
    // supply the flashloaned collateral
    _supplyCollateral(collateralAsset);

    // borrow stables that will be swapped to repay the FL
    //uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
    require(stableMarket.borrow(borrowAmount) == 0, "borrow stable failed");

    // swap for the FL asset
    convertAllTo(stableAsset, collateralAsset);
  }

  function _leverDown(uint256 targetRatioMantissa) internal {
    // redeems the supplied collateral by first repaying the debt with which it was levered
    uint256 amountToRedeem;
    uint256 borrowsToRepay;

    // TODO reduce getUnderlyingPrice calls in _updateBaseCollateral
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);
    (, uint256 stableCollateralFactor) = pool.markets(address(stableMarket));

    uint256 borrowBalance = stableMarket.borrowBalanceCurrent(address(this));

    // if max levering down, then derive the amount to redeem from the debt to be repaid
    if (targetRatioMantissa < 1e18) {

      // TODO only deleveraging allowed

      borrowsToRepay = borrowBalance;
      uint256 borrowsToRepayValueScaled = borrowsToRepay * stableAssetPrice;
      // not accounting for swaps slippage
      amountToRedeem = ((borrowsToRepayValueScaled / collateralAssetPrice) * 1e18) / stableCollateralFactor;
    } else {
      // TODO
      uint256 ratioDiff = targetRatioMantissa;

      // else derive the debt to be repaid from the amount to redeem
      amountToRedeem = (baseCollateral * ratioDiff) / 1e18;
      uint256 amountToRedeemValueScaled = amountToRedeem * collateralAssetPrice;
      // not accounting for swaps slippage
      borrowsToRepay = ((amountToRedeemValueScaled / stableAssetPrice) * stableCollateralFactor) / 1e18;
    }

    CTokenExtensionInterface(address(stableMarket)).flash(borrowsToRepay, abi.encode(amountToRedeem));
    // the execution will first receive a callback to receiveFlashLoan()
    // then it continues from here
    _updateBaseCollateral(borrowBalance - borrowsToRepay);
  }

  function _leverDownPostFL(uint256 _flashLoanedCollateral, uint256 _amountToRedeem) internal {
    // repay the borrows
    uint256 borrowBalance = stableMarket.borrowBalanceCurrent(address(this));
    uint256 repayAmount = _flashLoanedCollateral < borrowBalance ? _flashLoanedCollateral : borrowBalance;
    stableAsset.approve(address(stableMarket), repayAmount);
    require(stableMarket.repayBorrow(repayAmount) == 0, "repay failed");

    borrowBalance -= repayAmount;

    // redeem the corresponding amount needed to repay the FL
    // TODO is maxRedeem needed here?
    //    uint256 maxRedeem = pool.getMaxRedeemOrBorrow(address(this), collateralMarket, false);
    //    _amountToRedeem = _amountToRedeem > maxRedeem ? maxRedeem : _amountToRedeem;
    require(collateralMarket.redeemUnderlying(_amountToRedeem) == 0, "redeem failed");

    // swap for the FL asset
    convertAllTo(collateralAsset, stableAsset);
  }

  function _updateBaseCollateral(uint256 borrowBalance) internal {
    uint256 suppliedCollateralCurrent = collateralMarket.balanceOfUnderlyingHypo(address(this));
    if (borrowBalance == 0) {
      baseCollateral = suppliedCollateralCurrent;
    } else {
      (, uint256 stableCollateralFactor) = pool.markets(address(stableMarket));
      IPriceOracle oracle = pool.oracle();
      uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
      uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);

      uint256 borrowsValueScaled = borrowBalance * stableAssetPrice;
      uint256 borrowsCollateralizationValueScaled = (borrowsValueScaled * 1e18) / stableCollateralFactor;
      uint256 totalCollateralValueScaled = suppliedCollateralCurrent * collateralAssetPrice;

      this.log("borrows value scaled", borrowsValueScaled);
      this.log("borrows collateralization value scaled", borrowsCollateralizationValueScaled);
      this.log("total collateral value scaled", totalCollateralValueScaled);
      // the base collateral is the collateral which is not backing any borrows
      baseCollateral = (totalCollateralValueScaled - borrowsCollateralizationValueScaled) / collateralAssetPrice;
    }
  }

  function log(string memory, uint256) public pure {}

  function convertTo(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IERC20Upgradeable outputToken
  ) private returns (uint256 outputAmount) {
    (IRedemptionStrategy redemptionStrategy, bytes memory strategyData) = factory.getRedemptionStrategy(
      inputToken,
      outputToken
    );
    (, outputAmount) = convertCustomFunds(inputToken, inputAmount, redemptionStrategy, strategyData);
  }

  function convertAllTo(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    private
    returns (uint256 outputAmount)
  {
    uint256 inputAmount = inputToken.balanceOf(address(this));
    return convertTo(inputToken, inputAmount, outputToken);
  }

  function convertCustomFunds(
    IERC20Upgradeable inputToken,
    uint256 inputAmount,
    IRedemptionStrategy strategy,
    bytes memory strategyData
  ) private returns (IERC20Upgradeable, uint256) {
    bytes memory returndata = _functionDelegateCall(
      address(strategy),
      abi.encodeWithSelector(strategy.redeem.selector, inputToken, inputAmount, strategyData)
    );
    return abi.decode(returndata, (IERC20Upgradeable, uint256));
  }

  function _functionDelegateCall(address target, bytes memory data) private returns (bytes memory) {
    require(AddressUpgradeable.isContract(target), "Address: delegate call to non-contract");
    (bool success, bytes memory returndata) = target.delegatecall(data);
    return _verifyCallResult(success, returndata, "Address: low-level delegate call failed");
  }

  function _verifyCallResult(
    bool success,
    bytes memory returndata,
    string memory errorMessage
  ) private pure returns (bytes memory) {
    if (success) {
      return returndata;
    } else {
      if (returndata.length > 0) {
        assembly {
          let returndata_size := mload(returndata)
          revert(add(32, returndata), returndata_size)
        }
      } else {
        revert(errorMessage);
      }
    }
  }
}

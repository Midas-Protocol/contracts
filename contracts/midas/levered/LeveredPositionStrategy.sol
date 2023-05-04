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

// TODO upgradeable
contract LeveredPositionStrategy is IFlashLoanReceiver {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  address public positionOwner;
  ICErc20 public collateralMarket;
  IERC20Upgradeable public collateralAsset;
  ICErc20 public stableMarket;
  IERC20Upgradeable public stableAsset;
  uint256 public totalBaseCollateral;
  ILeveredPositionFactory public factory;

  constructor(
    address _positionOwner,
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket
  ) {
    require(_collateralMarket.comptroller() == _stableMarket.comptroller(), "markets pools differ");

    positionOwner = _positionOwner;
    collateralMarket = _collateralMarket;
    collateralAsset = IERC20Upgradeable(_collateralMarket.underlying());
    stableMarket = _stableMarket;
    stableAsset = IERC20Upgradeable(_stableMarket.underlying());

    totalBaseCollateral = 0;
    factory = ILeveredPositionFactory(msg.sender);
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function fundPosition(IERC20Upgradeable fundingAsset, uint256 amount) public {
    fundingAsset.safeTransferFrom(msg.sender, address(this), amount);
    totalBaseCollateral += _depositCollateral(fundingAsset);

    // TODO if not entered yet
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(collateralMarket);
    IComptroller pool = IComptroller(collateralMarket.comptroller());
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

    require(collateralMarket.redeemUnderlying(amount) == 0, "redeem max failed");
    // withdraw
    collateralAsset.safeTransfer(withdrawTo, amount);

    uint256 borrowBalance = stableMarket.borrowBalanceStored(address(this));
    if (borrowBalance == 0) {
      if (totalBaseCollateral <= amount) totalBaseCollateral = 0;
      else totalBaseCollateral -= amount;
    }
  }

  function closePosition() public returns (uint256 withdrawAmount) {
    return closePosition(msg.sender);
  }

  function closePosition(address withdrawTo) public returns (uint256 withdrawAmount) {
    require(msg.sender == positionOwner, "only owner");

    _leverDown(type(uint256).max);

    IComptroller pool = IComptroller(collateralMarket.comptroller());
    uint256 maxRedeem = pool.getMaxRedeemOrBorrow(address(this), collateralMarket, false);
    require(collateralMarket.redeemUnderlying(maxRedeem) == 0, "redeem failed");

    // withdraw the redeemed collateral
    withdrawAmount = collateralAsset.balanceOf(address(this));
    collateralAsset.safeTransfer(withdrawTo, withdrawAmount);

    uint256 borrowBalance = stableMarket.borrowBalanceCurrent(address(this));
    if (borrowBalance == 0) {
      totalBaseCollateral = collateralMarket.balanceOfUnderlying(address(this));
    } else {
      if (totalBaseCollateral <= withdrawAmount) totalBaseCollateral = 0;
      else totalBaseCollateral -= withdrawAmount;
    }
  }

  function adjustLeverageRatio(uint256 targetRatioMantissa) public returns (uint256) {
    require(msg.sender == positionOwner, "only owner");

    uint256 currentRatio = getCurrentLeverageRatio();
    if (currentRatio < targetRatioMantissa) _leverUp(targetRatioMantissa - currentRatio);
    else _leverDown(currentRatio - targetRatioMantissa);

    // return the de factor achieved ratio
    return getCurrentLeverageRatio();
  }

  function _leverUp(uint256 ratioDiff) internal {
    // flash loan the newDepositsNeeded, then borrow stable and swap for the amount needed to repay the FL
    uint256 newDepositsNeeded = (totalBaseCollateral * ratioDiff) / 1e18;
    CTokenExtensionInterface(address(collateralMarket)).flash(newDepositsNeeded, "");
    // will receive first a callback to receiveFlashLoan()
    // then the execution continues from here
  }

  function _leverUpPostFL(uint256 _flashLoanedCollateral) internal {
    _depositCollateral(collateralAsset);

    IComptroller pool = IComptroller(stableMarket.comptroller());
    uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
    require(stableMarket.borrow(maxBorrow) == 0, "borrow stable failed");

    // swap for the FL asset
    convertAllTo(stableAsset, collateralAsset);
  }

  function _leverDown(uint256 ratioDiff) internal {
    uint256 amountToRedeem;
    uint256 borrowsToRepay;

    IComptroller pool = IComptroller(stableMarket.comptroller());
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);
    (, uint256 stableCF) = pool.markets(address(stableMarket)); // CF = collateral factor

    if (ratioDiff == type(uint256).max) {
      borrowsToRepay = stableMarket.borrowBalanceCurrent(address(this));
      uint256 borrowsToRepayValueScaled = borrowsToRepay * stableAssetPrice;
      // not accounting for swaps slippage
      amountToRedeem = ((borrowsToRepayValueScaled / collateralAssetPrice) * 1e18) / stableCF;
    } else {
      amountToRedeem = (totalBaseCollateral * ratioDiff) / 1e18;
      uint256 amountToRedeemValueScaled = amountToRedeem * collateralAssetPrice;
      // not accounting for swaps slippage
      borrowsToRepay = ((amountToRedeemValueScaled / stableAssetPrice) * stableCF) / 1e18;
    }

    CTokenExtensionInterface(address(stableMarket)).flash(borrowsToRepay, abi.encode(amountToRedeem));
    // will receive first a callback to receiveFlashLoan()
    // then the execution continues from here
  }

  function _leverDownPostFL(uint256 _flashLoanedCollateral, uint256 _amountToRedeem) internal {
    // repay the borrows
    uint256 borrowBalance = stableMarket.borrowBalanceCurrent(address(this));
    uint256 repayAmount = _flashLoanedCollateral < borrowBalance ? _flashLoanedCollateral : borrowBalance;
    stableAsset.approve(address(stableMarket), repayAmount);
    require(stableMarket.repayBorrow(repayAmount) == 0, "repay failed");

    // redeem the corresponding amount needed to repay the FL
    IComptroller pool = IComptroller(collateralMarket.comptroller());
    // TODO is maxRedeem needed here?
    uint256 maxRedeem = pool.getMaxRedeemOrBorrow(address(this), collateralMarket, false);
    _amountToRedeem = _amountToRedeem > maxRedeem ? maxRedeem : _amountToRedeem;
    require(collateralMarket.redeemUnderlying(_amountToRedeem) == 0, "redeem failed");

    // swap for the FL asset
    convertAllTo(collateralAsset, stableAsset);
  }

  function receiveFlashLoan(
    address assetAddress,
    uint256 borrowedAmount,
    bytes calldata data
  ) external override {
    if (msg.sender == address(collateralMarket)) {
      // increasing the leverage ratio
      _leverUpPostFL(borrowedAmount);
      require(collateralAsset.balanceOf(address(this)) >= borrowedAmount, "!cannot repay FL");
    } else if (msg.sender == address(stableMarket)) {
      // decreasing the leverage ratio
      uint256 amountToRedeem = abi.decode(data, (uint256));
      _leverDownPostFL(borrowedAmount, amountToRedeem);
      require(stableAsset.balanceOf(address(this)) >= borrowedAmount, "!cannot repay FL");
    } else {
      revert("!fl not from either markets");
    }

    // repay FL
    IERC20Upgradeable(assetAddress).approve(msg.sender, borrowedAmount);
  }

  // TODO figure out if needed
  function withdrawBorrowedAssets(address withdrawTo) public {
    require(msg.sender == positionOwner, "only owner");
    require(totalBaseCollateral == 0, "only when closed");

    uint256 stableLeftovers = stableAsset.balanceOf(address(this));
    stableAsset.approve(withdrawTo, stableLeftovers);
  }

  /*----------------------------------------------------------------
                          View Functions
  ----------------------------------------------------------------*/

  function getCurrentLeverageRatio() public view returns (uint256) {
    if (totalBaseCollateral == 0) return 0;
    else {
      uint256 totalDeposits = collateralMarket.balanceOfUnderlyingHypo(address(this));
      return (totalDeposits * 1e18) / totalBaseCollateral;
    }
  }

  function getMaxLeverageRatio() public view returns (uint256) {
    IComptroller pool = IComptroller(stableMarket.comptroller());
    (, uint256 stableCF) = pool.markets(address(stableMarket)); // CF = collateral factor
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);
    uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
    uint256 maxBorrowValueScaled = maxBorrow * stableAssetPrice;

    // not accounting for swaps slippage
    uint256 maxTopUpRepay = maxBorrowValueScaled / collateralAssetPrice;
    uint256 maxFlashLoaned = (maxTopUpRepay * 1e18) / (1e18 - stableCF);

    uint256 currentDeposits = collateralMarket.balanceOfUnderlyingHypo(address(this));
    return ((currentDeposits + maxFlashLoaned) * 1e18) / totalBaseCollateral;
  }

  function getMaxWithdrawable() public view returns (uint256) {
    IComptroller pool = IComptroller(collateralMarket.comptroller());
    return pool.getMaxRedeemOrBorrow(address(this), collateralMarket, false);
  }

  /*----------------------------------------------------------------
                            Internal Functions
  ----------------------------------------------------------------*/

  function _depositCollateral(IERC20Upgradeable fundingAsset) internal returns (uint256 amountToDeposit) {
    // in case the funding is with a different asset
    if (address(collateralAsset) != address(fundingAsset)) {
      // swap for collateral asset
      convertAllTo(fundingAsset, collateralAsset);
    }

    // deposit the collateral
    amountToDeposit = collateralAsset.balanceOf(address(this));
    collateralAsset.approve(address(collateralMarket), amountToDeposit);
    require(collateralMarket.mint(amountToDeposit) == 0, "deposit collateral failed");
  }

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

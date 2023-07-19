// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { IonicComptroller } from "../../compound/ComptrollerInterface.sol";
import { ICErc20 } from "../../compound/CTokenInterfaces.sol";
import { BasePriceOracle } from "../../oracles/BasePriceOracle.sol";
import { IFundsConversionStrategy } from "../../liquidators/IFundsConversionStrategy.sol";
import { IRedemptionStrategy } from "../../liquidators/IRedemptionStrategy.sol";
import { ILeveredPositionFactory } from "./ILeveredPositionFactory.sol";
import { IFlashLoanReceiver } from "../IFlashLoanReceiver.sol";
import { IonicFlywheel } from "../../ionic/strategies/flywheel/IonicFlywheel.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { LeveredPositionStorage } from "./LeveredPositionStorage.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LeveredPosition is LeveredPositionStorage, IFlashLoanReceiver {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  error OnlyWhenClosed();
  error NotPositionOwner();
  error RepayFlashLoanFailed(address asset, uint256 currentBalance, uint256 repayAmount);

  error ConvertFundsFailed();
  error ExitFailed(uint256 errorCode);
  error RedeemFailed(uint256 errorCode);
  error SupplyCollateralFailed(uint256 errorCode);
  error BorrowStableFailed(uint256 errorCode);
  error RepayBorrowFailed(uint256 errorCode);
  error RedeemCollateralFailed(uint256 errorCode);
  error ExtNotFound(bytes4 _functionSelector);

  constructor(
    address _positionOwner,
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket
  ) LeveredPositionStorage(_positionOwner) {
    IonicComptroller collateralPool = _collateralMarket.comptroller();
    IonicComptroller stablePool = _stableMarket.comptroller();
    require(collateralPool == stablePool, "markets pools differ");
    pool = collateralPool;

    collateralMarket = _collateralMarket;
    collateralAsset = IERC20Upgradeable(_collateralMarket.underlying());
    stableMarket = _stableMarket;
    stableAsset = IERC20Upgradeable(_stableMarket.underlying());

    factory = ILeveredPositionFactory(msg.sender);
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function fundPosition(IERC20Upgradeable fundingAsset, uint256 amount) public {
    fundingAsset.safeTransferFrom(msg.sender, address(this), amount);
    _supplyCollateral(fundingAsset);

    if (!pool.checkMembership(address(this), collateralMarket)) {
      address[] memory cTokens = new address[](1);
      cTokens[0] = address(collateralMarket);
      pool.enterMarkets(cTokens);
    }
  }

  function closePosition() public returns (uint256) {
    return closePosition(msg.sender);
  }

  function closePosition(address withdrawTo) public returns (uint256 withdrawAmount) {
    if (msg.sender != positionOwner && msg.sender != address(factory)) revert NotPositionOwner();

    _leverDown(type(uint256).max);

    // calling accrue and exit allows to redeem the full underlying balance
    collateralMarket.accrueInterest();
    uint256 errorCode = pool.exitMarket(address(collateralMarket));
    if (errorCode != 0) revert ExitFailed(errorCode);

    // redeem all cTokens should leave no dust
    errorCode = collateralMarket.redeem(collateralMarket.balanceOf(address(this)));
    if (errorCode != 0) revert RedeemFailed(errorCode);

    // withdraw the redeemed collateral
    withdrawAmount = collateralAsset.balanceOf(address(this));
    collateralAsset.safeTransfer(withdrawTo, withdrawAmount);
  }

  function adjustLeverageRatio(uint256 targetRatioMantissa) public returns (uint256) {
    if (msg.sender != positionOwner && msg.sender != address(factory)) revert NotPositionOwner();

    // anything under 1:1 means removing the leverage
    if (targetRatioMantissa < 1e18) _leverDown(type(uint256).max);

    uint256 currentRatio = getCurrentLeverageRatio();
    if (currentRatio < targetRatioMantissa) _leverUp(targetRatioMantissa - currentRatio);
    else _leverDown(currentRatio - targetRatioMantissa);

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
      uint256 positionCollateralBalance = collateralAsset.balanceOf(address(this));
      if (positionCollateralBalance < borrowedAmount)
        revert RepayFlashLoanFailed(address(collateralAsset), positionCollateralBalance, borrowedAmount);
    } else if (msg.sender == address(stableMarket)) {
      // decreasing the leverage ratio
      uint256 amountToRedeem = abi.decode(data, (uint256));
      _leverDownPostFL(borrowedAmount, amountToRedeem);
      uint256 positionStableBalance = stableAsset.balanceOf(address(this));
      if (positionStableBalance < borrowedAmount)
        revert RepayFlashLoanFailed(address(stableAsset), positionStableBalance, borrowedAmount);
    } else {
      revert("!fl not from either markets");
    }

    // repay FL
    IERC20Upgradeable(assetAddress).approve(msg.sender, borrowedAmount);
  }

  function withdrawStableLeftovers(address withdrawTo) public returns (uint256) {
    if (msg.sender != positionOwner) revert NotPositionOwner();
    if (getEquityAmount() > 0) revert OnlyWhenClosed();

    uint256 stableLeftovers = stableAsset.balanceOf(address(this));
    stableAsset.safeTransfer(withdrawTo, stableLeftovers);
    return stableLeftovers;
  }

  function claimRewards() public {
    claimRewards(msg.sender);
  }

  function claimRewards(address withdrawTo) public {
    if (msg.sender != positionOwner && msg.sender != address(factory)) revert NotPositionOwner();

    address[] memory flywheels = pool.getRewardsDistributors();

    for (uint256 i = 0; i < flywheels.length; i++) {
      IonicFlywheel fw = IonicFlywheel(flywheels[i]);
      fw.accrue(ERC20(address(collateralMarket)), address(this));
      fw.accrue(ERC20(address(stableMarket)), address(this));
      fw.claimRewards(address(this));
      ERC20 rewardToken = fw.rewardToken();
      uint256 rewardsAccrued = rewardToken.balanceOf(address(this));
      if (rewardsAccrued > 0) {
        rewardToken.transfer(withdrawTo, rewardsAccrued);
      }
    }
  }

  fallback() external {
    address extension = factory.getPositionsExtension(msg.sig);
    if (extension == address(0)) revert ExtNotFound(msg.sig);
    // Execute external function from extension using delegatecall and return any value.
    assembly {
      // copy function selector and any arguments
      calldatacopy(0, 0, calldatasize())
      // execute function call using the extension
      let result := delegatecall(gas(), extension, 0, calldatasize(), 0, 0)
      // get any return value
      returndatacopy(0, 0, returndatasize())
      // return any return value or error back to the caller
      switch result
      case 0 {
        revert(0, returndatasize())
      }
      default {
        return(0, returndatasize())
      }
    }
  }

  /*----------------------------------------------------------------
                          View Functions
  ----------------------------------------------------------------*/

  /// @notice this is a lens fn, it is not intended to be used on-chain
  function getAccruedRewards()
    external
    returns (
      /*view*/
      ERC20[] memory rewardTokens,
      uint256[] memory amounts
    )
  {
    address[] memory flywheels = pool.getRewardsDistributors();

    rewardTokens = new ERC20[](flywheels.length);
    amounts = new uint256[](flywheels.length);

    for (uint256 i = 0; i < flywheels.length; i++) {
      IonicFlywheel fw = IonicFlywheel(flywheels[i]);
      fw.accrue(ERC20(address(collateralMarket)), address(this));
      fw.accrue(ERC20(address(stableMarket)), address(this));
      rewardTokens[i] = fw.rewardToken();
      amounts[i] = fw.rewardsAccrued(address(this));
    }
  }

  function getCurrentLeverageRatio() public view returns (uint256) {
    uint256 equityAmount = getEquityAmount();
    if (equityAmount == 0) return 0;

    uint256 suppliedCollateralCurrent = collateralMarket.balanceOfUnderlying(address(this));
    return (suppliedCollateralCurrent * 1e18) / equityAmount;
  }

  function getMinLeverageRatio() public view returns (uint256) {
    uint256 equityAmount = getEquityAmount();
    if (equityAmount == 0) return 0;

    uint256 collateralAssetPrice = pool.oracle().getUnderlyingPrice(collateralMarket);

    return 1e18 + (factory.getMinBorrowNative() * 1e36) / (equityAmount * collateralAssetPrice);
  }

  function getMaxLeverageRatio() public view returns (uint256) {
    uint256 equityAmount = getEquityAmount();
    if (equityAmount == 0) return 0;

    (, uint256 stableCollateralFactor) = pool.markets(address(stableMarket));
    (, uint256 collatCollateralFactor) = pool.markets(address(collateralMarket));
    BasePriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);
    uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
    uint256 cash = stableMarket.getCash();
    if (maxBorrow > cash) maxBorrow = cash;
    uint256 maxBorrowValueScaled = maxBorrow * stableAssetPrice;

    // accounting for swaps slippage
    uint256 assumedSlippage = factory.liquidatorsRegistry().getSlippage(stableAsset, collateralAsset);
    uint256 maxTopUpCollateralSwapValueScaled = (maxBorrowValueScaled * (10000 - assumedSlippage)) / 10000;

    uint256 maxTopUpRepay = maxTopUpCollateralSwapValueScaled / collateralAssetPrice;
    uint256 maxCollateralToRepay = (maxTopUpRepay * stableCollateralFactor) / (1e18 - stableCollateralFactor);
    uint256 maxFlashLoaned = (maxCollateralToRepay * collatCollateralFactor) / 1e18;
    uint256 suppliedCollateralCurrent = collateralMarket.balanceOfUnderlying(address(this));
    return ((suppliedCollateralCurrent + maxFlashLoaned) * 1e18) / equityAmount;
  }

  function isPositionClosed() public view returns (bool) {
    return getEquityAmount() == 0;
  }

  function getEquityAmount() public view returns (uint256 equityAmount) {
    BasePriceOracle oracle = pool.oracle();
    uint256 borrowedAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);
    uint256 positionSupplyAmount = collateralMarket.balanceOfUnderlying(address(this));
    uint256 positionValue = (collateralAssetPrice * positionSupplyAmount) / 1e18;

    uint256 debtAmount = stableMarket.borrowBalanceCurrent(address(this));
    uint256 debtValue = (borrowedAssetPrice * debtAmount) / 1e18;

    uint256 equityValue = positionValue - debtValue;
    equityAmount = (equityValue * 1e18) / collateralAssetPrice;
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
    uint256 errorCode = collateralMarket.mint(amountToSupply);
    if (errorCode != 0) revert SupplyCollateralFailed(errorCode);
  }

  // @dev flash loan the needed amount, then borrow stables and swap them for the amount needed to repay the FL
  function _leverUp(uint256 ratioDiff) internal {
    BasePriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);

    uint256 flashLoanCollateralAmount = (getEquityAmount() * ratioDiff) / 1e18;
    uint256 flashLoanedCollateralValueScaled = flashLoanCollateralAmount * collateralAssetPrice;

    uint256 stableToBorrow = flashLoanedCollateralValueScaled / stableAssetPrice;
    // accounting for swaps slippage
    uint256 assumedSlippage = factory.liquidatorsRegistry().getSlippage(stableAsset, collateralAsset);
    stableToBorrow = (stableToBorrow * (10000 + assumedSlippage)) / 10000;

    ICErc20(address(collateralMarket)).flash(flashLoanCollateralAmount, abi.encode(stableToBorrow));
    // the execution will first receive a callback to receiveFlashLoan()
    // then it continues from here
  }

  // @dev supply the flash loaned collateral and then borrow stables with it
  function _leverUpPostFL(uint256 stableToBorrow) internal {
    // supply the flash loaned collateral
    _supplyCollateral(collateralAsset);

    // borrow stables that will be swapped to repay the FL
    uint256 errorCode = stableMarket.borrow(stableToBorrow);
    if (errorCode != 0) revert BorrowStableFailed(errorCode);

    // swap for the FL asset
    convertAllTo(stableAsset, collateralAsset);
  }

  // @dev redeems the supplied collateral by first repaying the debt with which it was levered
  function _leverDown(uint256 ratioDiff) internal {
    uint256 amountToRedeem;
    uint256 borrowsToRepay;

    (, uint256 stableCollateralFactor) = pool.markets(address(stableMarket));
    BasePriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);

    if (ratioDiff == type(uint256).max) {
      // if max levering down, then derive the amount to redeem from the debt to be repaid
      borrowsToRepay = stableMarket.borrowBalanceCurrent(address(this));
      uint256 borrowsToRepayValueScaled = borrowsToRepay * stableAssetPrice;
      // not accounting for swaps slippage
      amountToRedeem = ((borrowsToRepayValueScaled / collateralAssetPrice) * 1e18) / stableCollateralFactor;
    } else {
      // else derive the debt to be repaid from the amount to redeem
      amountToRedeem = (getEquityAmount() * ratioDiff) / 1e18;
      uint256 amountToRedeemValueScaled = amountToRedeem * collateralAssetPrice;
      // not accounting for swaps slippage
      borrowsToRepay = ((amountToRedeemValueScaled / stableAssetPrice) * stableCollateralFactor) / 1e18;
    }

    if (borrowsToRepay > 0) {
      ICErc20(address(stableMarket)).flash(borrowsToRepay, abi.encode(amountToRedeem));
      // the execution will first receive a callback to receiveFlashLoan()
      // then it continues from here
    }
  }

  function _leverDownPostFL(uint256 _flashLoanedCollateral, uint256 _amountToRedeem) internal {
    // repay the borrows
    uint256 borrowBalance = stableMarket.borrowBalanceCurrent(address(this));
    uint256 repayAmount = _flashLoanedCollateral < borrowBalance ? _flashLoanedCollateral : borrowBalance;
    stableAsset.approve(address(stableMarket), repayAmount);
    uint256 errorCode = stableMarket.repayBorrow(repayAmount);
    if (errorCode != 0) revert RepayBorrowFailed(errorCode);

    // redeem the corresponding amount needed to repay the FL
    errorCode = collateralMarket.redeemUnderlying(_amountToRedeem);
    if (errorCode != 0) revert RedeemCollateralFailed(errorCode);

    // swap for the FL asset
    convertAllTo(collateralAsset, stableAsset);
  }

  function convertAllTo(IERC20Upgradeable inputToken, IERC20Upgradeable outputToken)
    private
    returns (uint256 outputAmount)
  {
    uint256 inputAmount = inputToken.balanceOf(address(this));
    (IRedemptionStrategy[] memory redemptionStrategies, bytes[] memory strategiesData) = factory
      .getRedemptionStrategies(inputToken, outputToken);

    if (redemptionStrategies.length == 0) revert ConvertFundsFailed();

    for (uint256 i = 0; i < redemptionStrategies.length; i++) {
      IRedemptionStrategy redemptionStrategy = redemptionStrategies[i];
      bytes memory strategyData = strategiesData[i];
      (outputToken, outputAmount) = convertCustomFunds(inputToken, inputAmount, redemptionStrategy, strategyData);
      inputAmount = outputAmount;
      inputToken = outputToken;
    }
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

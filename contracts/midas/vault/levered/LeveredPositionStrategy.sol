// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.10;

import { ICErc20 } from "../../../external/compound/ICErc20.sol";
import { IComptroller, IPriceOracle } from "../../../external/compound/IComptroller.sol";
import { IFundsConversionStrategy } from "../../../liquidators/IFundsConversionStrategy.sol";
import { ILeveredPositionFactory } from "./ILeveredPositionFactory.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract LeveredPositionStrategy {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  address public positionOwner;
  ICErc20 public collateralMarket;
  ICErc20 public stableMarket;
  uint256 public totalBaseCollateral;
  ILeveredPositionFactory public factory;

  uint8 public constant MAX_LEVER_UP_ITERATIONS = 15;

  constructor(
    address _positionOwner,
    ICErc20 _collateralMarket,
    ICErc20 _stableMarket
  ) {
    require(_collateralMarket.comptroller() == _stableMarket.comptroller(), "markets pools differ");

    positionOwner = _positionOwner;
    collateralMarket = _collateralMarket;
    stableMarket = _stableMarket;
    totalBaseCollateral = 0;
    factory = ILeveredPositionFactory(msg.sender);
  }

  /*----------------------------------------------------------------
                          Mutable Functions
  ----------------------------------------------------------------*/

  function fundPosition(IERC20Upgradeable fundingAsset, uint256 amount) public {
    SafeERC20Upgradeable.safeTransferFrom(fundingAsset, msg.sender, address(this), amount);
    totalBaseCollateral += _depositCollateral(fundingAsset);

    // TODO if not entered yet
    address[] memory cTokens = new address[](1);
    cTokens[0] = address(collateralMarket);
    IComptroller pool = IComptroller(collateralMarket.comptroller());
    pool.enterMarkets(cTokens);
  }

  function adjustLeverageRatio(uint256 targetRatioMantissa) public {
    require(msg.sender == positionOwner, "only owner");

    uint256 currentRatio = getCurrentLeverageRatio();
    if (currentRatio < targetRatioMantissa) _leverUp(targetRatioMantissa - currentRatio);
    else _leverDown(currentRatio - targetRatioMantissa);
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
    (, uint256 collateralFactor) = pool.markets(address(stableMarket));
    IPriceOracle oracle = pool.oracle();
    uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
    uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);
    uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
    uint256 maxBorrowValueScaled = maxBorrow * stableAssetPrice;

    // not accounting for swaps slippage
    uint256 totalNewLeveredDeposits = 0;
    for (uint8 i = 0; i < MAX_LEVER_UP_ITERATIONS; i++) {
      totalNewLeveredDeposits += maxBorrowValueScaled / collateralAssetPrice;
      maxBorrowValueScaled = (maxBorrowValueScaled * collateralFactor) / 1e18;
    }

    uint256 currentDeposits = collateralMarket.balanceOfUnderlyingHypo(address(this));
    return ((currentDeposits + totalNewLeveredDeposits) * 1e18) / totalBaseCollateral;
  }

  /*----------------------------------------------------------------
                            Internal Functions
  ----------------------------------------------------------------*/

  function _leverUp(uint256 ratioDiff) internal {
    IERC20Upgradeable stableAsset = IERC20Upgradeable(stableMarket.underlying());
    (IFundsConversionStrategy fundingStrategy, bytes memory strategyData) = factory.getFundingStrategy(stableAsset);

    // estimate the borrow amount for each iteration
    uint256[] memory stableToBorrowAndSwap = new uint256[](MAX_LEVER_UP_ITERATIONS);
    {
      uint256 newDepositsNeeded = (totalBaseCollateral * ratioDiff) / 1e18;

      IComptroller pool = IComptroller(stableMarket.comptroller());
      (, uint256 collateralFactor) = pool.markets(address(stableMarket));
      IPriceOracle oracle = pool.oracle();
      uint256 stableAssetPrice = oracle.getUnderlyingPrice(stableMarket);
      uint256 collateralAssetPrice = oracle.getUnderlyingPrice(collateralMarket);
      uint256 maxBorrow = pool.getMaxRedeemOrBorrow(address(this), stableMarket, true);
      uint256 maxBorrowValueScaled = maxBorrow * stableAssetPrice;

      for (uint8 i = 0; i < MAX_LEVER_UP_ITERATIONS; i++) {
        (, uint256 stableInputRequired) = fundingStrategy.estimateInputAmount(newDepositsNeeded, strategyData);
        if (stableInputRequired > maxBorrow) {
          uint256 newLeveredDeposits = maxBorrowValueScaled / collateralAssetPrice;
          newDepositsNeeded -= newLeveredDeposits;
          stableToBorrowAndSwap[i] = maxBorrow;

          maxBorrowValueScaled = (maxBorrowValueScaled * collateralFactor) / 1e18;
          maxBorrow = maxBorrowValueScaled / stableAssetPrice;
        } else {
          uint256 stableInputRequiredValueScaled = stableInputRequired * stableAssetPrice;
          // not accounting for swaps slippage
          uint256 newLeveredDeposits = stableInputRequiredValueScaled / collateralAssetPrice;
          if (newLeveredDeposits > newDepositsNeeded) newDepositsNeeded = 0;
          else newDepositsNeeded -= newLeveredDeposits;
          stableToBorrowAndSwap[i] = stableInputRequired;
          break;
        }
      }

      require((newDepositsNeeded * 1e18) / totalBaseCollateral < 1e16, "not enough leverage for the target ratio");
    }

    // do the actual borrowing and levering up
    for (uint8 j = 0; j < MAX_LEVER_UP_ITERATIONS; j++) {
      if (stableToBorrowAndSwap[j] == 0) break;

      require(stableMarket.borrow(stableToBorrowAndSwap[j]) == 0, "borrow stable failed");
      convertCustomFunds(stableAsset, fundingStrategy, strategyData);
      _depositCollateral(IERC20Upgradeable(collateralMarket.underlying()));
    }
  }

  function _leverDown(uint256 ratioDiff) internal {
    // TODO unwind position
  }

  function _depositCollateral(IERC20Upgradeable fundingAsset) internal returns (uint256 amountToDeposit) {
    address collateralAssetAddress = collateralMarket.underlying();

    // in case the funding is with a different asset
    if (collateralAssetAddress != address(fundingAsset)) {
      // swap for collateral asset
      (IFundsConversionStrategy fundingStrategy, bytes memory strategyData) = factory.getFundingStrategy(fundingAsset);
      convertCustomFunds(fundingAsset, fundingStrategy, strategyData);
    }

    // deposit the collateral
    IERC20Upgradeable collateralAsset = IERC20Upgradeable(collateralAssetAddress);
    amountToDeposit = collateralAsset.balanceOf(address(this));
    collateralAsset.approve(address(collateralMarket), amountToDeposit);
    require(collateralMarket.mint(amountToDeposit) == 0, "deposit collateral failed");
  }

  function convertCustomFunds(
    IERC20Upgradeable inputToken,
    IFundsConversionStrategy strategy,
    bytes memory strategyData
  ) private returns (IERC20Upgradeable, uint256) {
    uint256 inputAmount = inputToken.balanceOf(address(this));
    bytes memory returndata = _functionDelegateCall(
      address(strategy),
      abi.encodeWithSelector(strategy.convert.selector, inputToken, inputAmount, strategyData)
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

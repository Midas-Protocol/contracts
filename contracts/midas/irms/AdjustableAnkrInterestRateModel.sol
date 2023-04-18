// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../../compound/InterestRateModel.sol";
import "../../compound/SafeMath.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Ajustable IRM For Ankr-based pools
 * @author Compound
 */

struct AdjustableAnkrInterestRateModelParams {
  uint256 blocksPerYear; // The approximate number of blocks per year
  uint256 multiplierPerYear; // The rate of increase in interest rate wrt utilization (scaled by 1e18)
  uint256 jumpMultiplierPerYear; // The multiplierPerBlock after hitting a specified utilization point
  uint256 kink; // The utilization point at which the jump multiplier is applied
}

abstract contract AdjustableAnkrInterestRateModel is Ownable, InterestRateModel {
  event NewInterestParams(uint256 multiplierPerBlock, uint256 jumpMultiplierPerBlock, uint256 kink);

  /**
   * @notice The approximate number of blocks per year that is assumed by the interest rate model
   */
  uint256 public blocksPerYear;

  /**
   * @notice The multiplier of utilization rate that gives the slope of the interest rate
   */
  uint256 public multiplierPerBlock;

  /**
   * @notice The multiplierPerBlock after hitting a specified utilization point
   */
  uint256 public jumpMultiplierPerBlock;

  /**
   * @notice The utilization point at which the jump multiplier is applied
   */
  uint256 public kink;

  /**
   * @notice Initialise an interest rate model
   */

  constructor(AdjustableAnkrInterestRateModelParams memory params) {
    blocksPerYear = params.blocksPerYear;
    multiplierPerBlock = params.multiplierPerYear / blocksPerYear;
    jumpMultiplierPerBlock = params.jumpMultiplierPerYear / blocksPerYear;
    kink = params.kink;
    emit NewInterestParams(multiplierPerBlock, jumpMultiplierPerBlock, kink);
  }

  /**
   * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
   * @param cash The amount of cash in the market
   * @param borrows The amount of borrows in the market
   * @param reserves The amount of reserves in the market (currently unused)
   * @return The utilization rate as a mantissa between [0, 1e18]
   */
  function utilizationRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves
  ) public pure returns (uint256) {
    // Utilization rate is 0 when there are no borrows
    if (borrows == 0) {
      return 0;
    }

    return (borrows * 1e18) / (cash + borrows - reserves);
  }

  function getAnkrRate() public view virtual returns (uint256);

  function getBaseRatePerBlock() public view returns (uint256) {
    return getAnkrRate();
  }

  function _setIrmParameters(AdjustableAnkrInterestRateModelParams memory params) public onlyOwner {
    blocksPerYear = params.blocksPerYear;
    multiplierPerBlock = params.multiplierPerYear / blocksPerYear;
    jumpMultiplierPerBlock = params.jumpMultiplierPerYear / blocksPerYear;
    kink = params.kink;
    emit NewInterestParams(multiplierPerBlock, jumpMultiplierPerBlock, kink);
  }

  /**
   * @notice Calculates the current borrow rate per block, with the error code expected by the market
   * @param cash The amount of cash in the market
   * @param borrows The amount of borrows in the market
   * @param reserves The amount of reserves in the market
   * @return The borrow rate percentage per block as a mantissa (scaled by 1e18)
   */
  function getBorrowRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves
  ) public view override returns (uint256) {
    uint256 util = utilizationRate(cash, borrows, reserves);
    uint256 baseRatePerBlock = getAnkrRate();

    if (util <= kink) {
      return (util * multiplierPerBlock) / 1e18 + baseRatePerBlock;
    } else {
      uint256 normalRate = (kink * multiplierPerBlock) / 1e18 + baseRatePerBlock;
      uint256 excessUtil = util - kink;
      return (excessUtil * jumpMultiplierPerBlock) / 1e18 + normalRate;
    }
  }

  /**
   * @notice Calculates the current supply rate per block
   * @param cash The amount of cash in the market
   * @param borrows The amount of borrows in the market
   * @param reserves The amount of reserves in the market
   * @param reserveFactorMantissa The current reserve factor for the market
   * @return The supply rate percentage per block as a mantissa (scaled by 1e18)
   */
  function getSupplyRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves,
    uint256 reserveFactorMantissa
  ) public view virtual override returns (uint256) {
    uint256 oneMinusReserveFactor = 1e18 - reserveFactorMantissa;
    uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
    uint256 rateToPool = (borrowRate * oneMinusReserveFactor) / 1e18;
    return (utilizationRate(cash, borrows, reserves) * rateToPool) / 1e18;
  }
}

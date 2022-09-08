// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { InterestRateModel } from "../../compound/InterestRateModel.sol";
import { SafeMath } from "../../compound/SafeMath.sol";

interface IAnkrBNBR {
  function averagePercentageRate(uint256 day) external view returns (uint256);
}

contract AnkrBNBInterestRateModel is InterestRateModel {
  using SafeMath for uint256;

  event NewInterestParams(uint256 blocksPerYear, uint256 baseRateMultiplier, uint256 kink);

  address public ANKR_BNB_R;

  /**
   * @notice The approximate number of blocks per year that is assumed by the interest rate model
   */
  uint256 public blocksPerYear;

  /**
   * @notice The base interest rate which is the y-intercept when utilization rate is 0
   */
  uint256 public baseRateMultiplier;

  /**
   * @notice The jumpMultiplierPerBlock after hitting a specified utilization point
   */
  uint256 public jumpMultiplierPerBlock;

  /**
   * @notice The utilization point at which the jump multiplier is applied
   */
  uint256 public kink;

  uint8 public day;

  /**
   * @notice Construct an interest rate model
   * @param _blocksPerYear The approximate number of blocks per year
   * @param _baseRateMultiplier The baseRateMultiplier after hitting a specified utilization point
   * @param kink_ The utilization point at which the jump multiplier is applied
   * @param _day The day period for average apr
   * @param _abnbr Address for Ankr BNB stacking rate
   */
  constructor(
    uint256 _blocksPerYear,
    uint256 _baseRateMultiplier,
    uint256 _jumpMultiplierPerYear,
    uint256 kink_,
    uint8 _day,
    address _abnbr
  ) {
    require(_day > 0 && _day < 8, "_day should be from 1 to 7");
    blocksPerYear = _blocksPerYear;
    baseRateMultiplier = _baseRateMultiplier;
    jumpMultiplierPerBlock = _jumpMultiplierPerYear.div(blocksPerYear);
    kink = kink_;
    day = _day;
    ANKR_BNB_R = _abnbr;

    emit NewInterestParams(blocksPerYear, baseRateMultiplier, kink);
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

    return borrows.mul(1e18).div(cash.add(borrows).sub(reserves));
  }

  function getAnkrRate() public view returns (uint256) {
    return IAnkrBNBR(ANKR_BNB_R).averagePercentageRate(day).div(100).div(blocksPerYear);
  }

  function getMultiplierPerBlock() public view returns (uint256) {
    return getAnkrRate().mul(1e18).div(kink);
  }

  function getBaseRatePerBlock() public view returns (uint256) {
    return getAnkrRate().mul(baseRateMultiplier).div(1e18);
  }

  function getBorrowRatePostKink(
    uint256 cash,
    uint256 borrows,
    uint256 reserves
  ) public view returns (uint256) {
    uint256 util = utilizationRate(cash, borrows, reserves);
    uint256 excessUtil = util.sub(kink);
    return excessUtil.mul(jumpMultiplierPerBlock).div(1e18);
  }

  function getBorrowRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves
  ) public view override returns (uint256) {
    uint256 util = utilizationRate(cash, borrows, reserves);
    uint256 baseRatePerBlock = getBaseRatePerBlock();
    uint256 multiplierPerBlock = getMultiplierPerBlock();
    uint256 normalRate = util.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);

    if (util <= kink) {
      return normalRate;
    } else {
      uint256 borrowRatePostKink = getBorrowRatePostKink(cash, borrows, reserves);
      return borrowRatePostKink.add(normalRate);
    }
  }

  function getSupplyRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves,
    uint256 reserveFactorMantissa
  ) public view override returns (uint256) {
    uint256 oneMinusReserveFactor = uint256(1e18).sub(reserveFactorMantissa);
    uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
    uint256 rateToPool = borrowRate.mul(oneMinusReserveFactor).div(1e18);
    return utilizationRate(cash, borrows, reserves).mul(rateToPool).div(1e18);
  }
}

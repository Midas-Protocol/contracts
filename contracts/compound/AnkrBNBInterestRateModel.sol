// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { InterestRateModel } from "./InterestRateModel.sol";
import { SafeMath } from "./SafeMath.sol";

interface IAnkrBNBR {
  function averagePercentageRate(uint256 day) external view returns (uint256);
}

contract AnkrBNBInterestRateModel is InterestRateModel {
  using SafeMath for uint256;

  event NewInterestParams(uint256 baseRatePerBlock, uint256 jumpMultiplierPerBlock, uint256 kink);

  address public ANKR_BNB_R;

  /**
   * @notice The approximate number of blocks per year that is assumed by the interest rate model
   */
  uint256 public blocksPerYear;

  /**
   * @notice The base interest rate which is the y-intercept when utilization rate is 0
   */
  uint256 public baseRatePerBlock;

  /**
   * @notice The multiplierPerBlock after hitting a specified utilization point
   */
  uint256 public jumpMultiplierPerBlock;

  /**
   * @notice The utilization point at which the jump multiplier is applied
   */
  uint256 public kink;

  /**
   * @notice Construct an interest rate model
   * @param _blocksPerYear The approximate number of blocks per year
   * @param baseRatePerYear The approximate target base APR, as a mantissa (scaled by 1e18)
   * @param jumpMultiplierPerYear The multiplierPerBlock after hitting a specified utilization point
   * @param kink_ The utilization point at which the jump multiplier is applied
   * @param _abnbr Address for Ankr BNB stacking rate
   */
  constructor(
    uint256 _blocksPerYear,
    uint256 baseRatePerYear,
    uint256 jumpMultiplierPerYear,
    uint256 kink_,
    address _abnbr
  ) {
    blocksPerYear = _blocksPerYear;
    baseRatePerBlock = baseRatePerYear.div(blocksPerYear);
    jumpMultiplierPerBlock = jumpMultiplierPerYear.div(blocksPerYear);
    kink = kink_;
    ANKR_BNB_R = _abnbr;

    emit NewInterestParams(baseRatePerBlock, jumpMultiplierPerBlock, kink);
  }

  function indexOfRatio(uint256 timestamp) internal pure returns (uint8 index) {
    uint256 epochPeriod = timestamp / 1 days;
    return uint8(epochPeriod % 8);
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

  function getBorrowRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves
  ) public view override returns (uint256) {
    uint256 util = utilizationRate(cash, borrows, reserves);
    uint8 day = indexOfRatio(block.timestamp);
    uint256 multiplierPerBlock = IAnkrBNBR(ANKR_BNB_R).averagePercentageRate(day);

    if (util <= kink) {
      return util.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
    } else {
      uint256 normalRate = kink.mul(multiplierPerBlock).div(1e18).add(baseRatePerBlock);
      uint256 excessUtil = util.sub(kink);
      return excessUtil.mul(jumpMultiplierPerBlock).div(1e18).add(normalRate);
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

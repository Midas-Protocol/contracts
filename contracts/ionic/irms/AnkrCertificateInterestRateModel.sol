// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { InterestRateModel } from "../../compound/InterestRateModel.sol";

abstract contract AnkrCertificateInterestRateModel is InterestRateModel {
  event NewInterestParams(uint256 blocksPerYear, uint256 baseRateMultiplier, uint256 kink);

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

  address public ANKR_RATE_PROVIDER;

  /**
   * @notice Construct an interest rate model
   * @param _blocksPerYear The approximate number of blocks per year
   * @param _baseRateMultiplier The baseRateMultiplier after hitting a specified utilization point
   * @param kink_ The utilization point at which the jump multiplier is applied
   * @param _day The day period for average apr
   * @param _rate_provider Address for Ankr Rate Provider for staking rate
  
   */
  constructor(
    uint256 _blocksPerYear,
    uint256 _baseRateMultiplier,
    uint256 _jumpMultiplierPerYear,
    uint256 kink_,
    uint8 _day,
    address _rate_provider
  ) {
    require(_day > 0 && _day < 8, "_day should be from 1 to 7");
    blocksPerYear = _blocksPerYear;
    baseRateMultiplier = _baseRateMultiplier;
    jumpMultiplierPerBlock = _jumpMultiplierPerYear / blocksPerYear;
    kink = kink_;
    day = _day;
    ANKR_RATE_PROVIDER = _rate_provider;

    emit NewInterestParams(blocksPerYear, baseRateMultiplier, kink);
  }

  /**
   * @notice Calculates the utilization rate of the market: `borrows / (cash + borrows - reserves)`
   * @param cash The amount of cash in the market
   * @param borrows The amount of borrows in the market
   * @param reserves The amount of reserves in the market (currently unused)
   * @return The utilization rate as a mantissa between [0, 1e18]
   */
  function utilizationRate(uint256 cash, uint256 borrows, uint256 reserves) public pure returns (uint256) {
    // Utilization rate is 0 when there are no borrows
    if (borrows == 0) {
      return 0;
    }

    return (borrows * 1e18) / (cash + borrows - reserves);
  }

  function getAnkrRate() public view virtual returns (uint256);

  function getMultiplierPerBlock() public view returns (uint256) {
    return (getAnkrRate() * 1e18) / kink;
  }

  function getBaseRatePerBlock() public view returns (uint256) {
    return (getAnkrRate() * baseRateMultiplier) / 1e18;
  }

  function getBorrowRatePostKink(uint256 cash, uint256 borrows, uint256 reserves) public view returns (uint256) {
    uint256 util = utilizationRate(cash, borrows, reserves);
    uint256 excessUtil = util - kink;
    return (excessUtil * jumpMultiplierPerBlock) / 1e18;
  }

  function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) public view override returns (uint256) {
    uint256 util = utilizationRate(cash, borrows, reserves);
    uint256 baseRatePerBlock = getBaseRatePerBlock();
    uint256 multiplierPerBlock = getMultiplierPerBlock();
    uint256 normalRate = ((util * multiplierPerBlock) / 1e18) + baseRatePerBlock;

    if (util <= kink) {
      return normalRate;
    } else {
      uint256 borrowRatePostKink = getBorrowRatePostKink(cash, borrows, reserves);
      return borrowRatePostKink + normalRate;
    }
  }

  function getSupplyRate(
    uint256 cash,
    uint256 borrows,
    uint256 reserves,
    uint256 reserveFactorMantissa
  ) public view override returns (uint256) {
    uint256 oneMinusReserveFactor = uint256(1e18) - reserveFactorMantissa;
    uint256 borrowRate = getBorrowRate(cash, borrows, reserves);
    uint256 rateToPool = (borrowRate * oneMinusReserveFactor) / 1e18;
    return (utilizationRate(cash, borrows, reserves) * rateToPool) / (1e18);
  }
}

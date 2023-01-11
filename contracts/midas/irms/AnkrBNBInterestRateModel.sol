// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { InterestRateModel } from "../../compound/InterestRateModel.sol";
import { AnkrCertificateInterestRateModel } from "./AnkrCertificateInterestRateModel.sol";
import { SafeMath } from "../../compound/SafeMath.sol";

interface IAnkrRateProvider {
  function averagePercentageRate(address addr, uint256 day) external view returns (int256);
}

contract AnkrBNBInterestRateModel is AnkrCertificateInterestRateModel {
  using SafeMath for uint256;

  address public ANKR_RATE_PROVIDER;
  address public ANKR_BOND;

  /**
   * @notice Construct an interest rate model
   * @param _blocksPerYear The approximate number of blocks per year
   * @param _baseRateMultiplier The baseRateMultiplier after hitting a specified utilization point
   * @param kink_ The utilization point at which the jump multiplier is applied
   * @param _day The day period for average apr
   * @param _rate_provider Address for Ankr Rate Provider for staking rate
   * @param _abond Address for Ankr BNB bond address
   */
  constructor(
    uint256 _blocksPerYear,
    uint256 _baseRateMultiplier,
    uint256 _jumpMultiplierPerYear,
    uint256 kink_,
    uint8 _day,
    address _rate_provider, // 0xCb0006B31e6b403fEeEC257A8ABeE0817bEd7eBa
    address _abond // 0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827
  ) {
    require(_day > 0 && _day < 8, "_day should be from 1 to 7");
    blocksPerYear = _blocksPerYear;
    baseRateMultiplier = _baseRateMultiplier;
    jumpMultiplierPerBlock = _jumpMultiplierPerYear.div(blocksPerYear);
    kink = kink_;
    day = _day;
    ANKR_RATE_PROVIDER = _rate_provider;
    ANKR_BOND = _abond;

    emit NewInterestParams(blocksPerYear, baseRateMultiplier, kink);
  }

  function getAnkrRate() public view override returns (uint256) {
    return
      uint256(IAnkrRateProvider(ANKR_RATE_PROVIDER).averagePercentageRate(ANKR_BOND, day)).div(100).div(blocksPerYear);
  }
}

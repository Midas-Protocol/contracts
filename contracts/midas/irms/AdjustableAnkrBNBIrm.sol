// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { AdjustableAnkrInterestRateModel, AdjustableAnkrInterestRateModelParams } from "./AdjustableAnkrInterestRateModel.sol";

import "@openzeppelin/contracts/access/Ownable.sol";

struct AnkrRateProviderParams {
  uint8 day; // The day period for average apr
  address rate_provider; // Address for Ankr Rate Provider for staking rate
  address abond; // Address for Ankr BNB bond address
}

interface IAnkrRateProvider {
  function averagePercentageRate(address addr, uint256 day) external view returns (int256);
}

contract AdjustableAnkrBNBIrm is AdjustableAnkrInterestRateModel {
  AnkrRateProviderParams public ankrRateProviderParams;

  constructor(
    AdjustableAnkrInterestRateModelParams memory _adjustableAnkrInterestRateModelParams,
    AnkrRateProviderParams memory _ankrRateProviderParams
  ) AdjustableAnkrInterestRateModel(_adjustableAnkrInterestRateModelParams) {
    ankrRateProviderParams = _ankrRateProviderParams;
  }

  function getAnkrRate() public view override returns (uint256) {
    return
      (uint256(
        IAnkrRateProvider(ankrRateProviderParams.rate_provider).averagePercentageRate(
          ankrRateProviderParams.abond,
          ankrRateProviderParams.day
        )
      ) / 100) / (blocksPerYear);
  }

  function setAnkrRateProviderParams(AnkrRateProviderParams memory _ankrRateProviderParams) public onlyOwner {
    ankrRateProviderParams = _ankrRateProviderParams;
  }
}

// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

/// @title Pool state that can change
/// @dev Credit to Uniswap Labs under GPL-2.0-or-later license:
/// https://github.com/Uniswap/v3-core/tree/main/contracts/interfaces
interface IAlgebraPool {
  /**
   * @notice Returns the cumulative tick and liquidity as of each timestamp `secondsAgo` from the current block timestamp
   * @dev To get a time weighted average tick or liquidity-in-range, you must call this with two values, one representing
   * the beginning of the period and another for the end of the period. E.g., to get the last hour time-weighted average tick,
   * you must call it with secondsAgos = [3600, 0].
   * @dev The time weighted average tick represents the geometric time weighted average price of the pool, in
   * log base sqrt(1.0001) of token1 / token0. The TickMath library can be used to go from a tick value to a ratio.
   * @param secondsAgos From how long ago each cumulative tick and liquidity value should be returned
   * @return tickCumulatives Cumulative tick values as of each `secondsAgos` from the current block timestamp
   * @return secondsPerLiquidityCumulatives Cumulative seconds per liquidity-in-range value as of each `secondsAgos`
   * from the current block timestamp
   * @return volatilityCumulatives Cumulative standard deviation as of each `secondsAgos`
   * @return volumePerAvgLiquiditys Cumulative swap volume per liquidity as of each `secondsAgos`
   */
  function getTimepoints(uint32[] calldata secondsAgos)
    external
    view
    returns (
      int56[] memory tickCumulatives,
      uint160[] memory secondsPerLiquidityCumulatives,
      uint112[] memory volatilityCumulatives,
      uint256[] memory volumePerAvgLiquiditys
    );

  function factory() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function tickSpacing() external view returns (int24);

  function dataStorageOperator() external view returns (IDataStorageOperator);

  function globalState() external view returns (GlobalState memory);
}

struct Timepoint {
  bool initialized; // whether or not the timepoint is initialized
  uint32 blockTimestamp; // the block timestamp of the timepoint
  int56 tickCumulative; // the tick accumulator, i.e. tick * time elapsed since the pool was first initialized
  uint160 secondsPerLiquidityCumulative; // the seconds per liquidity since the pool was first initialized
  uint88 volatilityCumulative; // the volatility accumulator; overflow after ~34800 years is desired :)
  int24 averageTick; // average tick at this blockTimestamp
  uint144 volumePerLiquidityCumulative; // the gmean(volumes)/liquidity accumulator
}

struct GlobalState {
  uint160 price; // The square root of the current price in Q64.96 format
  int24 tick; // The current tick
  uint16 fee; // The current fee in hundredths of a bip, i.e. 1e-6
  uint16 timepointIndex; // The index of the last written timepoint
  uint8 communityFeeToken0; // The community fee represented as a percent of all collected fee in thousandths (1e-3)
  uint8 communityFeeToken1;
  bool unlocked; // True if the contract is unlocked, otherwise - false
}

interface IDataStorageOperator {
  function timepoints(uint256 index) external view returns (Timepoint memory);
}

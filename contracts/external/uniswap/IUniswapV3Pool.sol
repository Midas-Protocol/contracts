interface IUniswapV3Pool {
  function slot0()
    external
    view
    returns (
      uint160 sqrtPriceX96,
      int24 tick,
      uint16 observationIndex,
      uint16 observationCardinality,
      uint16 observationCardinalityNext,
      uint8 feeProtocol,
      bool unlocked
    );

  function liquidity() external view returns (uint128);

  function observe(uint32[] calldata secondsAgos)
    external
    view
    returns (int56[] memory tickCumulatives, uint160[] memory liquidityCumulatives);

  function observations(uint256 index)
    external
    view
    returns (
      uint32 blockTimestamp,
      int56 tickCumulative,
      uint160 liquidityCumulative,
      bool initialized
    );

  function increaseObservationCardinalityNext(uint16 observationCardinalityNext) external;
}

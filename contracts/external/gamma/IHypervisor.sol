// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.0;

interface IHypervisor {
  function baseLower() external view returns (int24);

  function baseUpper() external view returns (int24);

  function limitLower() external view returns (int24);

  function limitUpper() external view returns (int24);

  function pool() external view returns (address);

  function token0() external view returns (address);

  function token1() external view returns (address);

  function balanceOf(address) external view returns (uint256);

  function approve(address, uint256) external returns (bool);

  function getBasePosition()
    external
    view
    returns (
      uint256 liquidity,
      uint256 total0,
      uint256 total1
    );

  function totalSupply() external view returns (uint256);

  function getTotalAmounts() external view returns (uint256 total0, uint256 total1);

  function setWhitelist(address _address) external;

  function setFee(uint8 newFee) external;

  function removeWhitelisted() external;

  function transferOwnership(address newOwner) external;
}

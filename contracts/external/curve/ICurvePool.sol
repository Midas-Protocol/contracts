// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

interface ICurvePool is IERC20Upgradeable {
  function get_virtual_price() external view returns (uint256);

  function remove_liquidity_one_coin(
    uint256 _token_amount,
    int128 i,
    uint256 min_amount
  ) external;

  // exploitable
  function remove_liquidity_one_coin(
    uint256 _token_amount,
    int128 i,
    uint256 min_amount,
    bool useEth
  ) external;

  function exchange(
    int128 i,
    int128 j,
    uint256 dx,
    uint256 min_dy
  ) external returns (uint256);

  function get_dy(
    int128 i,
    int128 j,
    uint256 _dx
  ) external view returns (uint256);

  function coins(uint256 index) external view returns (address);

  // exploitable
  function add_liquidity(uint256[2] calldata amounts, uint256 minMintAmount, bool useEth) external payable returns (uint256);

  // exploitable
  function remove_liquidity(uint256 lpTokens, uint256[] calldata amounts, bool useEth) external returns (uint256);
}

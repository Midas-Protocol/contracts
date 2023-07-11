// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./ionic/SafeOwnableUpgradeable.sol";

contract JarvisSafeLiquidator is SafeOwnableUpgradeable {
  // just in case
  uint256[99] private __gap;

  mapping(address => uint256) public marketCTokensTotalSupply;
  mapping(address => uint256) public valueOwedToMarket;
  mapping(address => uint256) public usdcRedeemed;
  uint256 public totalUsdcSeized;
  uint256 public totalValueOwedToMarkets;
}

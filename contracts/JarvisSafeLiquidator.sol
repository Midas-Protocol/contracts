// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./midas/SafeOwnableUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/utils/AddressUpgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./liquidators/IRedemptionStrategy.sol";
import "./liquidators/IFundsConversionStrategy.sol";
import "./liquidators/JarvisLiquidatorFunder.sol";
import "./liquidators/UniswapV2Liquidator.sol";
import "./liquidators/UniswapLpTokenLiquidator.sol";
import "./liquidators/CurveLpTokenLiquidatorNoRegistry.sol";

import "./midas/AddressesProvider.sol";

import "./external/compound/ICToken.sol";
import "./external/compound/IComptroller.sol";

import "./external/compound/ICErc20.sol";
import "./external/compound/ICEther.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

contract JarvisSafeLiquidator is SafeOwnableUpgradeable {
  using AddressUpgradeable for address payable;
  using SafeERC20Upgradeable for IERC20Upgradeable;

  // just in case
  uint256[99] private __gap;

  mapping(address => uint256) public marketCTokensTotalSupply;
  mapping(address => uint256) public valueOwedToMarket;
  mapping(address => uint256) public usdcRedeemed;
  uint256 public totalUsdcSeized;
  uint256 public totalValueOwedToMarkets;
}

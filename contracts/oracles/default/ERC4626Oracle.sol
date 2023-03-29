// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { IERC4626 } from "../../compound/IERC4626.sol";
import { IPriceOracle } from "../../external/compound/IPriceOracle.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { BasePriceOracle } from "../BasePriceOracle.sol";
import { SafeOwnableUpgradeable } from "../../midas/SafeOwnableUpgradeable.sol";

contract ERC4626Oracle is SafeOwnableUpgradeable, BasePriceOracle {
  function initialize() public initializer {
    __SafeOwnable_init();
  }

  function price(address underlying) external view override returns (uint256) {
    return _price(underlying);
  }

  /**
   * @notice Returns the price in ETH of the token underlying `cToken`.
   * @dev Implements the `PriceOracle` interface for Fuse pools (and Compound v2).
   * @return Price in ETH of the token underlying `cToken`, scaled by `10 ** (36 - underlyingDecimals)`.
   */
  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    address underlying = ICErc20(address(cToken)).underlying();
    // Comptroller needs prices to be scaled by 1e(36 - decimals)
    // Since `_price` returns prices scaled by 18 decimals, we must scale them by 1e(36 - 18 - decimals)
    return (_price(underlying) * 1e18) / (10**uint256(ERC20Upgradeable(underlying).decimals()));
  }

  /**
   * @dev Fetches the fair LP token/ETH price from Balancer, with 18 decimals of precision.
   * Source: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/BalancerPairOracle.sol
   */
  function _price(address underlying) internal view virtual returns (uint256) {
    IERC4626 vault = IERC4626(underlying);
    address asset = vault.asset();
    uint256 redeemAmount = vault.previewRedeem(10**vault.decimals());
    uint256 underlyingPrice = BasePriceOracle(msg.sender).price(asset);
    return (redeemAmount * underlyingPrice) / 10**ERC20Upgradeable(asset).decimals();
  }
}

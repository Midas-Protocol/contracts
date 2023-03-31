// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../../external/compound/IPriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";

import { IBalancerStablePool } from "../../external/balancer/IBalancerStablePool.sol";
import { IBalancerVault } from "../../external/balancer/IBalancerVault.sol";
import { SafeOwnableUpgradeable } from "../../midas/SafeOwnableUpgradeable.sol";
import { BasePriceOracle } from "../BasePriceOracle.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";

/**
 * @title BalancerLpStablePoolPriceOracle
 * @author Carlo Mazzaferro <carlo@midascapital.xyz> (https://github.com/carlomazzaferro)
 * @notice BalancerLpStablePoolPriceOracle is a price oracle for Balancer LP tokens.
 * @dev Implements the `PriceOracle` interface used by Midas pools (and Compound v2).
 */

contract BalancerLpStablePoolPriceOracle is SafeOwnableUpgradeable, BasePriceOracle {
  address[] public underlyings;
  bytes32 internal constant REENTRANCY_ERROR_HASH = keccak256(abi.encodeWithSignature("Error(string)", "BAL#400"));

  function initialize(address[] memory _underlyings) public initializer {
    __SafeOwnable_init(msg.sender);
    underlyings = _underlyings;
  }

  /**
   * @notice Get the LP token price price for an underlying token address.
   * @param underlying The underlying token address for which to get the price (set to zero address for ETH).
   * @return Price denominated in ETH (scaled by 1e18).
   */

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
    IBalancerStablePool pool = IBalancerStablePool(underlying);
    IBalancerVault vault = pool.getVault();
    uint256 rate = pool.getRate();

    // read-only re-entracy protection - this call is always unsuccessful
    (, bytes memory revertData) = address(vault).staticcall(
      abi.encodeWithSelector(vault.manageUserBalance.selector, new address[](0))
    );
    require(keccak256(revertData) != REENTRANCY_ERROR_HASH, "Balancer vault view reentrancy");

    uint256 poolActualSupply = pool.getActualSupply();
    (IERC20Upgradeable[] memory tokens, uint256[] memory balances, ) = vault.getPoolTokens(pool.getPoolId());

    uint256 weightedBaseTokenValue = 0;

    for (uint256 i = 0; i < tokens.length; i++) {
      // exclude the LP token itself
      if (tokens[i] == IERC20Upgradeable(underlying)) {
        continue;
      }

      // scale by the decimals of the base token
      uint256 balancesScaled = balances[i] * 10**(18 - uint256(ERC20Upgradeable(address(tokens[i])).decimals()));

      // get the share of the base token in the pool (inverse to prevent underflow)
      // e18 + e18 - e18
      uint256 baseTokenShare = (poolActualSupply * 1e18) / balancesScaled;

      // Get the price of the base token in ETH
      uint256 baseTokenPrice = BasePriceOracle(msg.sender).price(address(tokens[i]));

      // Get the value of each of the base tokens' share in ETH
      // e18 + e18 - e18
      weightedBaseTokenValue += ((baseTokenPrice * 1e18) / baseTokenShare);
    }
    // Multiply the value of each of the base tokens' share in ETH by the rate of the pool
    return (rate * weightedBaseTokenValue) / 1e18;
  }

  /**
   * @dev Register the an underlying.
   * @param _underlying Underlying token for which to add an oracle.
   */
  function registerToken(address _underlying) external onlyOwner {
    bool skip = false;
    for (uint256 j = 0; j < underlyings.length; j++) {
      if (underlyings[j] == _underlying) {
        skip = true;
        break;
      }
    }
    if (!skip) {
      underlyings.push(_underlying);
    }
  }

  function getAllUnderlyings() external view returns (address[] memory) {
    return underlyings;
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import "../../external/compound/IPriceOracle.sol";
import "../../external/compound/ICToken.sol";
import "../../external/compound/ICErc20.sol";

import { IBalancerStablePool } from "../../external/balancer/IBalancerStablePool.sol";
import { IBalancerVault, UserBalanceOp } from "../../external/balancer/IBalancerVault.sol";
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
  mapping(address => address) public baseTokens;

  address[] public lpTokens;

  /**
   * @dev Initializes an array of LP tokens and pools if desired.
   * @param _lpTokens Array of LP token addresses.
   * @param _baseTokens Array of base token addresses.
   */
  function initialize(address[] memory _lpTokens, address[] memory _baseTokens) public initializer {
    require(_lpTokens.length == _baseTokens.length, "No LP tokens supplied or array lengths not equal.");
    __SafeOwnable_init();

    for (uint256 i = 0; i < _baseTokens.length; i++) {
      baseTokens[_lpTokens[i]] = _baseTokens[i];
    }
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

  function ensureNotInVaultContext(IBalancerVault vault) external {
    UserBalanceOp[] memory noop = new UserBalanceOp[](0);
    vault.manageUserBalance(noop);
  }

  /**
   * @dev Fetches the fair LP token/ETH price from Balancer, with 18 decimals of precision.
   * Source: https://github.com/AlphaFinanceLab/homora-v2/blob/master/contracts/oracle/BalancerPairOracle.sol
   */
  function _price(address underlying) internal view virtual returns (uint256) {
    IBalancerStablePool pool = IBalancerStablePool(underlying);

    // read-only re-entracy protection - this call is always unsuccessful
    (, bytes memory result) = address(this).staticcall(
      abi.encodeWithSelector(this.ensureNotInVaultContext.selector, pool.getVault())
    );

    bytes32 reentrancyErrorHash = keccak256(
      hex"08c379a00000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000742414c2334303000000000000000000000000000000000000000000000000000"
    );
    if (reentrancyErrorHash == keccak256(result)) {
      return 0;
    }
    // Returns the BLP Token / Base Token rate
    uint256 rate = pool.getRate();
    uint256 baseTokenPrice = BasePriceOracle(msg.sender).price(baseTokens[underlying]);
    return (rate * baseTokenPrice) / 1e18;
  }
}

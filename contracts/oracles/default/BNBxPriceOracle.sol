// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { IStakeManager } from "../../external/stader/IStakeManager.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

import "../../midas/SafeOwnableUpgradeable.sol";
import "../BasePriceOracle.sol";

/**
 * @title BNBxPriceOracle
 * @author Carlo Mazzaferro <carlo@midascapital.xyz> (https://github.com/carlomazzaferro)
 * @notice BNBxPriceOracle is a price oracle for BNBx liquid staked tokens.
 * @dev Implements the `PriceOracle` interface used by Midas pools (and Compound v2).
 */

contract BNBxPriceOracle is SafeOwnableUpgradeable, BasePriceOracle {
  IStakeManager public stakeManager;
  address public BNBx;

  function initialize() public initializer {
    __SafeOwnable_init();
    stakeManager = IStakeManager(0x7276241a669489E4BBB76f63d2A43Bfe63080F2F);
    (, address _bnbX, , ) = stakeManager.getContracts();
    BNBx = _bnbX;
  }

  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();
    require(underlying == BNBx, "Invalid underlying");
    // no need to scale as BNBx has 18 decimals
    return _price();
  }

  function price(address underlying) external view override returns (uint256) {
    require(underlying == BNBx, "Invalid underlying");
    return _price();
  }

  function _price() internal view returns (uint256) {
    uint256 oneBNB = 1e18;
    uint256 exchangeRate = stakeManager.convertBnbXToBnb(oneBNB);
    return exchangeRate;
  }
}

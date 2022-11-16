// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { IStakeManager } from "../../external/stader/IStakeManager.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

import "../../midas/SafeOwnableUpgradeable.sol";
import "../BasePriceOracle.sol";

/**
 * @title AnkrCertificateTokenPriceOracle
 * @author Carlo Mazzaferro <carlo@midascapital.xyz> (https://github.com/carlomazzaferro)
 * @notice AnkrCertificateTokenPriceOracle is a price oracle for Ankr Certificate liquid staked tokens.
 * @dev Implements the `PriceOracle` interface used by Midas pools (and Compound v2).
 */

interface IAnkrCertificate {
  function ratio() external view returns (uint256);
}

contract AnkrCertificateTokenPriceOracle is SafeOwnableUpgradeable, BasePriceOracle {
  IAnkrCertificate public aTokenCertificate;

  function initialize(address ankrCertificateToken) public initializer {
    __SafeOwnable_init();
    aTokenCertificate = IAnkrCertificate(ankrCertificateToken);
  }

  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();
    require(underlying == address(aTokenCertificate), "Invalid underlying");

    // no need to scale as Ankr Ceritificate Token has 18 decimals
    return _price();
  }

  function price(address underlying) external view override returns (uint256) {
    require(underlying == address(aTokenCertificate), "Invalid underlying");
    return _price();
  }

  function _price() internal view returns (uint256) {
    uint256 ONE = 1e18;

    // Returns the aXXXb / aXXXc ratio
    // Ankr Ceritificate Token Rebasing token is pegged to 1 BNB
    uint256 exchangeRate = aTokenCertificate.ratio();
    return (ONE * ONE) / exchangeRate;
  }
}

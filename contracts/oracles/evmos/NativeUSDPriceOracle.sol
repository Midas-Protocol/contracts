// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { IPriceOracle } from "../../external/compound/IPriceOracle.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { BasePriceOracle } from "../BasePriceOracle.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { SafeOwnableUpgradeable } from "../../midas/SafeOwnableUpgradeable.sol";
import { IPriceOracle as IAdrastiaPriceOracle } from "adrastia/interfaces/IPriceOracle.sol";

/**
 * @title NativeUSDPriceOracle
 * @notice Returns the NATIVE/USD price oracle for EVMOS using Adrastia
 * @dev Implements a price oracle for NATIVE/USD, using Adrastia.
 * @author Carlo Mazzaferro <rahul@midascapital.xyz> (https://github.com/carlomazzaferro)
 */
contract NativeUSDPriceOracle is SafeOwnableUpgradeable {
  /**
   * @dev Constructor to set admin and canAdminOverwrite, wtoken address and native token USD price feed address
   */

  address public NATIVE_USD_ORACLE_ADDRESS;

  function initialize(address nativeUsdOracleAddress) public initializer onlyOwnerOrAdmin {
    __SafeOwnable_init();
    NATIVE_USD_ORACLE_ADDRESS = nativeUsdOracleAddress;
  }

  /**
   * @dev Returns the price of EVMOS with 18 decimals of precision
   * https://docs.adrastia.io/deployments/evmos
   */
  function getValue() public view returns (uint256) {
    // 0xd850F64Eda6a62d625209711510f43cD49Ef8798 for EVMOS/USD
    IAdrastiaPriceOracle oracle = IAdrastiaPriceOracle(NATIVE_USD_ORACLE_ADDRESS);
    uint112 nativeTokenUsdPrice = oracle.consultPrice(address(0));
    uint8 nativeTokenPriceFeedDecimals = oracle.quoteTokenDecimals();

    if (nativeTokenUsdPrice <= 0) return 0;
    return uint256(nativeTokenUsdPrice) * 10**(18 - nativeTokenPriceFeedDecimals);
  }
}

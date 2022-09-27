// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { ICToken } from "../../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import "../../external/compound/IPriceOracle.sol";
import "../BasePriceOracle.sol";

interface DiaStDotOracle {
  function stDOTPrice() external view returns (uint256);

  function wstDOTPrice() external view returns (uint256);
}

contract DiaStDotPriceOracle is IPriceOracle, BasePriceOracle {
  MasterPriceOracle public immutable MASTER_PRICE_ORACLE;
  DiaStDotOracle private immutable DIA_STDOT_ORACLE;
  address public immutable ST_DOT;
  address public immutable WST_DOT;
  address public immutable USD_TOKEN;
  uint256 private lastPrice = 0;

  constructor(
    DiaStDotOracle _diaStDotOracle,
    MasterPriceOracle masterPriceOracle,
    address _stDot,
    address _wstDot,
    address usdToken
  ) {
    MASTER_PRICE_ORACLE = masterPriceOracle;
    DIA_STDOT_ORACLE = _diaStDotOracle;
    ST_DOT = _stDot;
    WST_DOT = _wstDot;
    USD_TOKEN = usdToken;
  }

  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();

    require(underlying == ST_DOT || underlying == WST_DOT, "Invalid underlying");
    // Get price in base 18 decimals
    uint256 oraclePrice = _price(underlying);

    // Format and return price
    uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
    return
      underlyingDecimals <= 18
        ? uint256(oraclePrice) * (10**(18 - underlyingDecimals))
        : uint256(oraclePrice) / (10**(underlyingDecimals - 18));
  }

  function price(address underlying) external view override returns (uint256) {
    require(underlying == ST_DOT || underlying == WST_DOT, "Invalid underlying");
    return _price(underlying);
  }

  function __price(address underlying) internal view returns (uint256) {
    if (underlying == ST_DOT) {
      return DIA_STDOT_ORACLE.stDOTPrice();
    } else if (underlying == WST_DOT) {
      return DIA_STDOT_ORACLE.wstDOTPrice();
    } else {
      return 0;
    }
  }

  function _price(address underlying) internal view returns (uint256) {
    // aBNBc/BUSD price
    uint256 oraclePrice = __price(underlying);
    if (oraclePrice == 0) {
      return 0;
    }
    // Get USD price
    uint256 wGlmrUsdPrice = MASTER_PRICE_ORACLE.price(USD_TOKEN);
    return (uint256(oraclePrice) / 10**18) * wGlmrUsdPrice;
  }
}

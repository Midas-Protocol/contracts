// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { ICToken } from "../../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import "../../midas/SafeOwnableUpgradeable.sol";
import "../../external/compound/IPriceOracle.sol";
import "../BasePriceOracle.sol";

import "forge-std/Vm.sol";
import "forge-std/Test.sol";

interface DiaStDotOracle {
  function stDOTPrice() external view returns (uint256);

  function wstDOTPrice() external view returns (uint256);
}

contract DiaStDotPriceOracle is SafeOwnableUpgradeable, BasePriceOracle {
  MasterPriceOracle public MASTER_PRICE_ORACLE;
  DiaStDotOracle public DIA_STDOT_ORACLE;
  address public ST_DOT;
  address public WST_DOT;
  address public USD_TOKEN;

  function initialize(
    MasterPriceOracle masterPriceOracle,
    DiaStDotOracle _diaStDotOracle,
    address _stDot,
    address _wstDot,
    address usdToken
  ) public initializer {
    __SafeOwnable_init();
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
    return _price(underlying);
  }

  function price(address underlying) external view override returns (uint256) {
    require(underlying == ST_DOT || underlying == WST_DOT, "Invalid underlying");
    return _price(underlying);
  }

  function _price(address underlying) internal view returns (uint256) {
    uint256 oraclePrice;
    // stDOTPrice() and wstDOTPrice() are 8-decimal feeds
    if (underlying == ST_DOT) {
      oraclePrice = (DIA_STDOT_ORACLE.stDOTPrice() * 1e10);
    } else if (underlying == WST_DOT) {
      oraclePrice = (DIA_STDOT_ORACLE.wstDOTPrice() * 1e10);
    } else {
      return 0;
    }
    // Get USD price
    uint256 wGlmrUsdPrice = MASTER_PRICE_ORACLE.price(USD_TOKEN);
    return (uint256(oraclePrice) * wGlmrUsdPrice) / 10**18;
  }
}

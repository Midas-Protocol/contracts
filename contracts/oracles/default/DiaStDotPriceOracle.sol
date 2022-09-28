// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { ICToken } from "../../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import "../../midas/SafeOwnableUpgradeable.sol";
import "../../external/compound/IPriceOracle.sol";
import "../BasePriceOracle.sol";

interface DiaStDotOracle {
  function stDOTPrice() external view returns (uint256);

  function wstDOTPrice() external view returns (uint256);
}

contract DiaStDotPriceOracle is SafeOwnableUpgradeable, BasePriceOracle {
  MasterPriceOracle public masterPriceOracle;
  DiaStDotOracle public diaStDotOracle;
  address public usdToken;

  address public immutable ST_DOT;
  address public immutable WST_DOT;

  constructor(address stDot, address wstDot) {
    ST_DOT = stDot;
    WST_DOT = wstDot;
  }

  function initialize(
    MasterPriceOracle _masterPriceOracle,
    DiaStDotOracle _diaStDotOracle,
    address _usdToken
  ) public initializer {
    __SafeOwnable_init();
    masterPriceOracle = _masterPriceOracle;
    diaStDotOracle = _diaStDotOracle;
    usdToken = _usdToken;
  }

  /**
   * @dev Re-initializes the pool in case of address changes
   * @param _usdToken stable toklen address
   * @param _diaStDotOracle dia oracle address
   * @param _masterPriceOracle mpo addresses.
   */
  function reinitialize(
    MasterPriceOracle _masterPriceOracle,
    DiaStDotOracle _diaStDotOracle,
    address _usdToken
  ) public reinitializer(2) onlyOwner {
    masterPriceOracle = _masterPriceOracle;
    diaStDotOracle = _diaStDotOracle;
    usdToken = _usdToken;
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
      oraclePrice = (diaStDotOracle.stDOTPrice() * 1e10);
    } else if (underlying == WST_DOT) {
      oraclePrice = (diaStDotOracle.wstDOTPrice() * 1e10);
    } else {
      return 0;
    }
    // Get USD price
    uint256 wGlmrUsdPrice = masterPriceOracle.price(usdToken);
    return (uint256(oraclePrice) * wGlmrUsdPrice) / 10**18;
  }
}

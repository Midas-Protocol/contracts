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

  address public stDot;
  address public wstDot;

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
   */
  function reinitialize() public reinitializer(4) onlyOwnerOrAdmin {
    stDot = 0xFA36Fe1dA08C89eC72Ea1F0143a35bFd5DAea108;
    wstDot = 0x191cf2602Ca2e534c5Ccae7BCBF4C46a704bb949;
  }

  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();

    require(underlying == stDot || underlying == wstDot, "Invalid underlying");

    // scaling the already scaled to 1e18 price by 1e(18-decimals)
    // decimals for both stDOT and wstDOT is 10
    return _price(underlying) * 1e8;
  }

  function price(address underlying) external view override returns (uint256) {
    require(underlying == stDot || underlying == wstDot, "Invalid underlying");
    return _price(underlying);
  }

  function _price(address underlying) internal view returns (uint256) {
    uint256 oraclePrice;
    // stDOTPrice() and wstDOTPrice() are 8-decimal feeds
    if (underlying == stDot) {
      oraclePrice = (diaStDotOracle.stDOTPrice() * 1e10);
    } else if (underlying == wstDot) {
      oraclePrice = (diaStDotOracle.wstDOTPrice() * 1e10);
    } else {
      return 0;
    }

    // Get USD price
    uint256 wGlmrUsdPrice = masterPriceOracle.price(usdToken);
    return (uint256(oraclePrice) * wGlmrUsdPrice) / 1e18;
  }
}

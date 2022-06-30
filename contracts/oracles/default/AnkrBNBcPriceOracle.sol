// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { ICToken } from "../../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import "../../external/compound/IPriceOracle.sol";
import "../BasePriceOracle.sol";

interface AnkrOracle {
  function peek() external view returns (bytes32, bool);
}

contract AnkrBNBcPriceOracle is IPriceOracle, BasePriceOracle {
  MasterPriceOracle public immutable MASTER_PRICE_ORACLE;
  AnkrOracle private immutable ANKR_ORACLE;
  address public immutable BASE_TOKEN;
  address public immutable USD_TOKEN;
  uint256 private lastPrice = 0;

  constructor(
    AnkrOracle _ankrOracle,
    MasterPriceOracle masterPriceOracle,
    address _baseToken,
    address usdToken
  ) {
    MASTER_PRICE_ORACLE = masterPriceOracle;
    ANKR_ORACLE = _ankrOracle;
    USD_TOKEN = usdToken;
    BASE_TOKEN = _baseToken;
  }

  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    // Return 1e18 for ETH
    if (cToken.isCEther()) return 1e18;

    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();

    require(underlying == BASE_TOKEN, "Invalid underlying");
    // Get price
    uint256 oraclePrice = _price();

    // Format and return price
    uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
    return
      underlyingDecimals <= 18
        ? uint256(oraclePrice) * (10**(18 - underlyingDecimals))
        : uint256(oraclePrice) / (10**(underlyingDecimals - 18));
  }

  function price(address underlying) external view override returns (uint256) {
    require(underlying == BASE_TOKEN, "Invalid underlying.");
    return _price();
  }

  function _price() internal view returns (uint256) {
    // aBNBc/BUSD price
    (bytes32 price, bool success) = ANKR_ORACLE.peek();

    if (success) {
      uint256 BusdBnbPrice = MASTER_PRICE_ORACLE.price(USD_TOKEN);

      return (uint256(price) / 10**18) * BusdBnbPrice;
    }

    return 0;
  }
}

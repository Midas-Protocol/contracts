// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { ICToken } from "../../external/compound/ICToken.sol";
import { IStakePool, ExchangeRateData } from "../../external/pstake/IStakePool.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

import "../../midas/SafeOwnableUpgradeable.sol";
import "../BasePriceOracle.sol";

contract StkBNBPriceOracle is SafeOwnableUpgradeable, BasePriceOracle {
  IStakePool public stakingPool = IStakePool(0xC228CefDF841dEfDbD5B3a18dFD414cC0dbfa0D8);
  address public stkBnb = 0xc2E9d07F66A89c44062459A47a0D2Dc038E4fb16;

  function initialize() public initializer {
    __SafeOwnable_init();
  }

  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    // Get underlying token address
    address underlying = ICErc20(address(cToken)).underlying();

    require(underlying == stkBnb, "Invalid underlying");

    uint256 stkBnbPrice = _price();

    // scale by decimals (18 for stkBNB)
    uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
    return uint256(stkBnbPrice) * (10**(18 - underlyingDecimals));
  }

  function price(address underlying) external view override returns (uint256) {
    require(underlying == stkBnb, "Invalid underlying");
    return _price();
  }

  function _price() internal view returns (uint256) {
    // 1 stkBNB  = (totalWei / poolTokenSupply) BNB
    ExchangeRateData memory exchangeRate = stakingPool.exchangeRate();
    uint256 stkBNBPrice = (exchangeRate.totalWei * 1e18) / exchangeRate.poolTokenSupply;
    return stkBNBPrice;
  }
}

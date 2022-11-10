// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { ICToken } from "../../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

import "../../external/compound/IPriceOracle.sol";
import "../BasePriceOracle.sol";

interface IWombexLpAsset {
  function cash() external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function underlyingToken() external view returns (address);
}

contract WombexLpTokenPriceOracle is IPriceOracle, BasePriceOracle {
  MasterPriceOracle public immutable MASTER_PRICE_ORACLE;

  constructor(
    MasterPriceOracle _masterPriceOracle
  ) {
    MASTER_PRICE_ORACLE = _masterPriceOracle;
  }

  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    if (cToken.isCEther()) return 1e18;

    address asset = ICErc20(address(cToken)).underlying();

    uint256 oraclePrice = _price(asset);

    uint256 assetDecimals = uint256(ERC20Upgradeable(asset).decimals());

    return assetDecimals <= 18
      ? uint256(oraclePrice) * (10**(18 - assetDecimals))
      : uint256(oraclePrice) / (10**(assetDecimals - 18));
  }

  function _price(address asset) internal view returns (uint256) {
    address underlying = IWombexLpAsset(asset).underlyingToken();

    // balance of underlying asset that vault contains
    uint256 underlyingCash = IWombexLpAsset(asset).cash();
    // total supply of vault token
    uint256 assetTotalSupply = IWombexLpAsset(asset).totalSupply();

    if (assetTotalSupply == 0) return 0;

    uint256 underlyingPrice = MASTER_PRICE_ORACLE.price(underlying);

    return underlyingPrice * underlyingCash / assetTotalSupply;
  }

  function price(address asset) external view override returns (uint256) {
    return _price(asset);
  }
}
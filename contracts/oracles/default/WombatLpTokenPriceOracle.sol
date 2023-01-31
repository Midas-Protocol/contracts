// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

import { ICToken } from "../../external/compound/ICToken.sol";
import { MasterPriceOracle } from "../MasterPriceOracle.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";

import "../../external/compound/IPriceOracle.sol";
import "../BasePriceOracle.sol";

interface IWombatLpAsset {
  function cash() external view returns (uint256);

  function underlyingTokenBalance() external view returns (uint256);

  function totalSupply() external view returns (uint256);

  function underlyingToken() external view returns (address);

  function pool() external view returns (address);

  function liability() external view returns (uint256);
}

contract WombatLpTokenPriceOracle is IPriceOracle, BasePriceOracle {
  function getUnderlyingPrice(ICToken cToken) external view override returns (uint256) {
    if (cToken.isCEther()) return 1e18;

    address asset = ICErc20(address(cToken)).underlying();

    uint256 oraclePrice = _price(asset);

    uint256 assetDecimals = uint256(ERC20Upgradeable(asset).decimals());

    return
      assetDecimals <= 18
        ? uint256(oraclePrice) * (10**(18 - assetDecimals))
        : uint256(oraclePrice) / (10**(assetDecimals - 18));
  }

  function _price(address asset) internal view returns (uint256) {
    // total supply of vault token
    uint256 assetTotalSupply = IWombatLpAsset(asset).totalSupply();

    if (assetTotalSupply == 0) return 0;

    address underlying = IWombatLpAsset(asset).underlyingToken();

    // balance of underlying asset that vault contains
    uint256 underlyingLiability = IWombatLpAsset(asset).liability();

    uint256 underlyingPrice = BasePriceOracle(msg.sender).price(underlying);

    return (underlyingPrice * underlyingLiability) / assetTotalSupply;
  }

  function price(address asset) external view override returns (uint256) {
    return _price(asset);
  }
}

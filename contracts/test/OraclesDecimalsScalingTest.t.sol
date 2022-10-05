// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "./config/BaseTest.t.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CTokenInterface } from "../compound/CTokenInterfaces.sol";
import { ICToken } from "../external/compound/ICToken.sol";

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";

contract OraclesDecimalsScalingTest is BaseTest {
  MasterPriceOracle mpo;
  FusePoolDirectory fusePoolDirectory;

  function setUp() public {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    fusePoolDirectory = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
  }

  function testOraclesDecimals() public {
    if (address(fusePoolDirectory) != address(0)) {
      FusePoolDirectory.FusePool[] memory pools = fusePoolDirectory.getAllPools();

      for (uint8 i = 0; i < pools.length; i++) {
        Comptroller comptroller = Comptroller(pools[i].comptroller);
        CTokenInterface[] memory markets = comptroller.getAllMarkets();
        for (uint8 j = 0; j < markets.length; j++) {
          address marketAddress = address(markets[j]);
          CErc20Delegate market = CErc20Delegate(marketAddress);
          address underlying = market.underlying();
          uint256 oraclePrice = mpo.price(underlying);
          uint256 scaledPrice = mpo.getUnderlyingPrice(ICToken(marketAddress));

          uint256 underlyingDecimals = uint256(ERC20Upgradeable(underlying).decimals());
          uint256 expectedScaledPrice = underlyingDecimals <= 18
            ? uint256(oraclePrice) * (10**(18 - underlyingDecimals))
            : uint256(oraclePrice) / (10**(underlyingDecimals - 18));

          assertEq(scaledPrice, expectedScaledPrice, "the comptroller expects prices to be scaled by 1e(36-decimals)");
        }
      }
    }
  }
}

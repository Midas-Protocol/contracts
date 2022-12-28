// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "./config/BaseTest.t.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { FusePoolDirectory } from "../FusePoolDirectory.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { CTokenInterface } from "../compound/CTokenInterfaces.sol";
import { ICToken } from "../external/compound/ICToken.sol";
import { IComptroller } from "../external/compound/IComptroller.sol";

import { IERC20MetadataUpgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/extensions/IERC20MetadataUpgradeable.sol";

contract OraclesDecimalsScalingTest is BaseTest {
  MasterPriceOracle mpo;
  FusePoolDirectory fusePoolDirectory;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    fusePoolDirectory = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
  }

  function testOracleDecimalsBsc() public fork(BSC_MAINNET) {
    testOraclesDecimals();
  }

  function testOracleDecimalsArbitrum() public fork(ARBITRUM_ONE) {
    testOraclesDecimals();
  }

  function testOracleDecimalsMoonbeam() public fork(MOONBEAM_MAINNET) {
    testOraclesDecimals();
  }

  function testOracleDecimalsPolygon() public fork(POLYGON_MAINNET) {
    testOraclesDecimals();
  }

  function testOracleDecimalsNeonDev() public fork(NEON_DEVNET) {
    testOraclesDecimals();
  }

  function testOraclesDecimals() internal {
    if (address(fusePoolDirectory) != address(0)) {
      (, FusePoolDirectory.FusePool[] memory pools) = fusePoolDirectory.getActivePools();

      for (uint8 i = 0; i < pools.length; i++) {
        IComptroller comptroller = IComptroller(pools[i].comptroller);
        ICToken[] memory markets = comptroller.getAllMarkets();
        for (uint8 j = 0; j < markets.length; j++) {
          address marketAddress = address(markets[j]);
          CErc20Delegate market = CErc20Delegate(marketAddress);
          address underlying = market.underlying();

          if (isSkipped(underlying)) {
            emit log("the oracle for this underlying cannot be tested");
            emit log_address(underlying);
            continue;
          }

          uint256 oraclePrice = mpo.price(underlying);
          uint256 scaledPrice = mpo.getUnderlyingPrice(markets[j]);

          uint8 decimals = IERC20MetadataUpgradeable(underlying).decimals();
          uint256 expectedScaledPrice = decimals <= 18
            ? uint256(oraclePrice) * (10**(18 - decimals))
            : uint256(oraclePrice) / (10**(decimals - 18));

          assertEq(scaledPrice, expectedScaledPrice, "the comptroller expects prices to be scaled by 1e(36-decimals)");
        }
      }
    }
  }

  function isSkipped(address token) internal pure returns (bool) {
    return
      token == 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080 || // xcDOT
      token == 0xc6e37086D09ec2048F151D11CdB9F9BbbdB7d685 || // xcDOT-stDOT LP token
      token == 0xa927E1e1E044CA1D9fe1854585003477331fE2Af; // WGLMR_xcDOT stella LP token
  }
}

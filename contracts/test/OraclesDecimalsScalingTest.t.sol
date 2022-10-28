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

  function setNetworkValues(string memory network, uint256 forkBlockNumber) internal {
    vm.createSelectFork(vm.rpcUrl(network), forkBlockNumber);
    setAddressProvider(network);

    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    fusePoolDirectory = FusePoolDirectory(ap.getAddress("FusePoolDirectory"));
  }

  function testBsc() public {
    setNetworkValues("bsc", 21945844);
    testOraclesDecimals();
  }

  function testArbitrum() public {
    setNetworkValues("arbitrum", 28654955);
    testOraclesDecimals();
  }

  function testMoonbeam() public {
    setNetworkValues("moonbeam", 2020022);
    testOraclesDecimals();
  }

  function testPolygon() public {
    setNetworkValues("polygon", 33996000);
    testOraclesDecimals();
  }

  function testNeonDev() public {
    setNetworkValues("neon_dev", 167826388);
    testOraclesDecimals();
  }

  function testOraclesDecimals() internal {
    if (address(fusePoolDirectory) != address(0)) {
      FusePoolDirectory.FusePool[] memory pools = fusePoolDirectory.getAllPools();

      for (uint8 i = 0; i < pools.length; i++) {
        Comptroller comptroller = Comptroller(pools[i].comptroller);
        CTokenInterface[] memory markets = comptroller.getAllMarkets();
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
          uint256 scaledPrice = mpo.getUnderlyingPrice(ICToken(marketAddress));

          uint8 decimals = ERC20Upgradeable(underlying).decimals();
          uint256 expectedScaledPrice = decimals <= 18
            ? uint256(oraclePrice) * (10**(18 - decimals))
            : uint256(oraclePrice) / (10**(decimals - 18));

          assertEq(scaledPrice, expectedScaledPrice, "the comptroller expects prices to be scaled by 1e(36-decimals)");
        }
      }
    }
  }

  function isSkipped(address token) internal returns (bool) {
    return
      token == 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080 || // xcDOT
      token == 0xc6e37086D09ec2048F151D11CdB9F9BbbdB7d685 || // xcDOT-stDOT LP token
      token == 0xa927E1e1E044CA1D9fe1854585003477331fE2Af; // WGLMR_xcDOT stella LP token
  }
}

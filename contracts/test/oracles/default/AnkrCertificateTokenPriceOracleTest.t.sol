// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BaseTest } from "../../config/BaseTest.t.sol";
import { AnkrCertificateTokenPriceOracle } from "../../../oracles/default/AnkrCertificateTokenPriceOracle.sol";

contract AnkrCertificateTokenPriceOracleTest is BaseTest {
  AnkrCertificateTokenPriceOracle private oracle;

  address aFTMc = 0xCfC785741Dc0e98ad4c9F6394Bb9d43Cd1eF5179;
  address aBNBc = 0xE85aFCcDaFBE7F2B096f268e31ccE3da8dA2990A;
  address aMATICc = 0x0E9b89007eEE9c958c0EDA24eF70723C2C93dD58;

  function afterForkSetUp() internal override {
    oracle = new AnkrCertificateTokenPriceOracle();
    if (block.chainid == BSC_MAINNET) {
      oracle.initialize(aBNBc);
    } else if (block.chainid == FANTOM_OPERA) {
      oracle.initialize(aFTMc);
    } else if (block.chainid == POLYGON_MAINNET) {
      oracle.initialize(aMATICc);
    }
  }

  function testAnkrFTMOracle() public forkAtBlock(FANTOM_OPERA, 51176746) {
    uint256 priceAnkrFTMc = oracle.price(aFTMc);
    assertGt(priceAnkrFTMc, 1e18);
    assertEq(priceAnkrFTMc, 1032694573127108753);
  }

  function testAnkrBSCOracle() public forkAtBlock(BSC_MAINNET, 22967648) {
    uint256 priceAnkrBNBc = oracle.price(aBNBc);
    assertGt(priceAnkrBNBc, 1e18);
    assertEq(priceAnkrBNBc, 1036531403670513817);
  }

  function testAnkrPolygonOracle() public forkAtBlock(POLYGON_MAINNET, 36299660) {
    uint256 priceAnkrMATICc = oracle.price(aMATICc);
    assertGt(priceAnkrMATICc, 1e18);
    assertEq(priceAnkrMATICc, 1099296293061644034);
  }
}

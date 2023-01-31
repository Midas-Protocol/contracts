// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { ERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/ERC20Upgradeable.sol";
import { BasePriceOracle } from "../../../oracles/BasePriceOracle.sol";
import { MasterPriceOracle } from "../../../oracles/MasterPriceOracle.sol";
import { SafeOwnableUpgradeable } from "../../../midas/SafeOwnableUpgradeable.sol";
import { IPriceOracle as IAdrastiaPriceOracle } from "adrastia/interfaces/IPriceOracle.sol";
import { NativeUSDPriceOracle } from "../../../oracles/evmos/NativeUSDPriceOracle.sol";

import { BaseTest } from "../../config/BaseTest.t.sol";

contract NativeUSDPriceOracleTest is BaseTest {
  NativeUSDPriceOracle private oracle;
  address EVMOS_USD_FEED = 0xeA07Ede816EcD52F17aEEf82a50a608Ca5369145;
  address WEVMOS = 0xD4949664cD82660AaE99bEdc034a0deA8A0bd517;

  function afterForkSetUp() internal override {
    oracle = new NativeUSDPriceOracle();
    vm.startPrank(oracle.owner());
    oracle.initialize(EVMOS_USD_FEED, WEVMOS);
  }

  function testNativeUSDPriceOracle() public fork(EVMOS_MAINNET) {
    uint256 evmosUsdPrice = oracle.getValue();
    assertGt(evmosUsdPrice, 1e17);
    assertLt(evmosUsdPrice, 1e19);
  }
}

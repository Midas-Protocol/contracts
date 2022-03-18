// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";
import "forge-std/Vm.sol";

import {WETH} from "@rari-capital/solmate/src/tokens/WETH.sol";

import {CurveLpTokenPriceOracleNoRegistry} from "../../contracts/oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import {CurveLpTokenLiquidatorNoRegistry} from "../../contracts/liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import "../../contracts/utils/IW_NATIVE.sol";

contract CurveLpTokenLiquidatorNoRegistryTest is DSTest {
  using stdStorage for StdStorage;

  Vm public constant vm = Vm(HEVM_ADDRESS);

  StdStorage stdstore;

  CurveLpTokenLiquidatorNoRegistry liquidator;

  WETH weth;
  CurveLpTokenPriceOracleNoRegistry oracle;

  function setUp() public {
    weth = new WETH();
    oracle = new CurveLpTokenPriceOracleNoRegistry();
    oracle.initialize(new address[](0), new address[](0), new address[][](0));
    liquidator = new CurveLpTokenLiquidatorNoRegistry(weth, oracle);
  }

  function testInitalizedValues() public {
    assertEq(address(liquidator.W_NATIVE()), address(weth));
    assertEq(address(liquidator.oracle()), address(oracle));
  }
}

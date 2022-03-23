// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";
import "forge-std/stdlib.sol";

import {WETH} from "@rari-capital/solmate/src/tokens/WETH.sol";

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {CurveLpTokenLiquidatorNoRegistry} from "../../contracts/liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import "../../contracts/utils/IW_NATIVE.sol";
import "../../contracts/external/curve/ICurvePool.sol";
import {BscMainnetBaseTest} from "../config/BaseTest.sol";

contract CurveLpTokenLiquidatorNoRegistryTest is BscMainnetBaseTest {
  CurveLpTokenLiquidatorNoRegistry private liquidator;
  ChainConfig private chainConfig;

  function setUp() override public {
    super.setUp();
    chainConfig = chainConfigs[block.chainid];
    liquidator = new CurveLpTokenLiquidatorNoRegistry(chainConfig.weth, chainConfig.curveLPTokenPriceOracleNoRegistry);
  }

  function testInitalizedValues() public {
    assertEq(address(liquidator.W_NATIVE()), address(chainConfig.weth));
    assertEq(address(liquidator.oracle()), address(chainConfig.curveLPTokenPriceOracleNoRegistry));
  }

  // tested with bsc block number 16233661
  function testRedeemToken() public {
    if (address(chainConfig.pool) == address(0)) {
      // cannot test with this chainId
      assertTrue(true);
      return;
    }

    vm.prank(chainConfig.whale);
    chainConfig.lpToken.transfer(address(liquidator), 1234);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(chainConfig.lpToken, 1234, abi.encode(uint8(0), chainConfig.coins[0]));
    assertEq(address(outputToken), address(chainConfig.coins[0]));
    assertGt(outputAmount, 0);
    assertEq(outputToken.balanceOf(address(liquidator)), outputAmount);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "ds-test/test.sol";

import { WETH } from "solmate/tokens/WETH.sol";

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { CurveLpTokenLiquidatorNoRegistry } from "../liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import "../utils/IW_NATIVE.sol";
import "../external/curve/ICurvePool.sol";
import "./config/BaseTest.t.sol";

contract CurveLpTokenLiquidatorNoRegistryTest is BaseTest {
  CurveLpTokenLiquidatorNoRegistry private liquidator;

  function setUp() public {
    liquidator = new CurveLpTokenLiquidatorNoRegistry(chainConfig.weth, chainConfig.curveLPTokenPriceOracleNoRegistry);
  }

  function testInitializedValues() public {
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

    vm.prank(chainConfig.lpTokenWhale);
    chainConfig.lpToken.transfer(address(liquidator), 1234);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      chainConfig.lpToken,
      1234,
      abi.encode(uint8(0), chainConfig.coins[0])
    );
    assertEq(address(outputToken), address(chainConfig.coins[0]));
    assertGt(outputAmount, 0);
    assertEq(outputToken.balanceOf(address(liquidator)), outputAmount);
  }
}

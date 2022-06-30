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

  address private lpTokenWhale = 0x8D7408C2b3154F9f97fc6dd24cd36143908d1E52;
  IERC20Upgradeable lpToken = IERC20Upgradeable(0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452);
  CurveLpTokenPriceOracleNoRegistry curveLPTokenPriceOracleNoRegistry =
    CurveLpTokenPriceOracleNoRegistry(0x44ea7bAB9121D97630b5DB0F92aAd75cA5A401a3);

  IERC20Upgradeable bUSD;
  WETH wtoken;

  function setUp() public shouldRun(forChains(BSC_MAINNET)) {
    wtoken = WETH(payable(ap.getAddress("wtoken")));
    liquidator = new CurveLpTokenLiquidatorNoRegistry(wtoken, curveLPTokenPriceOracleNoRegistry);
    bUSD = IERC20Upgradeable(ap.getAddress("bUSD"));
  }

  function testInitializedValues() public shouldRun(forChains(BSC_MAINNET)) {
    assertEq(address(liquidator.W_NATIVE()), address(wtoken));
    assertEq(address(liquidator.oracle()), address(curveLPTokenPriceOracleNoRegistry));
  }

  // tested with bsc block number 16233661
  function testRedeemToken() public shouldRun(forChains(BSC_MAINNET)) {
    vm.prank(lpTokenWhale);
    lpToken.transfer(address(liquidator), 1234);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      lpToken,
      1234,
      abi.encode(uint8(0), bUSD)
    );
    assertEq(address(outputToken), address(bUSD));
    assertGt(outputAmount, 0);
    assertEq(outputToken.balanceOf(address(liquidator)), outputAmount);
  }
}

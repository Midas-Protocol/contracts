// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { CurveLpTokenLiquidatorNoRegistry } from "../liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import { CurveLpTokenPriceOracleNoRegistry } from "../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import "../external/curve/ICurvePool.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract CurveLpTokenLiquidatorNoRegistryTest is BaseTest {
  CurveLpTokenLiquidatorNoRegistry private liquidator;

  address private lpTokenWhale = 0x8D7408C2b3154F9f97fc6dd24cd36143908d1E52;
  IERC20Upgradeable lpToken = IERC20Upgradeable(0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452);
  CurveLpTokenPriceOracleNoRegistry curveLPTokenPriceOracleNoRegistry =
    CurveLpTokenPriceOracleNoRegistry(0x4544d21EB5B368b3f8F98DcBd03f28aC0Cf6A0CA);

  IERC20Upgradeable bUSD;
  address wtoken;

  function afterForkSetUp() internal override {
    wtoken = ap.getAddress("wtoken");
    liquidator = new CurveLpTokenLiquidatorNoRegistry();
    bUSD = IERC20Upgradeable(ap.getAddress("bUSD"));
  }

  function testRedeemToken() public fork(BSC_MAINNET) {
    vm.prank(lpTokenWhale);
    lpToken.transfer(address(liquidator), 1234);

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      lpToken,
      1234,
      abi.encode(uint8(0), bUSD, wtoken, curveLPTokenPriceOracleNoRegistry)
    );

    assertEq(address(outputToken), address(bUSD), "!outputToken");
    assertGt(outputAmount, 0, "!outputAmount>0");
    assertEq(outputToken.balanceOf(address(liquidator)), outputAmount, "!outputAmount");
  }

  function testRedeem2Brl() public fork(BSC_MAINNET) {
    IERC20Upgradeable twobrl = IERC20Upgradeable(0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9);
    address whale2brl = 0x6219b46d6a5B5BfB4Ec433a9F96DB3BF4076AEE1;
    vm.prank(whale2brl);
    twobrl.transfer(address(liquidator), 123456);

    address poolOf2Brl = curveLPTokenPriceOracleNoRegistry.poolOf(address(twobrl));

    require(poolOf2Brl != address(0), "could not find the pool for 2brl");

    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(
      twobrl,
      123456,
      abi.encode(uint8(0), 0x316622977073BBC3dF32E7d2A9B3c77596a0a603, wtoken, curveLPTokenPriceOracleNoRegistry)
    );
    assertEq(address(outputToken), 0x316622977073BBC3dF32E7d2A9B3c77596a0a603);
    assertGt(outputAmount, 0);
    assertEq(outputToken.balanceOf(address(liquidator)), outputAmount);
  }

  function testCurveLPOracle() public fork(POLYGON_MAINNET) {
    MasterPriceOracle mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    //CurveLpTokenPriceOracleNoRegistry oracle = CurveLpTokenPriceOracleNoRegistry(0xaCF3E1C6f2D6Ff12B8aEE44413D6834774B3f7A3);
    address stMaticMaticCurveLPToken = 0xe7CEA2F6d7b120174BF3A9Bc98efaF1fF72C997d;
    address curvePool = 0xFb6FE7802bA9290ef8b00CA16Af4Bc26eb663a28;

    uint256 priceBefore = mpo.price(0xe7CEA2F6d7b120174BF3A9Bc98efaF1fF72C997d);
    emit log_named_uint("priceBefore", priceBefore);

    address hacker = address(1337);
    uint256 flashLoaned = 72e6 * 1e18;

    vm.deal(hacker, flashLoaned + 1e18);
    //    WETH wmatic = WETH(payable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270));
    //
    //    wmatic.deposit{value: 270000 * 1e18}();

    ICurvePool pool = ICurvePool(curvePool); // 0 - stMatic, 1 - wmatic

    emit log_named_address("coin0", pool.coins(0));
    emit log_named_address("coin1", pool.coins(1));

    uint256[2] memory amounts;
    amounts[0] = 0;
    amounts[1] = flashLoaned;

    vm.startPrank(hacker);

    pool.add_liquidity(amounts, 1, true);
    vm.stopPrank();

    uint256 priceAfter = mpo.price(0xe7CEA2F6d7b120174BF3A9Bc98efaF1fF72C997d);
    emit log_named_uint("priceAfter", priceAfter);
  }
}

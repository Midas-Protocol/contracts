// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { CurveLpTokenLiquidatorNoRegistry, CurveLpTokenWrapper } from "../../liquidators/CurveLpTokenLiquidatorNoRegistry.sol";
import { CurveLpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveLpTokenPriceOracleNoRegistry.sol";
import { CurveV2LpTokenPriceOracleNoRegistry } from "../../oracles/default/CurveV2LpTokenPriceOracleNoRegistry.sol";

import { BaseTest } from "../config/BaseTest.t.sol";

contract CurveLpTokenLiquidatorNoRegistryTest is BaseTest {
  CurveLpTokenLiquidatorNoRegistry private liquidator;

  IERC20Upgradeable twobrl = IERC20Upgradeable(0x1B6E11c5DB9B15DE87714eA9934a6c52371CfEA9);
  IERC20Upgradeable lpToken3Eps = IERC20Upgradeable(0xaF4dE8E872131AE328Ce21D909C74705d3Aaf452);

  address pool3Eps = 0x160CAed03795365F3A589f10C379FfA7d75d4E76;
  address pool2Brl = 0xad51e40D8f255dba1Ad08501D6B1a6ACb7C188f3;

  CurveLpTokenPriceOracleNoRegistry curveV1Oracle;
  CurveV2LpTokenPriceOracleNoRegistry curveV2Oracle;

  IERC20Upgradeable bUSD;
  address wtoken;

  function afterForkSetUp() internal override {
    wtoken = ap.getAddress("wtoken");
    liquidator = new CurveLpTokenLiquidatorNoRegistry();
    bUSD = IERC20Upgradeable(ap.getAddress("bUSD"));
    curveV1Oracle = CurveLpTokenPriceOracleNoRegistry(ap.getAddress("CurveLpTokenPriceOracleNoRegistry"));
    curveV2Oracle = CurveV2LpTokenPriceOracleNoRegistry(ap.getAddress("CurveV2LpTokenPriceOracleNoRegistry"));

    // TODO remove after the next deploy
    if (address(curveV1Oracle) == address(0)) {
      address[][] memory _poolUnderlyings = new address[][](2);
      _poolUnderlyings[0] = asArray(
        0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56,
        0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d,
        0x55d398326f99059fF775485246999027B3197955
      );
      _poolUnderlyings[1] = asArray(
        0x316622977073BBC3dF32E7d2A9B3c77596a0a603,
        0x71be881e9C5d4465B3FfF61e89c6f3651E69B5bb
      );
      curveV1Oracle = new CurveLpTokenPriceOracleNoRegistry();
      curveV1Oracle.initialize(
        asArray(address(lpToken3Eps), address(twobrl)),
        asArray(pool3Eps, pool2Brl),
        _poolUnderlyings
      );
    }
  }

  function testRedeemToken() public fork(BSC_MAINNET) {
    address lpTokenWhale = 0x8D7408C2b3154F9f97fc6dd24cd36143908d1E52;
    vm.prank(lpTokenWhale);
    lpToken3Eps.transfer(address(liquidator), 1234);

    bytes memory data = abi.encode(bUSD, wtoken, curveV1Oracle);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(lpToken3Eps, 1234, data);

    assertEq(address(outputToken), address(bUSD), "!outputToken");
    assertGt(outputAmount, 0, "!outputAmount>0");
    assertEq(outputToken.balanceOf(address(liquidator)), outputAmount, "!outputAmount");
  }

  function testRedeem2Brl() public fork(BSC_MAINNET) {
    address jbrl = 0x316622977073BBC3dF32E7d2A9B3c77596a0a603;
    address whale2brl = 0x6219b46d6a5B5BfB4Ec433a9F96DB3BF4076AEE1;
    vm.prank(whale2brl);
    twobrl.transfer(address(liquidator), 123456);

    address poolOf2Brl = curveV1Oracle.poolOf(address(twobrl)); // 0xad51e40D8f255dba1Ad08501D6B1a6ACb7C188f3

    require(poolOf2Brl != address(0), "could not find the pool for 2brl");

    bytes memory data = abi.encode(jbrl, wtoken, curveV1Oracle);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(twobrl, 123456, data);
    assertEq(address(outputToken), jbrl);
    assertGt(outputAmount, 0);
    assertEq(outputToken.balanceOf(address(liquidator)), outputAmount);
  }

  address usdrAddress = 0xb5DFABd7fF7F83BAB83995E72A52B97ABb7bcf63;
  address whaleUsdr = 0x76F49dE0c05cB7E2d0A08A0d9D12907d508fA88D;
  address whaleUsdr3Crv = 0xC225714E9c439Da0b9300B62645F24917BA753E7;
  IERC20Upgradeable usdr3Crv = IERC20Upgradeable(0xa138341185a9D0429B0021A11FB717B225e13e1F);

  function testRedeemUsdr3Crv() public fork(POLYGON_MAINNET) {
    vm.prank(whaleUsdr3Crv);
    usdr3Crv.transfer(address(liquidator), 1.23456e18);

    address poolOfUsdr3Crv = curveV1Oracle.poolOf(address(usdr3Crv)); // 0xa138341185a9D0429B0021A11FB717B225e13e1F

    require(poolOfUsdr3Crv != address(0), "could not find the pool for usdr3Crv");

    bytes memory data = abi.encode(usdrAddress, wtoken, curveV1Oracle);
    (IERC20Upgradeable outputToken, uint256 outputAmount) = liquidator.redeem(usdr3Crv, 1.23456e18, data);
    assertEq(address(outputToken), usdrAddress);
    assertGt(outputAmount, 0);
    assertEq(outputToken.balanceOf(address(liquidator)), outputAmount);
  }

  function testCurveLpTokenWrapper() public fork(POLYGON_MAINNET) {
    IERC20Upgradeable usdr = IERC20Upgradeable(usdrAddress);
    CurveLpTokenWrapper wrapper = new CurveLpTokenWrapper();
    vm.prank(whaleUsdr);
    usdr.transfer(address(wrapper), 100e11);

    wrapper.swapFor(
      IERC20Upgradeable(usdrAddress),
      100e11,
      usdr3Crv,
      1,
      abi.encode(curveV1Oracle)
    );

    assertGt(usdr3Crv.balanceOf(address(wrapper)), 0, "!wrapped");
  }
}

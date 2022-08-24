// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { BaseTest } from "./config/BaseTest.t.sol";
import "../external/curve/ICurvePool.sol";
import "../compound/EIP20NonStandardInterface.sol";
import "../compound/JumpRateModel.sol";

import { CurveSwapLiquidator } from "../liquidators/CurveSwapLiquidator.sol";

contract CurveSwapLiquidatorTest is BaseTest {
  CurveSwapLiquidator private csl;

  function setUp() public {
    csl = new CurveSwapLiquidator(ap.getAddress("wtoken"));
  }

  function not_working_TestRedeem() public shouldRun(forChains(MOONBEAM_MAINNET)) {
    address pool = 0x0fFc46cD9716a96d8D89E1965774A70Dcb851E50; // xcDOT-stDOT
    address xcDotAddress = 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080; // 0
    address stDotAddress = 0xFA36Fe1dA08C89eC72Ea1F0143a35bFd5DAea108; // 1
    IERC20Upgradeable xcDot = IERC20Upgradeable(xcDotAddress);
    //        IERC20Upgradeable stDot = IERC20Upgradeable(stDotAddress);

    ICurvePool curvePool = ICurvePool(pool);

    assertEq(xcDotAddress, curvePool.coins(0), "coin 0 must be xcDOT");
    assertEq(stDotAddress, curvePool.coins(1), "coin 1 must be stDOT");

    uint256 xcForSt = curvePool.get_dy(0, 1, 1e10);
    emit log_uint(xcForSt);

    bytes memory data = abi.encode(pool, 0, 1, stDotAddress);
    (IERC20Upgradeable shouldBeStDot, uint256 stDotOutput) = csl.redeem(xcDot, 1e10, data);
    assertEq(address(shouldBeStDot), stDotAddress, "output token does not match");

    assertEq(xcForSt, stDotOutput, "output amount does not match");
  }

  function testRedeemMAI() public shouldRun(forChains(BSC_MAINNET)) {
    address maiAddress = 0x3F56e0c36d275367b8C502090EDF38289b3dEa0d;
    address val3EPSAddress = 0x5b5bD8913D766D005859CE002533D4838B0Ebbb5;

    IERC20Upgradeable mai = IERC20Upgradeable(maiAddress);
    //        IERC20Upgradeable val3EPS = IERC20Upgradeable(val3EPSAddress);

    address poolAddress = 0x68354c6E8Bbd020F9dE81EAf57ea5424ba9ef322;

    ICurvePool curvePool = ICurvePool(poolAddress);

    assertEq(maiAddress, curvePool.coins(0), "coin 0 must be MAI");
    assertEq(val3EPSAddress, curvePool.coins(1), "coin 1 must be val3EPS");

    uint256 inputAmount = 1e10;

    uint256 maiForVal3EPS = curvePool.get_dy(0, 1, inputAmount);
    emit log_uint(maiForVal3EPS);

    dealMai(mai, address(csl), inputAmount);

    bytes memory data = abi.encode(poolAddress, 0, 1, val3EPSAddress);
    (IERC20Upgradeable shouldBeVal3EPS, uint256 outputAmount) = csl.redeem(mai, inputAmount, data);
    assertEq(address(shouldBeVal3EPS), val3EPSAddress, "output token does not match");

    assertEq(maiForVal3EPS, outputAmount, "output amount does not match");
  }

  function dealMai(
    IERC20Upgradeable mai,
    address to,
    uint256 amount
  ) internal {
    address whale = 0xc412eCccaa35621cFCbAdA4ce203e3Ef78c4114a; // anyswap
    vm.prank(whale);
    mai.transfer(to, amount);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { BaseTest } from "./config/BaseTest.t.sol";
import "../external/curve/ICurvePool.sol";
import "../compound/EIP20NonStandardInterface.sol";

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
        IERC20Upgradeable stDot = IERC20Upgradeable(stDotAddress);

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
}

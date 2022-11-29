// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";
import { BaseTest } from "./config/BaseTest.t.sol";
import { CErc20Token, MidasFlywheelLensRouter } from "../midas/strategies/flywheel/MidasFlywheelLensRouter.sol";
import "../midas/strategies/flywheel/MidasFlywheelCore.sol";
import { UniswapTwapPriceOracleV2Resolver } from "../oracles/default/UniswapTwapPriceOracleV2Resolver.sol";

contract MidasFlywheelLensRouterTest is BaseTest {
  function setUp() public fork(BSC_MAINNET) {}

  function testGetUnclaimedRwards() public {
    MidasFlywheelLensRouter router = MidasFlywheelLensRouter(0x55F40B04e7161A7D62EBf0676fE0AeF9fe2B772F);
    CErc20Token[] memory markets = new CErc20Token[](1);
    markets[0] = CErc20Token(0xa9736bA05de1213145F688e4619E5A7e0dcf4C72);
    MidasFlywheelCore[] memory flywheels = new MidasFlywheelCore[](1);
    flywheels[0] = MidasFlywheelCore(0xbCeB5Cb9b7Ea70994d8a7cfAC5D48dEA849CED06);
    bool[] memory accrue = new bool[](1);
    accrue[0] = true;

    address xcDotAddress = 0xFfFFfFff1FcaCBd218EDc0EbA20Fc2308C778080;
    IERC20Upgradeable xcDot = IERC20Upgradeable(xcDotAddress);

    vm.mockCall(
      xcDotAddress,
      abi.encodeWithSelector(xcDot.balanceOf.selector, 0xa9736bA05de1213145F688e4619E5A7e0dcf4C72, 152285381920943),
      abi.encode(true)
    );

    router.getUnclaimedRewardsByMarkets(0x9334f5B92da1Bed85Fd33a60146B453D58BBCbaF, markets, flywheels, accrue);
  }

  function testBscTwapResolver() public {
    UniswapTwapPriceOracleV2Resolver resolver = UniswapTwapPriceOracleV2Resolver(
      0xe712F1014d6c42cDb44193a6c8440AE3dc537BFF
    );
    address[] memory workablePairs = resolver.getWorkablePairs();
    UniswapTwapPriceOracleV2Resolver.PairConfig[] memory pairs = resolver.getPairs();
    // resolver.getWorkablePairs();
    emit log_uint(pairs.length);
    emit log_uint(workablePairs.length);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { BalancerLpTokenLiquidator } from "../liquidators/BalancerLpTokenLiquidator.sol";
import { ICErc20 } from "../external/compound/ICErc20.sol";
import "../external/balancer/IBalancerPool.sol";
import "../external/balancer/IBalancerVault.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "./config/BaseTest.t.sol";

contract BalancerLpTokenLiquidatorTest is BaseTest {
  BalancerLpTokenLiquidator private liquidator;

  function afterForkSetUp() internal override {
    liquidator = new BalancerLpTokenLiquidator();
  }

  function testBalancerLpLiquidatorRedeem() public fork(POLYGON_MAINNET) {
    address marketAddress = 0xcb67Bd2aE0597eDb2426802CdF34bb4085d9483A; //MIMO-PAR 8020
    address lpTokenWhale = 0xbB60ADbe38B4e6ab7fb0f9546C2C1b665B86af11;
    ICErc20 market = ICErc20(marketAddress);

    address outputTokenAddress = 0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128; // PAR

    address lpTokenAddress = market.underlying();
    IERC20Upgradeable lpToken = IERC20Upgradeable(lpTokenAddress);
    IBalancerPool asPool = IBalancerPool(lpTokenAddress);

    (IERC20Upgradeable[] memory tokens, ,) = asPool
      .getVault()
      .getPoolTokens(asPool.getPoolId());

    IERC20Upgradeable outputToken;
    uint256 outputTokenIndex = type(uint256).max;
    for (uint256 i = 0; i < tokens.length; i++) {
      if (address(tokens[i]) == outputTokenAddress) outputTokenIndex = i;
    }
    outputToken = IERC20Upgradeable(outputTokenAddress);

    uint256 amount = 1e18;
    vm.prank(lpTokenWhale);
    lpToken.transfer(address(liquidator), amount);

    uint256 balanceBefore = outputToken.balanceOf(address(liquidator));

    bytes memory data = abi.encode(outputTokenIndex);
    liquidator.redeem(lpToken, amount, data);

    uint256 balanceAfter = outputToken.balanceOf(address(liquidator));

    assertGt(balanceAfter - balanceBefore, 0, "!redeem lp token");
  }
}

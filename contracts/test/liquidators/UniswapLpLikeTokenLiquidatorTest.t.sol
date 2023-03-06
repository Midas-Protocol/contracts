// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import { UniswapLpTokenPriceOracle } from "../../oracles/default/UniswapLpTokenPriceOracle.sol";
import { SolidlyLpTokenPriceOracle } from "../../oracles/default/SolidlyLpTokenPriceOracle.sol";
import { UniswapLikeLpTokenPriceOracle } from "../../oracles/default/UniswapLikeLpTokenPriceOracle.sol";
import { UniswapLpTokenLiquidator } from "../../liquidators/UniswapLpTokenLiquidator.sol";
import { ICErc20 } from "../../external/compound/ICErc20.sol";
import { IPriceOracle } from "../../external/compound/IPriceOracle.sol";
import { IUniswapV2Router02 } from "../../external/uniswap/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../../external/uniswap/IUniswapV2Pair.sol";
import { IPair } from "../../external/solidly/IPair.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "../config/BaseTest.t.sol";

contract UniswapLpTokenLiquidatorTest is BaseTest {
  UniswapLpTokenLiquidator private liquidator;
  SolidlyLpTokenPriceOracle private oracleSolidly;
  UniswapLpTokenPriceOracle private oracleUniswap;
  MasterPriceOracle mpo;
  address wtoken;
  address uniswapV2Router;
  address WBNB_BUSD_Uniswap = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
  address WBNB_BUSD_Solidly = 0x483653bcF3a10d9a1c334CE16a19471a614F4385;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    uniswapV2Router = ap.getAddress("IUniswapV2Router02");
    wtoken = ap.getAddress("wtoken");

    liquidator = new UniswapLpTokenLiquidator();
    oracleSolidly = new SolidlyLpTokenPriceOracle(wtoken);
    oracleUniswap = new UniswapLpTokenPriceOracle(wtoken);
  }

  function setUpOracles(address lpToken, UniswapLikeLpTokenPriceOracle oracle) internal {
    if (address(mpo.oracles(lpToken)) == address(0)) {
      address[] memory underlyings = new address[](1);
      IPriceOracle[] memory oracles = new IPriceOracle[](1);

      underlyings[0] = lpToken;
      oracles[0] = IPriceOracle(oracle);

      vm.prank(mpo.admin());
      mpo.add(underlyings, oracles);
      emit log("added the oracle");
    } else {
      emit log("found the oracle");
    }
  }

  function testRedeem(
    address whale,
    address lpToken,
    UniswapLikeLpTokenPriceOracle oracle
  ) internal {
    setUpOracles(lpToken, oracle);
    IERC20Upgradeable lpTokenContract = IERC20Upgradeable(lpToken);
    IUniswapV2Pair pool = IUniswapV2Pair(lpToken);

    address token0 = pool.token0();
    address token1 = pool.token1();

    address[] memory swapToken0Path;
    address[] memory swapToken1Path;

    IERC20Upgradeable outputToken = IERC20Upgradeable(wtoken);

    if (token0 != wtoken) {
      swapToken0Path = asArray(token0, wtoken);
      swapToken1Path = new address[](0);
    } else {
      swapToken0Path = new address[](0);
      swapToken1Path = asArray(token1, wtoken);
    }

    uint256 redeemAmount = 1e18;

    bytes memory data = abi.encode(uniswapV2Router, swapToken0Path, swapToken1Path);

    uint256 outputBalanceBefore = outputToken.balanceOf(address(liquidator));
    vm.prank(whale);
    lpTokenContract.transfer(address(liquidator), redeemAmount);

    vm.prank(address(liquidator));
    lpTokenContract.approve(WBNB_BUSD_Uniswap, redeemAmount);
    liquidator.redeem(lpTokenContract, redeemAmount, data);

    uint256 outputBalanceAfter = outputToken.balanceOf(address(liquidator));
    uint256 outputBalanceDiff = outputBalanceAfter - outputBalanceBefore;
    assertGt(outputBalanceDiff, 0, "!redeem output");

    // compare the value of the input LP tokens and the value of the output tokens
    uint256 price = mpo.price(address(outputToken));
    uint256 outputValue = (price * outputBalanceDiff) / 1e18;
    uint256 inputTokenPrice = mpo.price(WBNB_BUSD_Uniswap);
    uint256 inputValue = (redeemAmount * inputTokenPrice) / 1e18;

    assertApproxEqAbs(inputValue, outputValue, 1e15, "value of output does not match the value of the output");
  }

  function testUniswapLpRedeem() public fork(BSC_MAINNET) {
    address lpTokenWhale = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652; // pcs main staking contract
    testRedeem(lpTokenWhale, WBNB_BUSD_Uniswap, oracleUniswap);
  }

  function testSolidlyLpRedeem() public fork(BSC_MAINNET) {
    address lpTokenWhale = 0x7144851e51523a88EA6BeC9710cC07f3a9B3baa7; // Thena Gauge
    testRedeem(lpTokenWhale, WBNB_BUSD_Solidly, oracleSolidly);
  }
}

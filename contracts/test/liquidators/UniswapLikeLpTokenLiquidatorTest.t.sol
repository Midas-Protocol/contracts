// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import { MasterPriceOracle } from "../../oracles/MasterPriceOracle.sol";
import { UniswapLpTokenPriceOracle } from "../../oracles/default/UniswapLpTokenPriceOracle.sol";
import { SolidlyLpTokenPriceOracle } from "../../oracles/default/SolidlyLpTokenPriceOracle.sol";
import { UniswapLikeLpTokenPriceOracle } from "../../oracles/default/UniswapLikeLpTokenPriceOracle.sol";
import { UniswapLpTokenLiquidator } from "../../liquidators/UniswapLpTokenLiquidator.sol";
import { SolidlyLpTokenLiquidator } from "../../liquidators/SolidlyLpTokenLiquidator.sol";
import { BasePriceOracle } from "../../oracles/BasePriceOracle.sol";
import { IUniswapV2Router02 } from "../../external/uniswap/IUniswapV2Router02.sol";
import { IUniswapV2Pair } from "../../external/uniswap/IUniswapV2Pair.sol";
import { IPair } from "../../external/solidly/IPair.sol";

import { IERC20Upgradeable } from "openzeppelin-contracts-upgradeable/contracts/token/ERC20/IERC20Upgradeable.sol";

import { BaseTest } from "../config/BaseTest.t.sol";

contract UniswapLikeLpTokenLiquidatorTest is BaseTest {
  UniswapLpTokenLiquidator private uniLiquidator;
  SolidlyLpTokenLiquidator private solidlyLpTokenLiquidator;
  SolidlyLpTokenPriceOracle private oracleSolidly;
  UniswapLpTokenPriceOracle private oracleUniswap;
  MasterPriceOracle mpo;
  address wtoken;
  address stableToken;
  address uniswapV2Router;
  address solidlyRouter;

  function afterForkSetUp() internal override {
    mpo = MasterPriceOracle(ap.getAddress("MasterPriceOracle"));
    uniswapV2Router = ap.getAddress("IUniswapV2Router02");
    solidlyRouter = 0xd4ae6eCA985340Dd434D38F470aCCce4DC78D109;
    wtoken = ap.getAddress("wtoken");
    stableToken = ap.getAddress("stableToken");

    uniLiquidator = new UniswapLpTokenLiquidator();
    solidlyLpTokenLiquidator = new SolidlyLpTokenLiquidator();
    oracleSolidly = new SolidlyLpTokenPriceOracle(wtoken);
    oracleUniswap = new UniswapLpTokenPriceOracle(wtoken);
  }

  function setUpOracles(address lpToken, UniswapLikeLpTokenPriceOracle oracle) internal {
    if (address(mpo.oracles(lpToken)) == address(0)) {
      address[] memory underlyings = new address[](1);
      BasePriceOracle[] memory oracles = new BasePriceOracle[](1);

      underlyings[0] = lpToken;
      oracles[0] = BasePriceOracle(oracle);

      vm.prank(mpo.admin());
      mpo.add(underlyings, oracles);
      emit log("added the oracle");
    } else {
      emit log("found the oracle");
    }
  }

  function testUniswapLpTokenRedeem(
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

    uint256 outputBalanceBefore = outputToken.balanceOf(address(uniLiquidator));

    uint256 redeemAmount = 1e18;
    // redeem
    {
      bytes memory data = abi.encode(uniswapV2Router, swapToken0Path, swapToken1Path);

      vm.prank(whale);
      lpTokenContract.transfer(address(uniLiquidator), redeemAmount);

      vm.prank(address(uniLiquidator));
      lpTokenContract.approve(lpToken, redeemAmount);
      uniLiquidator.redeem(lpTokenContract, redeemAmount, data);
    }

    uint256 outputBalanceAfter = outputToken.balanceOf(address(uniLiquidator));
    uint256 outputBalanceDiff = outputBalanceAfter - outputBalanceBefore;
    assertGt(outputBalanceDiff, 0, "!redeem output");

    // compare the value of the input LP tokens and the value of the output tokens
    checkInputOutputValue(redeemAmount, lpToken, outputBalanceDiff, address(outputToken));
  }

  function testSolidlyLpTokenRedeem(
    address whale,
    address lpToken,
    address outputTokenAddress,
    UniswapLikeLpTokenPriceOracle oracle
  ) internal {
    setUpOracles(lpToken, oracle);
    IERC20Upgradeable lpTokenContract = IERC20Upgradeable(lpToken);

    IERC20Upgradeable outputToken = IERC20Upgradeable(outputTokenAddress);

    uint256 outputBalanceBefore = outputToken.balanceOf(address(solidlyLpTokenLiquidator));

    uint256 redeemAmount = 1e18;
    // redeem
    {
      bytes memory data = abi.encode(solidlyRouter, outputTokenAddress);

      vm.prank(whale);
      lpTokenContract.transfer(address(solidlyLpTokenLiquidator), redeemAmount);

      vm.prank(address(solidlyLpTokenLiquidator));
      lpTokenContract.approve(lpToken, redeemAmount);
      solidlyLpTokenLiquidator.redeem(lpTokenContract, redeemAmount, data);
    }

    uint256 outputBalanceAfter = outputToken.balanceOf(address(solidlyLpTokenLiquidator));
    uint256 outputBalanceDiff = outputBalanceAfter - outputBalanceBefore;
    assertGt(outputBalanceDiff, 0, "!redeem output");

    // compare the value of the input LP tokens and the value of the output tokens
    checkInputOutputValue(redeemAmount, lpToken, outputBalanceDiff, address(outputToken));
  }

  function checkInputOutputValue(
    uint256 inputAmount,
    address inputToken,
    uint256 outputAmount,
    address outputToken
  ) internal {
    uint256 outputTokenPrice = mpo.price(address(outputToken));
    uint256 outputValue = (outputTokenPrice * outputAmount) / 1e18;
    uint256 inputTokenPrice = mpo.price(inputToken);
    uint256 inputValue = (inputAmount * inputTokenPrice) / 1e18;

    assertApproxEqAbs(inputValue, outputValue, 1e15, "value of output does not match the value of the output");
  }

  function testUniswapLpRedeem() public fork(BSC_MAINNET) {
    address lpTokenWhale = 0xa5f8C5Dbd5F286960b9d90548680aE5ebFf07652; // pcs main staking contract
    address WBNB_BUSD_Uniswap = 0x58F876857a02D6762E0101bb5C46A8c1ED44Dc16;
    testUniswapLpTokenRedeem(lpTokenWhale, WBNB_BUSD_Uniswap, oracleUniswap);
  }

  function testSolidlyLpRedeem() public fork(BSC_MAINNET) {
    address ankrBNB = 0x52F24a5e03aee338Da5fd9Df68D2b6FAe1178827;

    address WBNB_BUSD = 0x483653bcF3a10d9a1c334CE16a19471a614F4385;
    address HAY_BUSD = 0x93B32a8dfE10e9196403dd111974E325219aec24;
    address ANKR_ankrBNB = 0x7ef540f672Cd643B79D2488344944499F7518b1f;

    address WBNB_BUSD_whale = 0x7144851e51523a88EA6BeC9710cC07f3a9B3baa7;
    address HAY_BUSD_whale = 0x5f8a3d4ad41352A8145DDe8dC0aA3159C7B7649D;
    address ANKR_ankrBNB_whale = 0x5FFEAe4E352Bf3789C9152Ef7eAfD9c1B3bfcE26;

    testSolidlyLpTokenRedeem(WBNB_BUSD_whale, WBNB_BUSD, wtoken, oracleSolidly);
    testSolidlyLpTokenRedeem(HAY_BUSD_whale, HAY_BUSD, stableToken, oracleSolidly);
    testSolidlyLpTokenRedeem(ANKR_ankrBNB_whale, ANKR_ankrBNB, ankrBNB, oracleSolidly);
  }
}

// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../compound/CTokenInterfaces.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import { BaseTest } from "./config/BaseTest.t.sol";
import "./helpers/WithPool.sol";
import "../liquidators/UniswapV3LiquidatorFunder.sol";
import "../FuseSafeLiquidator.sol";
import "../external/uniswap/IUniswapV2Pair.sol";
import "../external/uniswap/IUniswapV2Factory.sol";
import "../external/uniswap/ISwapRouter.sol";
import "../external/uniswap/IUniswapV3Factory.sol";
import "../external/uniswap/Quoter/Quoter.sol";
import "../external/uniswap/IUniswapV3Pool.sol";
import "../external/uniswap/ISwapRouter.sol";

contract UniswapV3LiquidatorFunderTest is BaseTest {
  UniswapV3LiquidatorFunder private uniswapv3Liquidator;

  IERC20Upgradeable parToken;
  IERC20Upgradeable usdcToken;
  address parMarketAddress;
  address usdcMarketAddress;
  IUniswapV2Router02 uniswapRouter;
  address univ3SwapRouter;

  uint256 poolFee;
  uint256 repayAmount;
  uint256 borrowAmount;

  Quoter quoter;

  function afterForkSetUp() internal override {
    if (block.chainid == POLYGON_MAINNET) {
      quoter = new Quoter(0x1F98431c8aD98523631AE4a59f267346ea31F984);
      uniswapRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
      univ3SwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
      parToken = IERC20Upgradeable(0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128); // PAR, 18 decimals
      parMarketAddress = 0x2e84b83883E57727bAEBB4D2A85E7acB0b8e6b54;
      usdcMarketAddress = 0xF2aa6fd973A07AA7F413054958c9e8ec08F5d7cF;
      usdcToken = IERC20Upgradeable(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174); // USDC, 6 decimals
      poolFee = 500;
      repayAmount = 1e18; // 1 PAR
      borrowAmount = 6e20; // 600 PAR
    }
    uniswapv3Liquidator = new UniswapV3LiquidatorFunder();
  }

  function testPolygon() public fork(POLYGON_MAINNET) {
    // collateral value falls from 50 000 USD to 500 USD
    // PAR price 1 USD => debt value = 600*1 = 600 USD
    testLiquidation();
  }

  struct LiquidationData {
    address[] cTokens;
    IRedemptionStrategy[] strategies;
    bytes[] abis;
    CTokenInterface[] allMarkets;
    FuseSafeLiquidator liquidator;
    IFundsConversionStrategy[] fundingStrategies;
    bytes[] data;
  }

  function testLiquidation() internal {
    LiquidationData memory vars;

    vars.liquidator = FuseSafeLiquidator(payable(ap.getAddress("FuseSafeLiquidator")));

    CErc20Delegate usdcCToken = CErc20Delegate(usdcMarketAddress);
    CErc20Delegate parCToken = CErc20Delegate(parMarketAddress);
    IComptroller comptroller = IComptroller(address(usdcCToken.comptroller()));

    vars.cTokens = new address[](2);
    vars.cTokens[0] = address(parCToken);
    vars.cTokens[1] = address(usdcCToken);

    address accountOne = address(10001);
    address accountTwo = address(20002);

    // Account One supply PAR
    deal(parCToken.underlying(), accountTwo, 10e21);
    // Account One supply USDC
    deal(usdcCToken.underlying(), accountOne, 10e10);

    // Account One deposit usdcToken
    vm.startPrank(accountOne);
    {
      comptroller.enterMarkets(vars.cTokens);
      usdcToken.approve(address(usdcCToken), 1e36);
      require(usdcCToken.mint(5e10) == 0, "USDC mint failed"); // 50 000 USDC deposited
    }
    vm.stopPrank();

    vm.startPrank(accountTwo);
    {
      comptroller.enterMarkets(vars.cTokens);
      parToken.approve(address(parCToken), 1e36);
      require(parCToken.mint(5e21) == 0, "PAR mint failed"); // 5000 PAR deposited
    }
    vm.stopPrank();

    // Account One borrow PAR
    vm.startPrank(accountOne);
    {
      require(parCToken.borrow(borrowAmount) == 0, "borrow failed"); // borrow 12 PAR
    }
    vm.stopPrank();

    // some time passes, interest accrues and prices change
    {
      vm.roll(block.number + 100);
      usdcCToken.accrueInterest();
      parCToken.accrueInterest();

      MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
      uint256 priceusdc = mpo.getUnderlyingPrice(ICToken(usdcMarketAddress));
      vm.mockCall(
        address(mpo),
        abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, ICToken(usdcMarketAddress)),
        abi.encode(priceusdc / 100)
      );
    }

    // prepare the liquidation
    vars.strategies = new IRedemptionStrategy[](0);
    vars.abis = new bytes[](0);

    vars.fundingStrategies = new IFundsConversionStrategy[](1);
    vars.data = new bytes[](1);
    vars.data[0] = abi.encode(usdcToken, parToken, poolFee, ISwapRouter(univ3SwapRouter), quoter);
    vars.fundingStrategies[0] = uniswapv3Liquidator;

    // all strategies need to be whitelisted
    vm.prank(vars.liquidator.owner());
    vars.liquidator._whitelistRedemptionStrategy(vars.fundingStrategies[0], true);

    address pairAddress = IUniswapV2Factory(uniswapRouter.factory()).getPair(
      address(usdcToken),
      ap.getAddress("wtoken")
    );
    IUniswapV2Pair flashSwapPair = IUniswapV2Pair(pairAddress);

    // liquidate
    vm.prank(accountTwo);
    vars.liquidator.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        accountOne,
        repayAmount, // repay PAR
        ICErc20(address(parCToken)), // PAR debt
        ICErc20(address(usdcCToken)), // usdc collateral
        flashSwapPair,
        0,
        address(0),
        uniswapRouter,
        uniswapRouter,
        vars.strategies,
        vars.abis,
        0,
        vars.fundingStrategies,
        vars.data
      )
    );
  }
}

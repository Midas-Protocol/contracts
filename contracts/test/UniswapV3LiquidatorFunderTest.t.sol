// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import "../compound/CTokenInterfaces.sol";
import { Comptroller } from "../compound/Comptroller.sol";
import { CErc20Delegate } from "../compound/CErc20Delegate.sol";
import { MasterPriceOracle } from "../oracles/MasterPriceOracle.sol";
import "./config/BaseTest.t.sol";
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

contract UniswapV3LiquidatorFunderTest is BaseTest, WithPool {
  UniswapV3LiquidatorFunder private uniswapv3Liquidator;

  IERC20Upgradeable token1;
  IERC20Upgradeable token2;
  IUniswapV2Router02 uniswapRouter;

  uint256 poolFee;
  uint256 repayAmount;
  uint256 borrowAmount;

  Quoter quoter;

  function afterForkSetUp() internal override {
    if (block.chainid == ARBITRUM_ONE) {
      setUpWithPool(
        MasterPriceOracle(0xd4D0cA503E8befAbE4b75aAC36675Bc1cFA533D1),
        ERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
      );
      quoter = new Quoter(0x1F98431c8aD98523631AE4a59f267346ea31F984);
      setUpPool("arbitrum-test", false, 0.1e18, 1.1e18);
      uniswapv3Liquidator = new UniswapV3LiquidatorFunder();
      uniswapRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
      token1 = IERC20Upgradeable(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a); // GMX, 18 decimals
      token2 = IERC20Upgradeable(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8); // USDC, 6 decimals
      poolFee = 3000;
      repayAmount = 1e18; // 1.00 GMX
      borrowAmount = 12e18; // 12.00 GMX

    } else if (block.chainid == POLYGON_MAINNET) {
      setUpWithPool(
        MasterPriceOracle(0xb9e1c2B011f252B9931BBA7fcee418b95b6Bdc31),
        ERC20Upgradeable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270)
      );
      quoter = new Quoter(0x1F98431c8aD98523631AE4a59f267346ea31F984);
      setUpPool("polygon-test", false, 0.1e18, 1.1e18);
      uniswapRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
      token1 = IERC20Upgradeable(0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128);
      token2 = IERC20Upgradeable(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
      poolFee = 500;
      repayAmount = 11e10;
      borrowAmount = 1e20;
    }
    uniswapv3Liquidator = new UniswapV3LiquidatorFunder();
  }

  function testPolygon() public fork(POLYGON_MAINNET) {
    testLiquidation();
  }

  function testArbitrum() public fork(ARBITRUM_ONE) {
    // collateral value falls from 50 000 USD to 500 USD
    // GMX price 42.00 USD => debt value = 12*42 = 504 USD
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

    vars.liquidator = new FuseSafeLiquidator();
    vars.liquidator.initialize(
      ap.getAddress("wtoken"),
      address(uniswapRouter),
      ap.getAddress("wtoken"),
      ap.getAddress("wBTCToken"),
      "0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303",
      25
    );

    deployCErc20Delegate(address(token2), "token2", "token2", 0.9e18); // usdc, 6 dec
    deployCErc20Delegate(address(token1), "token1", "token1", 0.9e18); // gmx, 18 dec

    vars.allMarkets = comptroller.getAllMarkets();

    CErc20Delegate cToken1 = CErc20Delegate(address(vars.allMarkets[0])); // cUsdc, 6 dec
    CErc20Delegate cToken2 = CErc20Delegate(address(vars.allMarkets[1])); // cGmx, 18 dec

    assertEq(cToken1.underlying(), address(token2), "token 1 should be USDC");
    assertEq(cToken2.underlying(), address(token1), "token 2 should be GMX");

    address accountOne = address(10001);
    address accountTwo = address(20002);

    // Account One supply GMX
    deal(address(token1), accountTwo, 10e21);
    // Account One supply token2
    deal(address(token2), accountOne, 10e10);

    // Account One deposit token2
    vm.startPrank(accountOne);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cToken2);
      vars.cTokens[1] = address(cToken1);
      comptroller.enterMarkets(vars.cTokens);
    }
    token2.approve(address(cToken1), 1e36);
    require(cToken1.mint(5e10) == 0, "USDC mint failed"); // 50 000 USDC deposited
    vm.stopPrank();

    vm.startPrank(accountTwo);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cToken2);
      vars.cTokens[1] = address(cToken1);
      comptroller.enterMarkets(vars.cTokens);
      token1.approve(address(cToken2), 1e36);
      require(cToken2.mint(5e21) == 0, "GMX mint failed"); // 5000 GMX deposited
    }
    vm.stopPrank();

    // set borrow enable
    vm.startPrank(address(this));
    comptroller._setBorrowPaused(CTokenInterface(address(cToken2)), false);
    vm.stopPrank();

    // Account One borrow GMX
    vm.startPrank(accountOne);
    require(cToken2.borrow(borrowAmount) == 0, "borrow failed"); // borrow 12 GMX
    vm.stopPrank();

    // some time passes, interest accrues and prices change
    {
      vm.roll(block.number + 100);
      cToken1.accrueInterest();
      cToken2.accrueInterest();

      MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
      uint256 priceusdc = mpo.getUnderlyingPrice(ICToken(address(cToken1)));
      vm.mockCall(
        address(mpo),
        abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, ICToken(address(cToken1))),
        abi.encode(priceusdc / 100)
      );
    }

    // prepare the liquidation
    vars.strategies = new IRedemptionStrategy[](0);
    vars.abis = new bytes[](0);

    vars.fundingStrategies = new IFundsConversionStrategy[](1);
    vars.data = new bytes[](1);
    vars.data[0] = abi.encode(token2, token1, poolFee, ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564), quoter);
    vars.fundingStrategies[0] = uniswapv3Liquidator;

    // all strategies need to be whitelisted
    vm.prank(vars.liquidator.owner());
    vars.liquidator._whitelistRedemptionStrategy(vars.fundingStrategies[0], true);

    address pairAddress = IUniswapV2Factory(uniswapRouter.factory()).getPair(address(token2), ap.getAddress("wtoken"));
    IUniswapV2Pair flashSwapPair = IUniswapV2Pair(pairAddress);

    // liquidate
    vm.prank(accountTwo);
    vars.liquidator.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        accountOne,
        repayAmount, // repay gmx
        ICErc20(address(cToken2)), // gmx debt
        ICErc20(address(cToken1)), // usdc collateral
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

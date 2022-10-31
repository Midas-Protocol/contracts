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

interface IMockERC20 is IERC20Upgradeable {
  function mint(address _address, uint256 amount) external;
}

contract UniswapV3LiquidatorFunderTest is BaseTest, WithPool {
  UniswapV3LiquidatorFunder private uniswapv3Liquidator;

  address minter = 0x68863dDE14303BcED249cA8ec6AF85d4694dea6A;
  IMockERC20 token1;
  IMockERC20 token2;
  IUniswapV2Router02 uniswapRouter;

  address wETH;
  address BTCB;
  uint256 poolFee;
  uint256 repayAmount;
  uint256 borrowAmount;

  Quoter quoter;

  function setUp() public forkAtBlock(ARBITRUM_ONE, 28739891) {
    super.setUpWithPool(
      MasterPriceOracle(0xd4D0cA503E8befAbE4b75aAC36675Bc1cFA533D1),
      ERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
    );
  }

  function testPolygon() public forkAtBlock(POLYGON_MAINNET, 35032591) {
    setUpWithPool(
      MasterPriceOracle(0xb9e1c2B011f252B9931BBA7fcee418b95b6Bdc31),
      ERC20Upgradeable(0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270)
    );
    quoter = new Quoter(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    setUpPool("polygon-test", false, 0.1e18, 1.1e18);
    uniswapv3Liquidator = new UniswapV3LiquidatorFunder();
    wETH = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    BTCB = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    uniswapRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    token1 = IMockERC20(0xE2Aa7db6dA1dAE97C5f5C6914d285fBfCC32A128);
    token2 = IMockERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    poolFee = 500;
    repayAmount = 11e10;
    borrowAmount = 1e20;
    testLiquidation();
  }

  function testArbitrum() public forkAtBlock(ARBITRUM_ONE, 28739891) {
    quoter = new Quoter(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    setUpPool("arbitrum-test", false, 0.1e18, 1.1e18);
    uniswapv3Liquidator = new UniswapV3LiquidatorFunder();
    wETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    BTCB = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    uniswapRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
    token1 = IMockERC20(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a);
    token2 = IMockERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);
    poolFee = 3000;
    repayAmount = 9e7;
    borrowAmount = 1e19;
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
      wETH, // WETH
      BTCB, // BTCB
      "0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303",
      25
    );

    deployCErc20Delegate(address(token2), "token2", "token2", 0.9e18);
    deployCErc20Delegate(address(token1), "token1", "token1", 0.9e18);

    vars.allMarkets = comptroller.getAllMarkets();

    CErc20Delegate cToken1 = CErc20Delegate(address(vars.allMarkets[0]));
    CErc20Delegate cToken2 = CErc20Delegate(address(vars.allMarkets[1]));

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
    require(cToken1.mint(5e10) == 0, "USDC mint failed");
    vm.stopPrank();

    vm.startPrank(accountTwo);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cToken2);
      vars.cTokens[1] = address(cToken1);
      comptroller.enterMarkets(vars.cTokens);
    }
    token1.approve(address(cToken2), 1e36);
    require(cToken2.mint(5e21) == 0, "GMX mint failed");
    vm.stopPrank();

    // set borrow enable
    vm.startPrank(address(this));
    comptroller._setBorrowPaused(CTokenInterface(address(cToken2)), false);
    vm.stopPrank();

    // Account One borrow GMX
    vm.startPrank(accountOne);
    require(cToken2.borrow(borrowAmount) == 0, "borrow failed");
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
        abi.encode(priceusdc / 1000)
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
        repayAmount,
        ICErc20(address(cToken2)),
        ICErc20(address(cToken1)),
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

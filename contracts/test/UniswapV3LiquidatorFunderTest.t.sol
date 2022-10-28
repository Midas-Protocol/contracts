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

  IUniswapV3Pool pool = IUniswapV3Pool(0x80A9ae39310abf666A87C743d6ebBD0E8C42158E);

  address minter = 0x68863dDE14303BcED249cA8ec6AF85d4694dea6A;
  IMockERC20 gmxToken = IMockERC20(0xfc5A1A6EB076a2C7aD06eD22C90d7E710E35ad0a);

  IMockERC20 usdcToken = IMockERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8);

  Quoter quoter;

  constructor() WithPool() {
    vm.createSelectFork("arbitrum", 28739891);
    setAddressProvider("arbitrum");
    super.setUpWithPool(
      MasterPriceOracle(0xd4D0cA503E8befAbE4b75aAC36675Bc1cFA533D1),
      ERC20Upgradeable(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1)
    );
  }

  function setUp() public {
    quoter = new Quoter(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    setUpPool("gmx-test", false, 0.1e18, 1.1e18);

    uniswapv3Liquidator = new UniswapV3LiquidatorFunder();
  }

  function getPool(address inputToken) internal view returns (IUniswapV3Pool) {
    return pool;
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

  function testGMXLiquidation() public {
    LiquidationData memory vars;
    IUniswapV2Router02 uniswapRouter = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);

    vars.liquidator = new FuseSafeLiquidator();
    vars.liquidator.initialize(
      ap.getAddress("wtoken"),
      address(uniswapRouter),
      0x82aF49447D8a07e3bd95BD0d56f35241523fBab1, // WETH
      0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f, // BTCB
      "0xe18a34eb0e04b04f7a0ac29a6e80748dca96319b42c54d679cb821dca90c6303",
      25
    );

    deployCErc20Delegate(address(usdcToken), "USDC", "usdcToken", 0.9e18);
    deployCErc20Delegate(address(gmxToken), "GMX", "gmx", 0.9e18);

    vars.allMarkets = comptroller.getAllMarkets();

    CErc20Delegate cTokenUSDC = CErc20Delegate(address(vars.allMarkets[0]));
    CErc20Delegate cTokenGMX = CErc20Delegate(address(vars.allMarkets[1]));

    uint256 borrowAmount = 1e19;
    address accountOne = address(10001);
    address accountTwo = address(20002);

    // Account One supply GMX
    dealGMX(accountTwo, 10e21);
    // Account One supply usdcToken
    dealUSDC(accountOne, 10e10);

    emit log_uint(usdcToken.balanceOf(accountOne));

    // Account One deposit usdcToken
    vm.startPrank(accountOne);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cTokenGMX);
      vars.cTokens[1] = address(cTokenUSDC);
      comptroller.enterMarkets(vars.cTokens);
    }
    usdcToken.approve(address(cTokenUSDC), 1e36);
    require(cTokenUSDC.mint(5e10) == 0, "USDC mint failed");
    vm.stopPrank();

    vm.startPrank(accountTwo);
    {
      vars.cTokens = new address[](2);
      vars.cTokens[0] = address(cTokenGMX);
      vars.cTokens[1] = address(cTokenUSDC);
      comptroller.enterMarkets(vars.cTokens);
    }
    gmxToken.approve(address(cTokenGMX), 1e36);
    require(cTokenGMX.mint(5e21) == 0, "GMX mint failed");
    vm.stopPrank();

    // set borrow enable
    vm.startPrank(address(this));
    comptroller._setBorrowPaused(CTokenInterface(address(cTokenGMX)), false);
    vm.stopPrank();

    // Account One borrow GMX
    vm.startPrank(accountOne);
    require(cTokenGMX.borrow(borrowAmount) == 0, "borrow failed");
    vm.stopPrank();

    // some time passes, interest accrues and prices change
    {
      vm.roll(block.number + 100);
      cTokenUSDC.accrueInterest();
      cTokenGMX.accrueInterest();

      MasterPriceOracle mpo = MasterPriceOracle(address(comptroller.oracle()));
      uint256 priceusdc = mpo.getUnderlyingPrice(ICToken(address(cTokenUSDC)));
      vm.mockCall(
        address(mpo),
        abi.encodeWithSelector(mpo.getUnderlyingPrice.selector, ICToken(address(cTokenUSDC))),
        abi.encode(priceusdc / 1000)
      );
    }

    // prepare the liquidation
    vars.strategies = new IRedemptionStrategy[](0);
    vars.abis = new bytes[](0);

    vars.fundingStrategies = new IFundsConversionStrategy[](1);
    vars.data = new bytes[](1);
    vars.data[0] = abi.encode(
      usdcToken,
      gmxToken,
      3000,
      ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564),
      quoter
    );
    vars.fundingStrategies[0] = uniswapv3Liquidator;

    // all strategies need to be whitelisted
    vm.prank(vars.liquidator.owner());
    vars.liquidator._whitelistRedemptionStrategy(vars.fundingStrategies[0], true);

    address pairAddress = IUniswapV2Factory(uniswapRouter.factory()).getPair(
      address(usdcToken),
      ap.getAddress("wtoken")
    );
    IUniswapV2Pair flashSwapPair = IUniswapV2Pair(pairAddress);

    uint256 repayAmount = 9e7;
    // liquidate
    vm.prank(accountTwo);
    vars.liquidator.safeLiquidateToTokensWithFlashLoan(
      FuseSafeLiquidator.LiquidateToTokensWithFlashSwapVars(
        accountOne,
        repayAmount,
        ICErc20(address(cTokenGMX)),
        ICErc20(address(cTokenUSDC)),
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

  function dealUSDC(address to, uint256 amount) internal {
    vm.prank(0x489ee077994B6658eAfA855C308275EAd8097C4A); // whale
    usdcToken.transfer(to, amount);
  }

  function dealGMX(address to, uint256 amount) internal {
    vm.prank(minter); // whale
    gmxToken.mint(to, amount);
  }
}
